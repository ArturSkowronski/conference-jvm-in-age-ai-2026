import java.net.URI
import java.net.URL

plugins {
  application
  java
}

val requestedJavaVersion = (findProperty("javaVersion") as String?)?.toIntOrNull() ?: 21
val tensorflowJavaVersion = maxOf(22, requestedJavaVersion)

java {
  toolchain {
    languageVersion.set(JavaLanguageVersion.of(tensorflowJavaVersion))
  }
}

application {
  mainClass.set("conf.jvm.tensorflow.TensorFlowDemo")
  applicationDefaultJvmArgs = listOf(
    "--enable-native-access=ALL-UNNAMED",
  )
}

// TensorFlow 2.18.0 is used on all platforms for consistency.
// macOS x86_64 is NOT supported - TensorFlow dropped x86_64 macOS support after 2.16.2.
val tensorflowVersion = providers.gradleProperty("tensorflowVersion").orElse("2.18.0")
val tensorflowHomeOverride = providers.gradleProperty("tensorflowHome")

data class TfArchive(val url: String, val fileName: String, val isZip: Boolean)

fun tensorflowArchiveForCurrentPlatform(): TfArchive {
  val os = System.getProperty("os.name").lowercase()
  val arch = System.getProperty("os.arch").lowercase()

  val isX86_64 = arch == "x86_64" || arch == "amd64"
  val isArm64 = arch == "aarch64" || arch == "arm64"
  val version = tensorflowVersion.get()
  val baseUrl = "https://storage.googleapis.com/tensorflow/versions/$version"

  return when {
    // macOS ARM64 (Apple Silicon)
    (os.contains("mac") || os.contains("darwin")) && isArm64 -> {
      val fileName = "libtensorflow-cpu-darwin-arm64.tar.gz"
      TfArchive("$baseUrl/$fileName", fileName, isZip = false)
    }

    // macOS x86_64 - NOT SUPPORTED (TensorFlow dropped support after 2.16.2)
    (os.contains("mac") || os.contains("darwin")) && isX86_64 -> {
      error("""
        macOS x86_64 is not supported by this demo.
        TensorFlow dropped x86_64 macOS support after version 2.16.2.

        Options:
        - Use Apple Silicon (ARM64) Mac
        - Use Linux x86_64
        - Provide your own TF C library via -PtensorflowHome=...
      """.trimIndent())
    }

    // Linux x86_64
    os.contains("linux") && isX86_64 -> {
      val fileName = "libtensorflow-cpu-linux-x86_64.tar.gz"
      TfArchive("$baseUrl/$fileName", fileName, isZip = false)
    }

    // Windows x86_64
    os.contains("win") && isX86_64 -> {
      val fileName = "libtensorflow-cpu-windows-x86_64.zip"
      TfArchive("$baseUrl/$fileName", fileName, isZip = true)
    }

    else -> error("Unsupported platform: os.name=$os os.arch=$arch")
  }
}

val tfRootDir = layout.buildDirectory.dir("tensorflow")
val tfArchiveDir = tfRootDir.map { it.dir("archive") }
val tfExtractedDir = tfRootDir.map { it.dir("root") }

tasks.register("downloadTensorFlow") {
  group = "demos"
  description = "Download TensorFlow C library (for the FFM demo) into build/tensorflow/."

  onlyIf { !tensorflowHomeOverride.isPresent }

  doLast {
    val archive = tensorflowArchiveForCurrentPlatform()
    val dest = tfArchiveDir.get().asFile.resolve(archive.fileName)
    dest.parentFile.mkdirs()
    if (dest.exists() && dest.length() > 0) return@doLast

    logger.lifecycle("Downloading TensorFlow C library: ${archive.url}")
    URI(archive.url).toURL().openStream().use { input ->
      dest.outputStream().use { output -> input.copyTo(output) }
    }
  }
}

tasks.register<Copy>("unpackTensorFlowZip") {
  onlyIf {
    !tensorflowHomeOverride.isPresent && tensorflowArchiveForCurrentPlatform().isZip
  }
  dependsOn("downloadTensorFlow")
  val archive = tensorflowArchiveForCurrentPlatform()
  val archiveFile = tfArchiveDir.map { it.asFile.resolve(archive.fileName) }
  from(archiveFile.map { zipTree(it) })
  into(tfExtractedDir)
  doFirst {
    tfExtractedDir.get().asFile.deleteRecursively()
  }
}

tasks.register<Exec>("unpackTensorFlowTar") {
  onlyIf {
    !tensorflowHomeOverride.isPresent && !tensorflowArchiveForCurrentPlatform().isZip
  }
  dependsOn("downloadTensorFlow")
  val archive = tensorflowArchiveForCurrentPlatform()
  val archiveFile = tfArchiveDir.map { it.asFile.resolve(archive.fileName) }
  
  workingDir(tfExtractedDir)
  commandLine("tar", "-xzf")
  argumentProviders.add(CommandLineArgumentProvider {
    listOf(archiveFile.get().absolutePath)
  })

  doFirst {
    tfExtractedDir.get().asFile.mkdirs()
  }
}

tasks.register("unpackTensorFlow") {
  group = "demos"
  description = "Unpack TensorFlow C library (for the FFM demo) into build/tensorflow/root/."
  dependsOn("unpackTensorFlowZip", "unpackTensorFlowTar")
}

tasks.register<JavaExec>("runTensorFlow") {
  group = "demos"
  description = "Run the TensorFlow FFM demo (downloads TF C library)."

  if (!tensorflowHomeOverride.isPresent) {
    dependsOn("unpackTensorFlow")
  }

  // Use the same JDK as compilation (Java 22+ required for FFM)
  javaLauncher.set(javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(tensorflowJavaVersion))
  })

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)

  systemProperty(
    "tensorflow.home",
    tensorflowHomeOverride.orElse(tfExtractedDir.get().asFile.absolutePath).get()
  )
  jvmArgs(application.applicationDefaultJvmArgs)
}
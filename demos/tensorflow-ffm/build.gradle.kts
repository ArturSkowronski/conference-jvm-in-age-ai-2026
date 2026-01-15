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

// TensorFlow version depends on platform:
// - ARM64 macOS: 2.18.0 (last version with ARM64 prebuilt binaries)
// - x86_64: 2.15.0 (or override via -PtensorflowVersion=X.Y.Z)
val tensorflowHomeOverride = providers.gradleProperty("tensorflowHome")

data class TfArchive(val url: String, val fileName: String, val isZip: Boolean)

fun tensorflowArchiveForCurrentPlatform(): TfArchive {
  val os = System.getProperty("os.name").lowercase()
  val arch = System.getProperty("os.arch").lowercase()

  val isX86_64 = arch == "x86_64" || arch == "amd64"
  val isArm64 = arch == "aarch64" || arch == "arm64"

  val platform = when {
    os.contains("mac") || os.contains("darwin") -> "darwin"
    os.contains("win") -> "windows"
    os.contains("nux") || os.contains("linux") -> "linux"
    else -> error("Unsupported OS for TensorFlow demo: os.name=$os os.arch=$arch")
  }

  // ARM64 macOS uses TensorFlow 2.18.0 with different URL format
  if (platform == "darwin" && isArm64) {
    val version = providers.gradleProperty("tensorflowVersion").orElse("2.18.0").get()
    val fileName = "libtensorflow-cpu-darwin-arm64.tar.gz"
    val url = "https://storage.googleapis.com/tensorflow/versions/$version/$fileName"
    return TfArchive(url, fileName, isZip = false)
  }

  if (!isX86_64) {
    error("TensorFlow prebuilt C library for $platform requires x86_64 (got os.arch=$arch). " +
      "Provide your own TF C library via -PtensorflowHome=...")
  }

  val version = providers.gradleProperty("tensorflowVersion").orElse("2.15.0").get()
  val baseUrl = "https://storage.googleapis.com/tensorflow/libtensorflow"

  return when (platform) {
    "windows" -> TfArchive("$baseUrl/libtensorflow-cpu-windows-x86_64-$version.zip",
                           "libtensorflow-cpu-windows-x86_64-$version.zip", isZip = true)
    "linux" -> TfArchive("$baseUrl/libtensorflow-cpu-linux-x86_64-$version.tar.gz",
                         "libtensorflow-cpu-linux-x86_64-$version.tar.gz", isZip = false)
    "darwin" -> TfArchive("$baseUrl/libtensorflow-cpu-darwin-x86_64-$version.tar.gz",
                          "libtensorflow-cpu-darwin-x86_64-$version.tar.gz", isZip = false)
    else -> error("unreachable")
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
    URL(archive.url).openStream().use { input ->
      dest.outputStream().use { output -> input.copyTo(output) }
    }
  }
}

tasks.register("unpackTensorFlow") {
  group = "demos"
  description = "Unpack TensorFlow C library (for the FFM demo) into build/tensorflow/root/."

  dependsOn("downloadTensorFlow")
  onlyIf { !tensorflowHomeOverride.isPresent }

  doLast {
    val archive = tensorflowArchiveForCurrentPlatform()
    val archiveFile = tfArchiveDir.get().asFile.resolve(archive.fileName)
    val intoDir = tfExtractedDir.get().asFile

    // Clean and recreate target directory
    intoDir.deleteRecursively()
    intoDir.mkdirs()

    if (archive.isZip) {
      copy {
        from(zipTree(archiveFile))
        into(intoDir)
      }
    } else {
      // Use native tar to preserve symlinks (Gradle's tarTree doesn't handle them well)
      exec {
        workingDir = intoDir
        commandLine("tar", "-xzf", archiveFile.absolutePath)
      }
    }
  }
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

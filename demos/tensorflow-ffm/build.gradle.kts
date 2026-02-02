import java.net.URI

plugins {
  application
  java
}

val tensorflowVersion = "2.18.0"
val tensorflowHome = providers.gradleProperty("tensorflowHome")

java {
  toolchain {
    languageVersion.set(JavaLanguageVersion.of(25))
  }
}

application {
  mainClass.set("com.skowronski.talk.jvmai.TensorFlowDemo")
  applicationDefaultJvmArgs = listOf("--enable-native-access=ALL-UNNAMED")
}

val tfBuildDir = layout.buildDirectory.dir("tensorflow")
val tfArchive = tfBuildDir.map { it.dir("archive") }
val tfExtracted = tfBuildDir.map { it.dir("root") }

// Detect platform and archive name
fun getArchiveName(): String {
  val os = System.getProperty("os.name").lowercase()
  val arch = System.getProperty("os.arch").lowercase()
  val isArm64 = arch == "aarch64" || arch == "arm64"
  val isX86_64 = arch == "x86_64" || arch == "amd64"

  return when {
    os.contains("mac") && isArm64 -> "libtensorflow-cpu-darwin-arm64.tar.gz"
    os.contains("linux") && isX86_64 -> "libtensorflow-cpu-linux-x86_64.tar.gz"
    os.contains("win") && isX86_64 -> "libtensorflow-cpu-windows-x86_64.zip"
    else -> error("Unsupported platform: $os $arch")
  }
}

// Download TensorFlow C library
tasks.register("downloadTensorFlow") {
  group = "setup"
  description = "Download TensorFlow C library"
  onlyIf { !tensorflowHome.isPresent }

  doLast {
    val archiveName = getArchiveName()
    val url = "https://storage.googleapis.com/tensorflow/versions/$tensorflowVersion/$archiveName"
    val archiveFile = tfArchive.get().asFile.resolve(archiveName)

    if (archiveFile.exists() && archiveFile.length() > 0) {
      logger.lifecycle("TensorFlow archive already downloaded")
      return@doLast
    }

    archiveFile.parentFile.mkdirs()
    logger.lifecycle("Downloading TensorFlow $tensorflowVersion from $url...")
    URI(url).toURL().openStream().use { input ->
      archiveFile.outputStream().use { output -> input.copyTo(output) }
    }
    logger.lifecycle("Downloaded ${archiveFile.length() / 1024 / 1024} MB")
  }
}

// Extract TensorFlow (Windows - zip)
tasks.register<Copy>("extractTensorFlowZip") {
  onlyIf { !tensorflowHome.isPresent && getArchiveName().endsWith(".zip") }
  dependsOn("downloadTensorFlow")

  doFirst {
    val archiveFile = tfArchive.get().asFile.resolve(getArchiveName())
    from(zipTree(archiveFile))
    into(tfExtracted)
  }
}

// Extract TensorFlow (Linux/macOS - tar.gz)
tasks.register<Exec>("extractTensorFlowTar") {
  onlyIf { !tensorflowHome.isPresent && !getArchiveName().endsWith(".zip") }
  dependsOn("downloadTensorFlow")

  doFirst {
    tfExtracted.get().asFile.mkdirs()
    val archiveFile = tfArchive.get().asFile.resolve(getArchiveName())
    workingDir = tfExtracted.get().asFile
    commandLine = listOf("tar", "-xzf", archiveFile.absolutePath)
  }
}

// Setup task (download + extract)
tasks.register("setupTensorFlow") {
  group = "setup"
  description = "Setup TensorFlow C library (download + extract)"
  dependsOn("extractTensorFlowZip", "extractTensorFlowTar")
}

// Main task - runs TensorFlow FFM demo
tasks.register<JavaExec>("runSmoke") {
  group = "application"
  description = "Run TensorFlow FFM demo"

  if (!tensorflowHome.isPresent) {
    dependsOn("setupTensorFlow")
  }

  javaLauncher.set(javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(25))
  })

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)
  systemProperty("tensorflow.home", tensorflowHome.orElse(tfExtracted.get().asFile.absolutePath).get())
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Configure 'run' task (from application plugin) same as runSmoke
tasks.named<JavaExec>("run") {
  if (!tensorflowHome.isPresent) {
    dependsOn("setupTensorFlow")
  }

  javaLauncher.set(javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(25))
  })

  systemProperty("tensorflow.home", tensorflowHome.orElse(tfExtracted.get().asFile.absolutePath).get())
  jvmArgs(application.applicationDefaultJvmArgs)
}

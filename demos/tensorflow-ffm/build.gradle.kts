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

// Download TensorFlow C library
tasks.register("downloadTensorFlow") {
  group = "setup"
  description = "Download TensorFlow C library"
  onlyIf { !tensorflowHome.isPresent }

  doLast {
    val os = System.getProperty("os.name").lowercase()
    val arch = System.getProperty("os.arch").lowercase()
    val isArm64 = arch == "aarch64" || arch == "arm64"
    val isX86_64 = arch == "x86_64" || arch == "amd64"

    val url = when {
      os.contains("mac") && isArm64 ->
        "https://storage.googleapis.com/tensorflow/versions/$tensorflowVersion/libtensorflow-cpu-darwin-arm64.tar.gz"
      os.contains("linux") && isX86_64 ->
        "https://storage.googleapis.com/tensorflow/versions/$tensorflowVersion/libtensorflow-cpu-linux-x86_64.tar.gz"
      os.contains("win") && isX86_64 ->
        "https://storage.googleapis.com/tensorflow/versions/$tensorflowVersion/libtensorflow-cpu-windows-x86_64.zip"
      else -> error("Unsupported platform: $os $arch")
    }

    val archiveFile = tfArchive.get().asFile.resolve(url.substringAfterLast("/"))
    if (archiveFile.exists()) return@doLast

    archiveFile.parentFile.mkdirs()
    logger.lifecycle("Downloading TensorFlow $tensorflowVersion...")
    URI(url).toURL().openStream().use { input ->
      archiveFile.outputStream().use { output -> input.copyTo(output) }
    }
  }
}

// Extract TensorFlow
tasks.register<Copy>("extractTensorFlowZip") {
  onlyIf { !tensorflowHome.isPresent && System.getProperty("os.name").lowercase().contains("win") }
  dependsOn("downloadTensorFlow")

  from(zipTree(tfArchive.get().asFile.listFiles()!!.first()))
  into(tfExtracted)
}

tasks.register<Exec>("extractTensorFlowTar") {
  onlyIf { !tensorflowHome.isPresent && !System.getProperty("os.name").lowercase().contains("win") }
  dependsOn("downloadTensorFlow")

  workingDir(tfExtracted)
  commandLine("tar", "-xzf", tfArchive.get().asFile.listFiles()!!.first().absolutePath)

  doFirst { tfExtracted.get().asFile.mkdirs() }
}

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

// Alias 'run' to 'runSmoke'
tasks.named("run") {
  dependsOn("runSmoke")
}

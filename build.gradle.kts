import java.net.URL

plugins {
  application
  java
  id("org.graalvm.buildtools.native") version "0.10.2"
}

repositories {
  mavenCentral()
}

val javaVersion = (findProperty("javaVersion") as String?)?.toIntOrNull() ?: 21

java {
  toolchain {
    languageVersion.set(JavaLanguageVersion.of(javaVersion))
  }
}

dependencies {
  implementation("org.jcuda:jcuda:12.6.0") {
    exclude(group = "org.jcuda", module = "jcuda-natives")
  }
  runtimeOnly("org.jcuda:jcuda-natives:12.6.0:linux-x86_64")
  runtimeOnly("org.jcuda:jcuda-natives:12.6.0:windows-x86_64")
}

application {
  mainClass.set("conf.jvm.Main")
  applicationDefaultJvmArgs = listOf(
    "--enable-native-access=ALL-UNNAMED",
  )
}

tasks.test {
  enabled = false
}

val tensorflowVersion = providers.gradleProperty("tensorflowVersion").orElse("2.15.0")
val tensorflowBaseUrl = providers.gradleProperty("tensorflowBaseUrl")
  .orElse("https://storage.googleapis.com/tensorflow/libtensorflow")
val tensorflowHomeOverride = providers.gradleProperty("tensorflowHome")

data class TfArchive(val fileName: String, val isZip: Boolean)

fun tensorflowArchiveForCurrentPlatform(version: String): TfArchive {
  val os = System.getProperty("os.name").lowercase()
  val arch = System.getProperty("os.arch").lowercase()

  val isX86_64 = arch == "x86_64" || arch == "amd64"
  val platform = when {
    os.contains("mac") || os.contains("darwin") -> "darwin"
    os.contains("win") -> "windows"
    os.contains("nux") || os.contains("linux") -> "linux"
    else -> error("Unsupported OS for TensorFlow demo: os.name=$os os.arch=$arch")
  }

  if (!isX86_64) {
    error("TensorFlow prebuilt C library in this demo supports x86_64 only (got os.arch=$arch). " +
      "Use an x86_64 JDK (e.g. via Rosetta on Apple Silicon) or provide your own TF C library via -Dtensorflow.home=...")
  }

  return when (platform) {
    "windows" -> TfArchive("libtensorflow-cpu-windows-x86_64-$version.zip", isZip = true)
    "linux" -> TfArchive("libtensorflow-cpu-linux-x86_64-$version.tar.gz", isZip = false)
    "darwin" -> TfArchive("libtensorflow-cpu-darwin-x86_64-$version.tar.gz", isZip = false)
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
    val archive = tensorflowArchiveForCurrentPlatform(tensorflowVersion.get())
    val dest = tfArchiveDir.get().asFile.resolve(archive.fileName)
    dest.parentFile.mkdirs()
    if (dest.exists() && dest.length() > 0) return@doLast

    val url = "${tensorflowBaseUrl.get().trimEnd('/')}/${archive.fileName}"
    logger.lifecycle("Downloading TensorFlow C library: $url")
    URL(url).openStream().use { input ->
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
    val archive = tensorflowArchiveForCurrentPlatform(tensorflowVersion.get())
    val archiveFile = tfArchiveDir.get().asFile.resolve(archive.fileName)
    val intoDir = tfExtractedDir.get().asFile
    intoDir.mkdirs()

    copy {
      from(if (archive.isZip) zipTree(archiveFile) else tarTree(resources.gzip(archiveFile)))
      into(intoDir)
    }
  }
}

tasks.register<JavaExec>("runTensorFlow") {
  group = "demos"
  description = "Run the TensorFlow FFM demo (downloads TF C library)."

  if (!tensorflowHomeOverride.isPresent) {
    dependsOn("unpackTensorFlow")
  }

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)
  args("tensorflow")

  systemProperty(
    "tensorflow.home",
    tensorflowHomeOverride.orElse(tfExtractedDir.get().asFile.absolutePath).get()
  )
  jvmArgs(application.applicationDefaultJvmArgs)
}

graalvmNative {
  binaries {
    named("main") {
      imageName.set("conference-jvm")
      mainClass.set(application.mainClass)
    }
  }
}

plugins {
  base
}

val javaVersion = (findProperty("javaVersion") as String?)?.toIntOrNull() ?: 21

allprojects {
  repositories {
    mavenCentral()
  }
}

subprojects {
  plugins.withId("java") {
    extensions.configure<JavaPluginExtension> {
      toolchain {
        languageVersion.set(JavaLanguageVersion.of(javaVersion))
      }
    }
  }

  tasks.withType<Test>().configureEach {
    enabled = false
  }
}

// Master task: Run all smoke tests (quick validation)
tasks.register("runSmokeTests") {
  group = "validation"
  description = "Run all smoke tests (quick validation of all Java demos)"

  dependsOn(
    ":demos:tensorflow-ffm:run",
    ":demos:jcuda:run",
    ":demos:valhalla:run",
    ":demos:babylon:run",
    ":demos:tornadovm:run"
  )

  doFirst {
    println("=".repeat(70))
    println("Running Smoke Tests - Quick Validation")
    println("=".repeat(70))
    println("  1. TensorFlow FFM")
    println("  2. JCuda")
    println("  3. Valhalla (Vector API + FP16)")
    println("  4. Babylon (RuntimeCheck)")
    println("  5. TornadoVM (Baseline)")
    println("=".repeat(70))
    println()
  }
}

// ============================================================================
// Babylon JDK Build Tasks
// ============================================================================
// Build Babylon JDK from source at ~/Github/babylon
// Prerequisites: Xcode (macOS), build-essential (Linux), boot JDK 23+

val babylonSourceDir = file(System.getenv("HOME") + "/Github/babylon")
val babylonBuildDir = file(babylonSourceDir.path + "/build")
val babylonJdkInstallDir = file(System.getenv("HOME") + "/.sdkman/candidates/java/babylon-26-code-reflection")

// Detect platform-specific build directory name
val babylonPlatformBuildDir: File by lazy {
  val osName = System.getProperty("os.name").lowercase()
  val osArch = System.getProperty("os.arch")
  val platform = when {
    osName.contains("mac") && osArch == "aarch64" -> "macosx-aarch64-server-release"
    osName.contains("mac") -> "macosx-x86_64-server-release"
    osName.contains("linux") && osArch == "aarch64" -> "linux-aarch64-server-release"
    osName.contains("linux") -> "linux-x86_64-server-release"
    else -> "unknown-platform"
  }
  file(babylonBuildDir.path + "/$platform")
}

val babylonJdkImageDir: File by lazy {
  file(babylonPlatformBuildDir.path + "/images/jdk")
}

tasks.register<Exec>("babylonConfigure") {
  group = "babylon"
  description = "Configure Babylon JDK build (run once before building)"

  workingDir = babylonSourceDir
  commandLine("bash", "configure",
    "--with-conf-name=release",
    "--with-debug-level=release"
  )

  doFirst {
    if (!babylonSourceDir.exists()) {
      throw GradleException("""
        |Babylon source not found at: $babylonSourceDir
        |
        |Clone it with:
        |  git clone https://github.com/openjdk/babylon.git ~/Github/babylon
      """.trimMargin())
    }
    println("Configuring Babylon JDK build...")
    println("Source: $babylonSourceDir")
  }

  onlyIf {
    // Skip if already configured
    !file(babylonPlatformBuildDir.path + "/spec.gmk").exists()
  }
}

tasks.register("babylonBuild") {
  group = "babylon"
  description = "Build Babylon JDK from source (takes 10-30 minutes)"

  doLast {
    if (!babylonSourceDir.exists()) {
      throw GradleException("Babylon source not found at: $babylonSourceDir")
    }

    // Auto-configure if needed
    if (!file(babylonPlatformBuildDir.path + "/spec.gmk").exists()) {
      println("Build not configured, running configure first...")
      val configureProcess = ProcessBuilder("bash", "configure")
        .directory(babylonSourceDir)
        .inheritIO()
        .start()
      val configureExitCode = configureProcess.waitFor()
      if (configureExitCode != 0) {
        throw GradleException("Configure failed with exit code $configureExitCode")
      }
    }

    println("=" .repeat(70))
    println("Building Babylon JDK from source")
    println("=" .repeat(70))
    println("Source:  $babylonSourceDir")
    println("Output:  $babylonJdkImageDir")
    println("CPUs:    ${Runtime.getRuntime().availableProcessors()}")
    println("=" .repeat(70))

    val buildProcess = ProcessBuilder("make", "images", "JOBS=${Runtime.getRuntime().availableProcessors()}")
      .directory(babylonSourceDir)
      .inheritIO()
      .start()
    val buildExitCode = buildProcess.waitFor()
    if (buildExitCode != 0) {
      throw GradleException("Build failed with exit code $buildExitCode")
    }

    println()
    println("=" .repeat(70))
    println("Babylon JDK build complete!")
    println("JDK location: $babylonJdkImageDir")
    println()
    println("To use: export JAVA_HOME=$babylonJdkImageDir")
    println("Or run: ./gradlew babylonInstall")
    println("=" .repeat(70))
  }
}

tasks.register<Exec>("babylonClean") {
  group = "babylon"
  description = "Clean Babylon JDK build"

  workingDir = babylonSourceDir
  commandLine("make", "clean")

  onlyIf { babylonSourceDir.exists() }
}

tasks.register("babylonInstall") {
  group = "babylon"
  description = "Install built Babylon JDK to SDKMAN directory"

  doLast {
    if (!babylonJdkImageDir.exists()) {
      throw GradleException("""
        |Babylon JDK not built yet. Run: ./gradlew babylonBuild
        |Expected at: $babylonJdkImageDir
      """.trimMargin())
    }

    // Create symlink to SDKMAN candidates directory
    val sdkmanDir = file(System.getenv("HOME") + "/.sdkman/candidates/java")
    if (!sdkmanDir.exists()) {
      println("SDKMAN not found, skipping SDKMAN installation")
      println("JDK available at: $babylonJdkImageDir")
      return@doLast
    }

    // Remove existing symlink/directory if present
    if (babylonJdkInstallDir.exists()) {
      if (java.nio.file.Files.isSymbolicLink(babylonJdkInstallDir.toPath())) {
        babylonJdkInstallDir.delete()
      } else {
        throw GradleException("$babylonJdkInstallDir exists and is not a symlink. Remove it manually.")
      }
    }

    // Create symlink
    java.nio.file.Files.createSymbolicLink(
      babylonJdkInstallDir.toPath(),
      babylonJdkImageDir.toPath()
    )

    println("=" .repeat(70))
    println("Babylon JDK installed to SDKMAN!")
    println("=" .repeat(70))
    println()
    println("To use with SDKMAN:")
    println("  sdk use java babylon-26-code-reflection")
    println()
    println("To use directly:")
    println("  export JAVA_HOME=$babylonJdkInstallDir")
    println("=" .repeat(70))
  }
}

tasks.register("babylonInfo") {
  group = "babylon"
  description = "Show Babylon JDK build information"

  doLast {
    println("=" .repeat(70))
    println("Babylon JDK Build Information")
    println("=" .repeat(70))
    println()
    println("Source directory:   $babylonSourceDir")
    println("Source exists:      ${babylonSourceDir.exists()}")
    println()
    println("Build directory:    $babylonPlatformBuildDir")
    println("Build exists:       ${babylonPlatformBuildDir.exists()}")
    println()
    println("JDK image:          $babylonJdkImageDir")
    println("JDK built:          ${babylonJdkImageDir.exists()}")
    println()
    println("SDKMAN install:     $babylonJdkInstallDir")
    println("SDKMAN installed:   ${babylonJdkInstallDir.exists()}")

    if (babylonJdkImageDir.exists()) {
      println()
      println("JDK Version:")
      ProcessBuilder(babylonJdkImageDir.path + "/bin/java", "--version")
        .inheritIO()
        .start()
        .waitFor()
    }
    println("=" .repeat(70))
  }
}

// ============================================================================
// Master task: Run all LLM inference benchmarks
tasks.register("runBenchmarks") {
  group = "benchmarking"
  description = "Run all LLM inference benchmarks (requires model)"

  // Note: GraalPy's llama task is expected to fail (demonstrates ctypes limitation)
  // We don't add it as a dependency to avoid failing the whole build

  doFirst {
    println("=".repeat(70))
    println("Running LLM Inference Benchmarks")
    println("=".repeat(70))
    println("Model: ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf")
    println()
    println("  1. Llama3.java (Pure Java, Vector API)")
    println("  2. java-llama.cpp (JNI + Metal/CUDA GPU)")
    println("  3. GraalPy - runtimeCheck (basic embedding)")
    println("  4. GraalPy - llamaPython (CPython LLM)")
    println("  5. GraalPy - llama (expected to fail)")
    println("=".repeat(70))
    println()
  }

  doLast {
    // Run benchmarks sequentially to see results clearly
    fun runGradle(vararg args: String, ignoreFailure: Boolean = false) {
      val process = ProcessBuilder("./gradlew", *args, "--no-daemon")
        .inheritIO()
        .start()
      val exitCode = process.waitFor()
      if (exitCode != 0 && !ignoreFailure) {
        throw GradleException("Command failed with exit code $exitCode")
      }
    }

    runGradle(":demos:llama3-java:run")
    runGradle(":demos:java-llama-cpp:run")
    runGradle(":demos:graalpy:runtimeCheck")
    runGradle(":demos:graalpy:llamaPython")

    // Run GraalPy LLM (expected to fail) - don't fail the build
    runGradle(":demos:graalpy:llama", ignoreFailure = true)

    println()
    println("=".repeat(70))
    println("Benchmarks Complete!")
    println("Note: GraalPy LLM failure is expected (ctypes limitation)")
    println("=".repeat(70))
  }
}

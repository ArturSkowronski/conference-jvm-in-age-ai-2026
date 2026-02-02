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

// Master task: Run all LLM inference benchmarks
tasks.register("runBenchmarks") {
  group = "benchmarking"
  description = "Run all LLM inference benchmarks (requires model)"

  // Note: GraalPy's runGraalPyLlama is expected to fail (demonstrates ctypes limitation)
  // We don't add it as a dependency to avoid failing the whole build

  doFirst {
    println("=".repeat(70))
    println("Running LLM Inference Benchmarks")
    println("=".repeat(70))
    println("Model: ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf")
    println()
    println("  1. Llama3.java (Pure Java, Vector API)")
    println("  2. java-llama.cpp (JNI + Metal/CUDA GPU)")
    println("  3. GraalPy - runSmoke (basic embedding)")
    println("  4. GraalPy - runCPythonLlama (CPython LLM)")
    println("  5. GraalPy - runGraalPyLlama (expected to fail)")
    println("=".repeat(70))
    println()
  }

  doLast {
    // Run benchmarks sequentially to see results clearly
    exec {
      commandLine("./gradlew", ":demos:llama3-java:run", "--no-daemon")
    }
    exec {
      commandLine("./gradlew", ":demos:java-llama-cpp:run", "--no-daemon")
    }
    exec {
      commandLine("./gradlew", ":demos:graalpy:runSmoke", "--no-daemon")
    }
    exec {
      commandLine("./gradlew", ":demos:graalpy:runCPythonLlama", "--no-daemon")
    }

    // Run GraalPy LLM (expected to fail) - don't fail the build
    exec {
      commandLine("./gradlew", ":demos:graalpy:runGraalPyLlama", "--no-daemon")
      isIgnoreExitValue = true
    }

    println()
    println("=".repeat(70))
    println("Benchmarks Complete!")
    println("Note: GraalPy LLM failure is expected (ctypes limitation)")
    println("=".repeat(70))
  }
}

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

  dependsOn(
    ":demos:llama3-java:run",
    ":demos:java-llama-cpp:run",
    ":demos:graalpy:run"
  )

  doFirst {
    println("=".repeat(70))
    println("Running LLM Inference Benchmarks")
    println("=".repeat(70))
    println("Model: ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf")
    println()
    println("  1. Llama3.java (Pure Java, Vector API)")
    println("  2. java-llama.cpp (JNI + Metal/CUDA GPU)")
    println("  3. GraalPy suite (basic + CPython + GraalPy)")
    println("=".repeat(70))
    println()
  }
}

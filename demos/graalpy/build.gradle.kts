plugins {
  application
  java
}

dependencies {
  compileOnly("org.graalvm.sdk:graal-sdk:25.0.1")
  runtimeOnly("org.graalvm.polyglot:python:25.0.1") {
    exclude(group = "org.graalvm.truffle", module = "truffle-runtime")
    exclude(group = "org.graalvm.truffle", module = "truffle-compiler")
  }
}

application {
  mainClass.set("com.skowronski.talk.jvmai.GraalPyFromJava")
  applicationDefaultJvmArgs = listOf(
    "-Dpolyglotimpl.DisableVersionChecks=true",
    "-Dpolyglot.engine.WarnInterpreterOnly=false"
  )
}

// Task 1: Basic GraalPy embedding (smoke test)
tasks.register<JavaExec>("runSmoke") {
  group = "application"
  description = "Run basic GraalPy embedding demo (smoke test - works)"
  mainClass.set("com.skowronski.talk.jvmai.GraalPyFromJava")
  classpath = sourceSets.main.get().runtimeClasspath
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Task 2: CPython LLM inference
tasks.register<Exec>("runCPythonLlama") {
  group = "application"
  description = "Run CPython LLM inference (works - shows CPython compatibility)"
  workingDir = projectDir
  commandLine = listOf(
    "python3",
    "llama_inference.py",
    "--prompt",
    "Tell me a short joke about programming.",
    "--max-tokens",
    "32"
  )
}

// Task 3: GraalPy LLM attempt (fails)
tasks.register<JavaExec>("runGraalPyLlama") {
  group = "application"
  description = "Run GraalPy LLM inference demo (fails - demonstrates ctypes limitation)"
  mainClass.set("com.skowronski.talk.jvmai.GraalPyLlama")
  classpath = sourceSets.main.get().runtimeClasspath
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Override 'run' task to run all three demos (master task)
tasks.named("run") {
  group = "application"
  description = "Run all three GraalPy demos in sequence (smoke → CPython → GraalPy)"

  dependsOn("runSmoke", "runCPythonLlama", "runGraalPyLlama")

  doFirst {
    println("=".repeat(60))
    println("GraalPy Demo Suite - Running all three demos:")
    println("  1. runSmoke - Basic GraalPy embedding (✅ works)")
    println("  2. runCPythonLlama - CPython LLM inference (✅ works)")
    println("  3. runGraalPyLlama - GraalPy LLM attempt (❌ fails)")
    println("=".repeat(60))
    println()
  }
}

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

tasks.register<JavaExec>("runLlama") {
  group = "application"
  description = "Runs the GraalPy Llama inference demo (fails - demonstrates ctypes limitation)"
  mainClass.set("com.skowronski.talk.jvmai.GraalPyLlama")
  classpath = sourceSets.main.get().runtimeClasspath
  jvmArgs(application.applicationDefaultJvmArgs)
}

tasks.register<Exec>("runCPython") {
  group = "application"
  description = "Run CPython llama inference (works - shows CPython compatibility)"
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
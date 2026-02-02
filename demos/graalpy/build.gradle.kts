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
  description = "Runs the GraalPy Llama inference demo"
  mainClass.set("com.skowronski.talk.jvmai.GraalPyLlama")
  classpath = sourceSets.main.get().runtimeClasspath
  jvmArgs(application.applicationDefaultJvmArgs)
}
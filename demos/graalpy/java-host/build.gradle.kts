plugins {
  application
  java
}

dependencies {
  // SDK for compilation
  compileOnly("org.graalvm.sdk:graal-sdk:25.0.1")

  // GraalPy runtime - needed since GraalVM 23+ no longer bundles Python
  // This brings in the full Python runtime including Polyglot API implementation
  runtimeOnly("org.graalvm.polyglot:python:25.0.1")
}

application {
  mainClass.set("demo.GraalPyFromJava")
}

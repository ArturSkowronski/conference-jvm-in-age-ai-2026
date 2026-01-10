plugins {
  application
  java
}

dependencies {
  implementation("org.graalvm.sdk:graal-sdk:24.0.1")
}

application {
  mainClass.set("demo.GraalPyFromJava")
}


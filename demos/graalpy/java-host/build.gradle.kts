plugins {
  application
  java
}

dependencies {
  // Only needed for compilation on non-GraalVM JDKs.
  // At runtime we want to use the GraalVM-bundled Polyglot/Truffle classes to avoid version skew.
  compileOnly("org.graalvm.sdk:graal-sdk:24.0.1")
}

application {
  mainClass.set("demo.GraalPyFromJava")
}

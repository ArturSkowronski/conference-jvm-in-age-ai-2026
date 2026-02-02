plugins {
  application
  java
}

java {
  toolchain {
    languageVersion.set(JavaLanguageVersion.of(25))
  }
}

tasks.withType<JavaCompile> {
  options.compilerArgs.addAll(listOf(
    "--add-modules", "jdk.incubator.vector"
  ))
}

application {
  mainClass.set("com.skowronski.talk.jvmai.VectorAPIDemo")
  applicationDefaultJvmArgs = listOf(
    "--add-modules=jdk.incubator.vector"
  )
}

// Task 1: Vector API demo (FP32 operations)
tasks.register<JavaExec>("runVectorAPI") {
  group = "application"
  description = "Run Vector API demo (Float32 SIMD operations)"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set("com.skowronski.talk.jvmai.VectorAPIDemo")
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Task 2: FP16 Vector demo (half-precision)
tasks.register<JavaExec>("runFP16") {
  group = "application"
  description = "Run FP16 Vector demo (half-precision SIMD)"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set("com.skowronski.talk.jvmai.FP16VectorDemo")
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Default 'run' executes Vector API demo
tasks.named<JavaExec>("run") {
  mainClass.set("com.skowronski.talk.jvmai.VectorAPIDemo")
  jvmArgs(application.applicationDefaultJvmArgs)
}

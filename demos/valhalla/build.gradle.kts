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

// runtimeCheck executes both demos in sequence
tasks.register("runtimeCheck") {
  group = "application"
  description = "Run both Vector API and FP16 demos"
  dependsOn("runVectorAPI", "runFP16")

  doFirst {
    println("=".repeat(60))
    println("Valhalla Demo Suite - Running both demos:")
    println("  1. runVectorAPI - Float32 SIMD operations")
    println("  2. runFP16 - Float16 value type")
    println("=".repeat(60))
    println()
  }
}

// Default 'run' executes runtimeCheck
tasks.named("run") {
  dependsOn("runtimeCheck")
}

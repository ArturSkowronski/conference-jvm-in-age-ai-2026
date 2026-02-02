plugins {
  java
  application
}

val modelPath = providers.gradleProperty("model")
  .orElse("${System.getProperty("user.home")}/.llama/models/Llama-3.2-1B-Instruct-f16.gguf")
val prompt = providers.gradleProperty("prompt")
  .orElse("Tell me a short joke about programming.")

// Compile Llama3.java (single-file demo)
sourceSets {
  main {
    java {
      srcDir(".")
      include("Llama3.java")
    }
  }
}

tasks.withType<JavaCompile> {
  options.compilerArgs.addAll(listOf(
    "--add-modules", "jdk.incubator.vector"
  ))
}

application {
  mainClass.set("Llama3")
  applicationDefaultJvmArgs = listOf(
    "--add-modules=jdk.incubator.vector",
    "-Djdk.incubator.vector.VECTOR_ACCESS_OOB_CHECK=0"
  )
}

// Run with JDK 25 (best Vector API performance - ~40x faster than JDK 21)
tasks.register<JavaExec>("runJDK25") {
  group = "application"
  description = "Run with JDK 25 (best Vector API - ~13 tokens/sec)"

  javaLauncher.set(javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(25))
  })

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)
  jvmArgs(application.applicationDefaultJvmArgs)
  args = listOf("--instruct", "-m", modelPath.get(), "-p", prompt.get(), "--max-tokens", "32")
}

// Run with JDK 21 (slow Vector API - ~0.3 tokens/sec, for comparison)
tasks.register<JavaExec>("runJDK21") {
  group = "application"
  description = "Run with JDK 21 (old Vector API - ~0.3 tokens/sec, 40x slower!)"

  javaLauncher.set(javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(21))
  })

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)
  jvmArgs(application.applicationDefaultJvmArgs)
  args = listOf("--instruct", "-m", modelPath.get(), "-p", prompt.get(), "--max-tokens", "32")
}

// Smoke test - runs with JDK 25 (best performance)
tasks.register<JavaExec>("runSmoke") {
  group = "application"
  description = "Run smoke test with JDK 25 (recommended)"
  dependsOn("runJDK25")
}

// Default 'run' uses JDK 25
tasks.named<JavaExec>("run") {
  javaLauncher.set(javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(25))
  })
  jvmArgs(application.applicationDefaultJvmArgs)
  args = listOf("--instruct", "-m", modelPath.get(), "-p", prompt.get(), "--max-tokens", "32")
}

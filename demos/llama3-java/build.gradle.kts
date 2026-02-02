plugins {
  java
  application
}

val modelPath = providers.gradleProperty("model")
  .orElse("${System.getProperty("user.home")}/.llama/models/Llama-3.2-1B-Instruct-f16.gguf")
val prompt = providers.gradleProperty("prompt")
  .orElse("Tell me a short joke about programming.")

// Standard source directory (Llama3.java in src/main/java/com/skowronski/talk/jvmai/)

tasks.withType<JavaCompile> {
  options.compilerArgs.addAll(listOf(
    "--add-modules", "jdk.incubator.vector"
  ))
}

application {
  mainClass.set("com.skowronski.talk.jvmai.Llama3")
  applicationDefaultJvmArgs = listOf(
    "--add-modules=jdk.incubator.vector",
    "-Djdk.incubator.vector.VECTOR_ACCESS_OOB_CHECK=0"
  )
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

// Default 'run' uses JDK 25 (best performance)
tasks.named<JavaExec>("run") {
  group = "application"
  description = "Run with JDK 25 (best Vector API - ~13 tokens/sec)"

  javaLauncher.set(javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(25))
  })

  jvmArgs(application.applicationDefaultJvmArgs)
  args = listOf("--instruct", "-m", modelPath.get(), "-p", prompt.get(), "--max-tokens", "32")
}

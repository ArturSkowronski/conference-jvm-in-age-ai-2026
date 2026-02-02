plugins {
  application
  java
}

repositories {
  mavenCentral()
}

dependencies {
  implementation("de.kherud:llama:4.1.0")
}

application {
  mainClass.set("com.skowronski.talk.jvmai.JavaLlamaCppDemo")
}

// Main task - run with default model and prompt
tasks.register<JavaExec>("runSmoke") {
  group = "application"
  description = "Run java-llama.cpp demo with default prompt"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)

  args = listOf(
    "${System.getProperty("user.home")}/.llama/models/Llama-3.2-1B-Instruct-f16.gguf",
    "Tell me a short joke about programming."
  )
}

// Configure default 'run' task same as runSmoke
tasks.named<JavaExec>("run") {
  args = listOf(
    "${System.getProperty("user.home")}/.llama/models/Llama-3.2-1B-Instruct-f16.gguf",
    "Tell me a short joke about programming."
  )
}

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
  mainClass.set("conf.jvm.llama.JavaLlamaCppDemo")
}

tasks.register<JavaExec>("runLlama") {
  group = "demos"
  description = "Run java-llama.cpp inference demo"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)

  val defaultModel = "${System.getProperty("user.home")}/.llama/models/Llama-3.2-1B-Instruct-f16.gguf"
  val defaultPrompt = "Tell me a short joke about programming."

  val modelPath = if (project.hasProperty("model")) {
    project.property("model").toString()
  } else {
    defaultModel
  }

  val promptText = if (project.hasProperty("prompt")) {
    project.property("prompt").toString()
  } else {
    defaultPrompt
  }

  args = listOf(modelPath, promptText)
}

// Make the default 'run' task work with sensible defaults
tasks.named<JavaExec>("run") {
  args = listOf(
    "${System.getProperty("user.home")}/.llama/models/Llama-3.2-1B-Instruct-f16.gguf",
    "Tell me a short joke about programming."
  )
}

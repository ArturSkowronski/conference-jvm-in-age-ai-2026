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

// Configure default 'run' task with model and prompt
tasks.named<JavaExec>("run") {
  args = listOf(
    "${System.getProperty("user.home")}/.llama/models/Llama-3.2-1B-Instruct-f16.gguf",
    "Tell me a short joke about programming."
  )
}

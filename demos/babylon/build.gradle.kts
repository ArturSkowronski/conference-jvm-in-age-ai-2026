plugins {
  application
  java
}

java {
  toolchain {
    languageVersion.set(JavaLanguageVersion.of(25))
  }
}

application {
  mainClass.set("com.skowronski.talk.jvmai.RuntimeCheck")
  applicationDefaultJvmArgs = listOf(
    "--enable-preview",
    "--add-modules=jdk.incubator.code"
  )
}

// Runtime check - verifies Babylon Code Reflection API availability
tasks.register<JavaExec>("runSmoke") {
  group = "application"
  description = "Run Babylon runtime check (shows Code Reflection availability)"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Alias 'run' to 'runSmoke'
tasks.named<JavaExec>("run") {
  jvmArgs(application.applicationDefaultJvmArgs)
}

plugins {
  base
}

val javaVersion = (findProperty("javaVersion") as String?)?.toIntOrNull() ?: 21

allprojects {
  repositories {
    mavenCentral()
  }
}

subprojects {
  plugins.withId("java") {
    extensions.configure<JavaPluginExtension> {
      toolchain {
        languageVersion.set(JavaLanguageVersion.of(javaVersion))
      }
    }
  }

  tasks.withType<Test>().configureEach {
    enabled = false
  }
}

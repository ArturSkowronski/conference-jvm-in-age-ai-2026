plugins {
  application
  java
  id("org.graalvm.buildtools.native") version "0.10.2"
}

repositories {
  mavenCentral()
}

val javaVersion = (findProperty("javaVersion") as String?)?.toIntOrNull() ?: 21

java {
  toolchain {
    languageVersion.set(JavaLanguageVersion.of(javaVersion))
  }
}

application {
  mainClass.set("conf.jvm.Main")
}

tasks.test {
  enabled = false
}

graalvmNative {
  binaries {
    named("main") {
      imageName.set("conference-jvm")
      mainClass.set(application.mainClass)
    }
  }
}

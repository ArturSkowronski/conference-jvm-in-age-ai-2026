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

dependencies {
  implementation("org.jcuda:jcuda:12.6.0") {
    exclude(group = "org.jcuda", module = "jcuda-natives")
  }
  runtimeOnly("org.jcuda:jcuda-natives:12.6.0:linux-x86_64")
  runtimeOnly("org.jcuda:jcuda-natives:12.6.0:windows-x86_64")
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

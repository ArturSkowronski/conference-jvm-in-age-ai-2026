plugins {
  application
  java
}

dependencies {
  implementation("org.jcuda:jcuda:12.6.0") {
    exclude(group = "org.jcuda", module = "jcuda-natives")
  }
  runtimeOnly("org.jcuda:jcuda-natives:12.6.0:linux-x86_64")
  runtimeOnly("org.jcuda:jcuda-natives:12.6.0:windows-x86_64")
}

application {
  mainClass.set("com.skowronski.talk.jvmai.JCudaInfoDemo")
}

// Main task - query CUDA driver and device info
tasks.register<JavaExec>("runSmoke") {
  group = "application"
  description = "Run JCuda device info demo (queries CUDA driver)"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set(application.mainClass)
}

// Alias 'run' to 'runSmoke'
tasks.named("run") {
  dependsOn("runSmoke")
}

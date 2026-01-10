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
  mainClass.set("conf.jvm.jcuda.JCudaInfoDemo")
}

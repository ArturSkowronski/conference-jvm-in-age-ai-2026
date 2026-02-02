plugins {
  application
  java
}

repositories {
  mavenCentral()
}

// Note: TornadoVM requires special JDK 21 distribution
// This build provides baseline (CPU) demo only
// For TornadoVM GPU demo, use scripts/run-tornado.sh

dependencies {
  // TornadoVM dependencies would go here if running GPU version
  // For baseline demo, no dependencies needed
}

application {
  mainClass.set("com.skowronski.talk.jvmai.VectorAddBaseline")
}

// Baseline demo - runs on any JDK (CPU only)
tasks.register<JavaExec>("runBaseline") {
  group = "application"
  description = "Run baseline vector add (CPU, no TornadoVM)"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set("com.skowronski.talk.jvmai.VectorAddBaseline")
  args = listOf("--size", "10000000", "--iters", "5")
}

// Alias 'run' to 'runBaseline'
tasks.named<JavaExec>("run") {
  args = listOf("--size", "10000000", "--iters", "5")
}

// Note: TornadoVM GPU demo requires:
// 1. TornadoVM SDK installed
// 2. OpenCL/CUDA drivers
// 3. Use: ./scripts/run-tornado.sh
// 4. Or: ./scripts/run-gpullama3.sh for LLM demo

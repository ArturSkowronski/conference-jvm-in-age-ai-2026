plugins {
  application
  java
}

val babylonJdkHome = System.getenv("HOME") + "/.sdkman/candidates/java/babylon-26-code-reflection"
val hatBuildDir = System.getenv("HOME") + "/Github/babylon/hat/build"
val hasHat = file(hatBuildDir).exists()

java {
  toolchain {
    languageVersion.set(JavaLanguageVersion.of(26))
  }
}

tasks.withType<JavaCompile> {
  options.compilerArgs.addAll(listOf(
    "--enable-preview",
    "--add-modules", "jdk.incubator.code",
    "--add-exports", "java.base/jdk.internal.vm.annotation=ALL-UNNAMED"
  ))
}

// Add all HAT dependencies if available
dependencies {
  if (hasHat) {
    fileTree(hatBuildDir) {
      include("*.jar")
      exclude("hat-example-*.jar")  // Exclude example JARs
      exclude("hat-tests-*.jar")
    }.forEach {
      implementation(files(it))
    }
  }
}

// Note: HatMatMul.java kept as reference in demo root
// Cannot compile - requires matching HAT API version (NonMappableIface not in current HAT build)
// HAT API is experimental and changes frequently

application {
  mainClass.set("com.skowronski.talk.jvmai.RuntimeCheck")
  applicationDefaultJvmArgs = listOf(
    "--enable-preview",
    "--add-modules=jdk.incubator.code"
  )
}

// Task 1: Runtime check (works with any JDK 25+)
tasks.register<JavaExec>("runtimeCheck") {
  group = "application"
  description = "Run Babylon runtime check (shows Code Reflection availability)"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set("com.skowronski.talk.jvmai.RuntimeCheck")
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Note: HatMatMul.java cannot be compiled due to HAT API version mismatch
// For working HAT examples, run from HAT repository:
// cd ~/Github/babylon/hat && java @hat/run ffi-opencl matmul 2DTILING

// Default 'run' executes RuntimeCheck
tasks.named<JavaExec>("run") {
  group = "application"
  description = "Run Babylon RuntimeCheck (Code Reflection detection)"
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Note: runHatMatMul is available but HatMatMul.java is kept as reference
// HAT API is experimental and requires exact version matching
// For HAT examples, run directly: cd ~/Github/babylon/hat && java @hat/run ffi-opencl matmul 2DTILING

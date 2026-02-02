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

// Add HAT dependencies if available
dependencies {
  if (hasHat) {
    implementation(files("$hatBuildDir/hat-core-1.0.jar"))
    implementation(files("$hatBuildDir/hat-backend-ffi-opencl-1.0.jar"))
    implementation(files("$hatBuildDir/hat-backend-ffi-shared-1.0.jar"))
    implementation(files("$hatBuildDir/hat-optkl-1.0.jar"))
    implementation(files("$hatBuildDir/hat-tools-1.0.jar"))
  }
}

// Main.java (HAT MatMul) kept as reference file in demo root
// Requires specific HAT version compatibility - not compiled in standard build

application {
  mainClass.set("com.skowronski.talk.jvmai.RuntimeCheck")
  applicationDefaultJvmArgs = listOf(
    "--enable-preview",
    "--add-modules=jdk.incubator.code"
  )
}

// Task 1: Runtime check (works with any JDK 25+)
tasks.register<JavaExec>("runRuntimeCheck") {
  group = "application"
  description = "Run Babylon runtime check (shows Code Reflection availability)"

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set("com.skowronski.talk.jvmai.RuntimeCheck")
  jvmArgs(application.applicationDefaultJvmArgs)
}

// Task 2: HAT MatMul (requires Babylon JDK + HAT framework)
tasks.register<JavaExec>("runHatMatMul") {
  group = "application"
  description = "Run HAT MatMul GPU demo (requires Babylon JDK + HAT)"
  onlyIf { hasHat }

  javaLauncher.set(javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(26))
  })

  classpath = sourceSets.main.get().runtimeClasspath
  mainClass.set("com.skowronski.talk.jvmai.Main")
  jvmArgs(listOf(
    "--enable-preview",
    "--add-modules=jdk.incubator.code",
    "--add-exports=java.base/jdk.internal.vm.annotation=ALL-UNNAMED"
  ))
  args = listOf("ffi-opencl", "matmul", "2DTILING")
}

// Default 'run' executes runtime check
tasks.named<JavaExec>("run") {
  jvmArgs(application.applicationDefaultJvmArgs)
}

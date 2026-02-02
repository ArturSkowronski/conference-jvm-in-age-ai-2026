plugins {
  id("org.gradle.toolchains.foojay-resolver-convention") version "0.9.0"
}

rootProject.name = "conference-jvm-in-age-ai-2026"

include(":demos:jcuda")
include(":demos:tensorflow-ffm")
include(":demos:graalpy")
include(":demos:java-llama-cpp")
include(":demos:cpython-llama")
include(":demos:tornadovm")

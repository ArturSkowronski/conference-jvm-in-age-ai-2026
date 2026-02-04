plugins {
  id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

rootProject.name = "conference-jvm-in-age-ai-2026"

include(":demos:jcuda")
include(":demos:tensorflow-ffm")
include(":demos:graalpy")
include(":demos:java-llama-cpp")
include(":demos:llama3-java")
include(":demos:tornadovm")
include(":demos:valhalla")
include(":demos:babylon")

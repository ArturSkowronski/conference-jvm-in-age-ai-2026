rootProject.name = "conference-jvm-in-age-ai-2026"

include(":demos:jcuda")
include(":demos:tensorflow-ffm")
include(":demos:graalpy-java-host")
include(":demos:java-llama-cpp")
include(":tornadovm-demo")

project(":demos:graalpy-java-host").projectDir = file("demos/graalpy/java-host")

tasks.register<Exec>("run") {
    group = "application"
    description = "Run CPython llama inference with default prompt"

    workingDir = file("../graalpy-llama")
    commandLine = listOf(
        "python3",
        "llama_inference.py",
        "--prompt",
        "Tell me a short joke about programming."
    )
}

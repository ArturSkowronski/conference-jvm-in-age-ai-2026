# Demo: java-llama.cpp (JNI Bindings for llama.cpp)

This demo runs Llama model inference using [java-llama.cpp](https://github.com/kherud/java-llama.cpp) - Java JNI bindings for llama.cpp.

## What This Demo Shows

- Pure Java LLM inference via JNI bindings to llama.cpp
- Same GGUF model format as TornadoVM GPULlama3 and GraalPy Llama demos
- Native performance with Java API convenience
- Cross-platform support (Linux, macOS, Windows)

## Requirements

- JDK 17+
- Model file (Llama 3.2 1B Instruct in FP16 format)

## Model Setup

Download the same model used by other demos (~2.5 GB):

```bash
mkdir -p ~/.tornadovm/models
curl -L -o ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf \
  "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"
```

## Running

```bash
# Using default model and prompt
./gradlew :demos:java-llama-cpp:run

# With custom prompt
./gradlew :demos:java-llama-cpp:runLlama -Pprompt="Tell me a joke"

# With custom model path
./gradlew :demos:java-llama-cpp:runLlama -Pmodel=/path/to/model.gguf -Pprompt="Hello"
```

## Expected Output

```
============================================================
java-llama.cpp Inference Demo
============================================================
Java: 25
VM: OpenJDK 64-Bit Server VM
OS: Mac OS X aarch64
============================================================

Loading model: /Users/.../.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf
Model loaded in 19.47s

Prompt: Tell me a short joke about programming.
----------------------------------------
Response:
Why do programmers prefer dark mode?

Because light attracts bugs.
----------------------------------------

Stats:
  Model load time: 19.47s
  Inference time: 0.43s
  Tokens generated: 18
  Tokens/sec: 42.35
```

Note: On Apple Silicon, java-llama.cpp uses Metal acceleration achieving ~47 tokens/sec during inference.

## Comparison with Other Demos

| Demo | Technology | Backend | Binding Type |
|------|------------|---------|--------------|
| java-llama.cpp | Java + JNI | llama.cpp (CPU) | JNI |
| TornadoVM GPULlama3 | Java | OpenCL (GPU) | Pure Java |
| llama-cpp-python | Python | llama.cpp (CPU) | ctypes |

## Key Source File

- `src/main/java/conf/jvm/llama/JavaLlamaCppDemo.java`

## References

- [java-llama.cpp GitHub](https://github.com/kherud/java-llama.cpp)
- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [GGUF Model Format](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md)

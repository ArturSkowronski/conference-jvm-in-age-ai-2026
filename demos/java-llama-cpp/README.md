# java-llama.cpp Demo - JNI Bindings for llama.cpp

High-performance LLM inference using JNI bindings to llama.cpp with Metal/CUDA GPU acceleration.

## Quick Start

```bash
# Run with default prompt
./gradlew :demos:java-llama-cpp:run
```

**Expected output:**
```
Loading model from ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf...
Model loaded in 1.2s

Prompt: Tell me a short joke about programming.

Why do programmers prefer dark mode?
Because light attracts bugs!

✅ Generated 18 tokens in 0.36s (50.14 tokens/sec)
Tokens/sec: 50.14
```

## What This Demo Shows

- **JNI bindings** to native llama.cpp library
- **GPU acceleration** - Metal (macOS) or CUDA (Linux/Windows)
- **High performance** - ~50 tokens/sec on Apple M1 Pro with Metal
- **Simple API** - Just 2 lines of code to run inference
- **Prebuilt natives** - No compilation needed

## Requirements

- **JDK 21+**
- **Model file**: `~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf` (~2.5 GB)
- **GPU** (optional): Metal (macOS), CUDA (Linux/Windows)

## Setup

```bash
# Download model
./scripts/download-models.sh --fp16

# Or with SDKMAN
cd demos/java-llama-cpp
sdk env install && sdk env
```

## Running

```bash
# Default prompt
./gradlew :demos:java-llama-cpp:run

# Smoke test (same as run)
./gradlew :demos:java-llama-cpp:runSmoke
```

## Performance

**Apple M1 Pro (Metal GPU):**
- Model load: ~1-2 seconds
- Inference: ~50 tokens/sec
- GPU: Fully utilized via Metal

**Linux (CUDA):**
- Similar performance with NVIDIA GPU
- Requires CUDA drivers

**CPU-only:**
- ~3-5 tokens/sec (fallback mode)

## Code Structure

```
demos/java-llama-cpp/
├── src/main/java/com/skowronski/talk/jvmai/
│   └── JavaLlamaCppDemo.java    # Main demo (~50 lines)
├── build.gradle.kts             # Simple build (39 lines)
├── .sdkmanrc                    # Temurin 21
├── README.md                    # This file
└── Findings.md                  # JNI vs FFM analysis
```

## See Also

- **[Findings.md](Findings.md)** - JNI technical analysis
- **`demos/llama3-java/`** - Pure Java LLM (✅ ~13 tok/s, no GPU)
- **`demos/tensorflow-ffm/`** - FFM instead of JNI
- **`demos/graalpy/`** - Python embedding (CPython works, GraalPy fails)

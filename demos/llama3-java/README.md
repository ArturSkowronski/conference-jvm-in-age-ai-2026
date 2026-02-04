# Llama3.java - Pure Java LLM Inference

100% pure Java LLM inference with **no native dependencies** - demonstrates Java Vector API performance improvements.

## Quick Start

```bash
# Run with JDK 25 (recommended - ~40x faster than JDK 21!)
./gradlew :demos:llama3-java:run
```

**Expected output:**
```
Loading model...
Model loaded: Llama-3.2-1B-Instruct
Parameters: 1.24B
Prompt: Tell me a short joke about programming.

Why do programmers prefer dark mode?
Because light attracts bugs!

✅ Generated 18 tokens in 1.4s (~13 tokens/sec)
```

## What This Demo Shows

- **100% Pure Java** - No JNI, no native libraries
- **Vector API** - SIMD acceleration in pure Java
- **JDK version impact** - JDK 21 vs 25 performance difference (~40x!)
- **Single file** - Entire LLM implementation in one Java file (~3000 lines)
- **GGUF support** - Compatible with llama.cpp model format

## Requirements

- **JDK 21+** (JDK 25 strongly recommended)
- **Model**: `~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf` (~2.5 GB)

## Running

### Recommended: JDK 25 (~13 tokens/sec)

```bash
# Default - uses JDK 25
./gradlew :demos:llama3-java:run
```

### Comparison: JDK 21 (~0.3 tokens/sec)

```bash
# Shows how slow JDK 21 is (40x slower!)
./gradlew :demos:llama3-java:llama21
```

**Why the difference?** See [Findings.md](Findings.md) for Vector API performance analysis.

## Performance

**JDK 25 (Temurin or GraalVM):**
- Inference: ~13 tokens/sec
- Memory: ~3 GB (model loaded)
- CPU: Fully utilized with Vector API

**JDK 21 (any distribution):**
- Inference: ~0.3 tokens/sec
- **40x slower than JDK 25!**
- Same Vector API, different implementation

## All Available Tasks

```bash
# Run with JDK 25 (recommended)
./gradlew :demos:llama3-java:run

# Run with JDK 21 (comparison - 40x slower!)
./gradlew :demos:llama3-java:llama21

# Custom prompt
./gradlew :demos:llama3-java:run -Pprompt="Explain closures"
```

## Code Structure

```
demos/llama3-java/
├── src/main/java/com/skowronski/talk/jvmai/
│   └── Llama3.java              # Single-file LLM (~3000 lines)
├── build.gradle.kts             # Gradle tasks for JDK 21/25
├── .sdkmanrc                    # JDK 25
├── README.md                    # This file
└── Findings.md                  # Vector API analysis
```

## Why This Demo Matters

**Demonstrates:**
- Pure Java can do LLM inference
- Vector API performance is excellent (when optimized)
- JDK version matters enormously (40x difference!)
- No native dependencies = works everywhere

**Limitations:**
- CPU-only (no GPU acceleration)
- Slower than GPU solutions (java-llama.cpp: ~50 tok/s)
- But faster than you'd expect for pure Java!

## See Also

- **[Findings.md](Findings.md)** - Vector API deep dive, JDK 21 vs 25 analysis
- **`demos/java-llama-cpp/`** - JNI with GPU (~50 tok/s)
- **`demos/graalpy/`** - Python comparison
- **`demos/tensorflow-ffm/`** - FFM example


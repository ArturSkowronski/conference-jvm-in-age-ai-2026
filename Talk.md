# The JVM in the Age of AI - Demo Script

This document contains step-by-step commands for the live demo.

## Prerequisites

```bash
# Ensure SDKMAN is loaded and using correct JDK
sdk env install && sdk env

# Verify Java version (should be GraalVM CE 21)
java -version

# Download Llama models (required for LLM demos)
./scripts/download-models.sh
```

### Model Download Options

```bash
# Download all models (~3.3 GB total)
./scripts/download-models.sh --all

# Download only FP16 model (~2.5 GB) - for java-llama.cpp, TornadoVM, graalpy-llama
./scripts/download-models.sh --fp16

# Download only Q4_0 model (~0.8 GB) - for Llama3.java
./scripts/download-models.sh --q4

# Check download status
./scripts/download-models.sh --list
```

Models are stored in `~/.llama/models/`.

---

## Demo 1: TensorFlow via FFM (Foreign Function & Memory API)

**Goal**: Show how Java can call native C libraries (TensorFlow) directly using FFM - no JNI, no Python.

### What it demonstrates
- Java 22+ Foreign Function & Memory API
- Zero-overhead native library calls
- TensorFlow C API bindings written in pure Java

### Commands

```bash
# Run TensorFlow FFM demo (auto-downloads TF C library on first run)
./gradlew :demos:tensorflow-ffm:runTensorFlow
```

### Expected output
```
TensorFlow via FFM (C API)
TF_Version=2.18.0
1.5 + 2.25 = 3.75
```

> **Note**: TensorFlow 2.18.0 is used on all platforms. macOS x86_64 (Intel) is not supported
> because TensorFlow dropped Intel Mac support after version 2.16.2.

### Key source file
- `demos/tensorflow-ffm/src/main/java/conf/jvm/tensorflow/TensorFlowDemo.java`

---

## Demo 2: JCuda (NVIDIA GPU Access from Java)

**Goal**: Show how Java can directly access NVIDIA CUDA driver for GPU information.

### What it demonstrates
- JCuda bindings for CUDA driver API
- Direct GPU device enumeration
- Compute capability detection

### Commands

```bash
# Run JCuda demo (requires NVIDIA GPU + CUDA driver)
./gradlew :demos:jcuda:run
```

### Expected output (on machine with NVIDIA GPU)
```
== JCuda device info ==
os.name=Linux
os.arch=amd64
java.version=21.0.2
cuda.driverVersion=12060
cuda.deviceCount=1
cuda.device[0].name=NVIDIA GeForce RTX 4090
cuda.device[0].cc=8.9
```

### Expected output (no NVIDIA GPU)
```
== JCuda device info ==
os.name=Mac OS X
os.arch=aarch64
java.version=21.0.2
JCuda unavailable: java.lang.UnsatisfiedLinkError: ...
```

### Key source file
- `demos/jcuda/src/main/java/conf/jvm/jcuda/JCudaInfoDemo.java`

---

## Demo 3: GraalPy (Python on GraalVM)

**Goal**: Show Python running on GraalVM with seamless Java interoperability.

### What it demonstrates
- GraalPy: Python implementation on GraalVM
- Java-to-Python interop (embedding Python in Java via Polyglot API)
- Zero-copy data sharing between Java and Python

> **Note**: In GraalVM 21+, the `gu` tool is deprecated. GraalPy is now available as a
> Maven dependency (used by the Java host demo) or as a standalone distribution.

### 3.1 Embed Python in Java (Polyglot API) - RECOMMENDED

```bash
# Run Java application that embeds Python
./gradlew :demos:graalpy-java-host:run
```

**Expected output:**
```
python.version=3.12.8 (Thu Jan 15 11:43:30 CET 2026)
[Graal, Interpreted, Java 25 (aarch64)]
1.5 + 2.25 = 3.75
```

### 3.2 Standalone GraalPy (Optional)

If you have standalone GraalPy installed, you can also run Python scripts directly:

```bash
# Install standalone GraalPy (if needed)
# Download from: https://github.com/oracle/graalpython/releases

# Run simple Python script
graalpy demos/graalpy/python/01_hello.py

# Run Python with Java interop (JVM mode)
graalpy --jvm demos/graalpy/python/02_java_from_python.py
```

### Key source files
- `demos/graalpy/java-host/src/main/java/demo/GraalPyFromJava.java`
- `demos/graalpy/python/01_hello.py`
- `demos/graalpy/python/02_java_from_python.py`

---

## Demo 4: TornadoVM (GPU Acceleration for Java)

**Goal**: Show how TornadoVM accelerates Java code on GPUs with minimal code changes.

### What it demonstrates
- `@Parallel` annotation for loop parallelization
- TaskGraph API for defining GPU workloads
- Automatic compilation to OpenCL/CUDA/SPIR-V
- Performance comparison: CPU baseline vs GPU

### 4.1 Baseline (Plain Java, CPU only)

```bash
# Run vector addition on CPU (plain Java)
./tornadovm-demo/scripts/run-baseline.sh --size 10000000 --iters 5
```

**Expected output:**
```
Baseline: size=10000000, best=4.309 ms, throughput=25.93 GB/s
Verify: OK
```

### 4.2 TornadoVM (GPU accelerated)

```bash
# Run vector addition on GPU via TornadoVM
./tornadovm-demo/scripts/run-tornado.sh --size 10000000 --iters 5
```

**Expected output:**
```
=== TornadoVM Demo Runner ===
Using SDKMAN GraalVM CE: /path/to/java
Using cached TornadoVM SDK: .../tornadovm-2.2.0-opencl

=== TornadoVM Demo ===
Devices:
  Driver: OpenCL
  Tornado device=0:0 (DEFAULT)
  Global Memory Size: 25.0 GB

TornadoVM: size=10000000, best=2.416 ms, throughput=46.26 GB/s
Verify: OK
```

**Performance gain: ~1.8x faster than baseline!**

### 4.3 GPULlama3 (Real-world LLM Inference)

```bash
# Setup: Download FP16 model if not present
mkdir -p ~/.llama/models
# curl -L -o ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
#   "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"

# Run LLM inference on GPU
export TORNADOVM_HOME=./tornadovm-demo/build/tornadovm-sdk/tornadovm-2.2.0-opencl
./tornadovm-demo/scripts/run-gpullama3.sh \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Tell me a joke about Java programming"
```

**Expected output:**
```
Hello! How can I assist you today?

achieved tok/s: 6.64. Tokens: 21, seconds: 3.16
```

### Key source files
- `tornadovm-demo/src/baseline/java/demo/baseline/VectorAddBaseline.java`
- `tornadovm-demo/src/tornado/java/demo/tornadovm/VectorAddTornado.java`

---

## Demo 5: GraalPy Llama (Python LLM Inference)

**Goal**: Show Python ML libraries running on GraalVM's Python implementation.

### What it demonstrates
- Running llama-cpp-python on GraalPy
- Same GGUF model format as TornadoVM GPULlama3
- Cross-language model sharing in the JVM ecosystem

### Commands

```bash
cd demos/graalpy-llama

# With GraalPy (currently blocked - see Known Limitation)
./scripts/run-llama.sh --prompt "tell me a joke"

# Workaround: Use CPython instead
pip3 install llama-cpp-python
python3 llama_inference.py --prompt "tell me a joke"
```

### Known Limitation

GraalPy 25.0.1 fails with:
```
SystemError: ctypes: returning struct by value is not supported.
```

The [Truffle NFI](https://www.graalvm.org/latest/graalvm-as-a-platform/language-implementation-framework/NFI/) does not support struct return types, which `llama-cpp-python` requires.

### Key source file
- `demos/graalpy-llama/llama_inference.py`

---

## Demo 6: java-llama.cpp (JNI Bindings for llama.cpp)

**Goal**: Show pure Java LLM inference using JNI bindings to llama.cpp.

### What it demonstrates
- Java JNI bindings to llama.cpp
- Same GGUF model format as other demos
- Native performance with Java API convenience
- Cross-platform support (Linux, macOS, Windows)

### Commands

```bash
# Run with default model and prompt
./gradlew :demos:java-llama-cpp:run

# With custom prompt
./gradlew :demos:java-llama-cpp:runLlama -Pprompt="Tell me a joke"

# With custom model path
./gradlew :demos:java-llama-cpp:runLlama -Pmodel=/path/to/model.gguf -Pprompt="Hello"
```

### Expected output

```
============================================================
java-llama.cpp Inference Demo
============================================================
Java: 25
VM: OpenJDK 64-Bit Server VM
OS: Mac OS X aarch64
============================================================

Loading model: ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf
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

### Key source file
- `demos/java-llama-cpp/src/main/java/conf/jvm/llama/JavaLlamaCppDemo.java`

### References
- [java-llama.cpp GitHub](https://github.com/kherud/java-llama.cpp)

---

## Demo 7: Llama3.java (Pure Java LLM Inference)

**Goal**: Show 100% pure Java LLM inference with no native dependencies.

### What it demonstrates
- Single-file pure Java implementation (~3000 lines)
- Java Vector API for SIMD acceleration
- GraalVM JIT optimizations
- No JNI, no native libraries - runs anywhere Java runs

### Commands

```bash
# Download Q4_0 model (recommended for Llama3.java)
curl -L -o ~/.llama/models/Llama-3.2-1B-Instruct-Q4_0.gguf \
  "https://huggingface.co/hugging-quants/Llama-3.2-1B-Instruct-Q4_0-GGUF/resolve/main/llama-3.2-1b-instruct-q4_0.gguf"

# Run with script
./demos/llama3-java/scripts/run-llama3.sh --prompt "Tell me a joke"

# Or run directly
java --enable-preview --source 21 --add-modules jdk.incubator.vector \
  demos/llama3-java/Llama3.java --instruct \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-Q4_0.gguf \
  --prompt "Tell me a joke"
```

### Expected output

```
============================================================
Llama3.java - Pure Java LLM Inference
============================================================
Java: java version "21.0.5" 2024-10-15 LTS
Model: ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf
Mode: --instruct
============================================================

Parse model: 673 millis
Load LlaMa model: 345 millis

A man walked into a library and asked the librarian, "Do you have any
books on Pavlov's dogs and Schrödinger's cat?" The librarian replied,
"It rings a bell, but I'm not sure if it's here or not."

context: 69/256 prompt: 2.65 tokens/s (15) generation: 12.20 tokens/s (54)
```

### Key Features
- **Zero dependencies** - pure Java, no native code
- **Vector API** - SIMD acceleration via `jdk.incubator.vector`
- **GraalVM Native Image** - supports AOT compilation with model preloading

### Key source file
- `demos/llama3-java/Llama3.java`

### References
- [Llama3.java GitHub](https://github.com/mukel/llama3.java)

---

## Performance Comparison: LLM Inference

All tests using **Llama 3.2 1B Instruct (FP16)** model on macOS ARM64 (Apple Silicon):

| Approach | Language | Backend | Tokens/sec | Status |
|----------|----------|---------|------------|--------|
| java-llama.cpp | Java | llama.cpp (JNI+Metal) | ~47.0 | ✅ Working |
| Llama3.java | Pure Java | Vector API (CPU) | ~12.2 | ✅ Working |
| llama-cpp-python (CPython) | Python | llama.cpp (CPU+Metal) | ~10.0 | ✅ Working |
| TornadoVM GPULlama3 | Java | OpenCL (GPU) | ~6.6 | ✅ Working |
| llama-cpp-python (GraalPy) | Python | llama.cpp | N/A | ❌ Blocked (ctypes) |

### Observations

- **java-llama.cpp** achieves highest throughput (~47 tok/s) - JNI bindings to llama.cpp with Metal GPU acceleration
- **Llama3.java** pure Java implementation - no native dependencies, uses Vector API for SIMD
- **CPython + llama.cpp** good performance (~10 tok/s) with Metal acceleration on Apple Silicon
- **TornadoVM GPULlama3** runs pure Java on OpenCL (~6.6 tok/s), demonstrating JVM-native GPU inference without native bindings
- **GraalPy** blocked by ctypes limitation - waiting for Truffle NFI struct return support

### Model Load Times

| Approach | Model Load | First Token Latency |
|----------|------------|---------------------|
| Llama3.java | ~1s | ~6s |
| java-llama.cpp | ~19s | <1s |
| TornadoVM GPULlama3 | ~5s | ~3s |
| llama-cpp-python (CPython) | ~23s | ~5s |

---

## Summary

| Demo | Technology | Key Feature | Platform |
|------|------------|-------------|----------|
| TensorFlow FFM | Java 22+ FFM API | Native C library calls without JNI | Linux x86_64, macOS ARM64, Windows |
| JCuda | JCuda bindings | Direct CUDA driver access | NVIDIA GPU |
| GraalPy | GraalVM Polyglot | Python-Java interoperability | All |
| TornadoVM | TornadoVM SDK | GPU acceleration with @Parallel | OpenCL/CUDA |
| GraalPy Llama | GraalPy + llama-cpp | Python ML on GraalVM | Blocked (ctypes) |
| java-llama.cpp | JNI bindings | LLM inference via llama.cpp | Linux, macOS, Windows |
| Llama3.java | Pure Java | 100% Java LLM, Vector API | All (no native deps) |

---

## Troubleshooting

### TensorFlow FFM
- Requires JDK 22+ (FFM is final in Java 22)
- Uses TensorFlow 2.18.0 on all platforms
- **Supported**: Linux x86_64, macOS ARM64 (Apple Silicon), Windows x86_64
- **Not supported**: macOS x86_64 (Intel) - TensorFlow dropped support after 2.16.2
- Auto-downloads TensorFlow C library on first run

### JCuda
- Requires NVIDIA GPU + CUDA driver
- Will show helpful error message on non-NVIDIA systems (Mac, AMD, etc.)
- Error: `JCuda unavailable: This CUDA version is not available on MacOS`

### GraalPy
- The `gu` tool is deprecated in GraalVM 21+
- Use the Gradle demo which pulls GraalPy as a Maven dependency
- For standalone: download from https://github.com/oracle/graalpython/releases
- Warning about `WarnInterpreterOnly` is normal when not using GraalVM JIT

### TornadoVM
- Requires JDK 21 + OpenCL/CUDA drivers
- Script auto-downloads TornadoVM SDK 2.2.0 on first run
- If JVMCI errors occur: `export JVMCI_CONFIG_CHECK=ignore` (auto-set in scripts)
- GPULlama3 requires **FP16 format** models (Q4_K_M not supported)
- Model location: `~/.llama/models/`

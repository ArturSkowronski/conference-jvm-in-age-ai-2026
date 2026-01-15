# The JVM in the Age of AI - Demo Script

This document contains step-by-step commands for the live demo.

## Prerequisites

```bash
# Ensure SDKMAN is loaded and using correct JDK
sdk env install && sdk env

# Verify Java version (should be GraalVM CE 21)
java -version
```

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
TF_Version=2.15.0
1.5 + 2.25 = 3.75
```

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
mkdir -p ~/.tornadovm/models
# curl -L -o ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf \
#   "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"

# Run LLM inference on GPU
export TORNADOVM_HOME=./tornadovm-demo/build/tornadovm-sdk/tornadovm-2.2.0-opencl
./tornadovm-demo/scripts/run-gpullama3.sh \
  --model ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf \
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

## Summary

| Demo | Technology | Key Feature |
|------|------------|-------------|
| TensorFlow FFM | Java 22+ FFM API | Native C library calls without JNI |
| JCuda | JCuda bindings | Direct CUDA driver access |
| GraalPy | GraalVM Polyglot | Python-Java interoperability |
| TornadoVM | TornadoVM SDK | GPU acceleration with @Parallel |

---

## Troubleshooting

### TensorFlow FFM
- Requires JDK 22+ (FFM is final)
- **x86_64 only** - on Apple Silicon use Rosetta JDK or provide custom TF build
- Error: `TensorFlow prebuilt C library in this demo supports x86_64 only`

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
- Model location: `~/.tornadovm/models/`

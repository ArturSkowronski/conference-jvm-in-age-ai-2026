# Running LLMs on the JVM: A Benchmarking Journey

*An opinionated exploration of local LLM inference options for Java developers*

---

## ⚠️ Benchmark Caveats (Read This First)

**This is not a fair, scientific benchmark.** It's an exploratory comparison with significant methodology issues:

### What's Wrong With These Numbers

1. **Apples vs Oranges (GPU vs CPU)**
   - java-llama.cpp uses **Metal GPU** acceleration → ~47 tok/s
   - Llama3.java uses **CPU only** (Vector API) → ~12 tok/s
   - Comparing these directly is like comparing a car to a bicycle. Of course the GPU is faster.

2. **Inconsistent GPU Backends**
   - java-llama.cpp: Metal (Apple-native, highly optimized)
   - TornadoVM: OpenCL (cross-platform, less optimized on Mac)
   - These are not equivalent. Metal has home-field advantage on Apple Silicon.

3. **The Python Mystery**
   - llama-cpp-python *should* also use Metal, yet shows only ~10 tok/s
   - java-llama.cpp with the same underlying llama.cpp shows ~47 tok/s
   - Likely cause: default `n_gpu_layers=0` in our Python script (not forcing GPU offload)
   - **This makes Python look worse than it actually is.**

4. **No Proper Methodology**
   - Single runs, not averaged over multiple iterations
   - No JIT warmup consideration for Java
   - Different response lengths affect tok/s calculations
   - Model load time conflated with inference time in some cases

5. **Hardware-Specific Results**
   - All tests on Apple M1 Pro with unified memory
   - Results would be completely different on x86, NVIDIA GPU, or cloud instances
   - Metal advantage disappears on non-Apple hardware

### What This Benchmark Actually Shows

Despite the flaws, there are valid takeaways:

- **Llama3.java at ~12 tok/s with zero native dependencies is genuinely impressive**
- **GraalPy's ctypes limitation is a real blocker** (not a benchmark issue)
- **The JVM has multiple viable paths to LLM inference** (the main point)

### What A Fair Benchmark Would Require

- Force GPU layers in Python: `Llama(model_path, n_gpu_layers=-1)`
- Multiple runs with warmup, report mean and std dev
- Separate model load time from inference time
- Test on multiple hardware configurations
- Control for response length (fixed token count)

---

## The Setup

**Model**: Llama 3.2 1B Instruct (FP16, 2.5 GB)
**Hardware**: Apple M1 Pro, 32 GB RAM
**Task**: Generate a short response to "Tell me a joke about programming"

Why this model? It's small enough to run on consumer hardware, yet large enough to produce coherent output. The 1B parameter size is the sweet spot for benchmarking—big enough to stress the system, small enough to iterate quickly.

**⚠️ Remember**: The numbers below are indicative, not definitive. See caveats above.

---

## Chapter 1: The Python Baseline

**llama-cpp-python with CPython 3.13**

Let's start where most ML practitioners begin: Python. The `llama-cpp-python` library wraps the excellent llama.cpp C++ implementation, providing a familiar Python interface.

```bash
python3 llama_inference.py --prompt "Tell me a joke about programming"
```

**Results:**
```
Model loaded in 2.07s
Response: Why do programmers prefer dark mode? Because light attracts bugs.
Tokens/sec: ~10
```

The experience is... fine. Model loads quickly, inference is reasonable. But here's what the numbers don't tell you: we're running a Python interpreter that's calling into C++ via ctypes, which is calling into Metal for GPU acceleration. That's a lot of layers.

**Verdict**: The comfortable choice. Works everywhere, vast ecosystem, but you're paying a tax for that convenience.

---

## Chapter 2: The GraalPy Experiment (Spoiler: It Doesn't Work)

**llama-cpp-python on GraalPy 25.0.1**

"What if we could run that same Python code on the JVM?" asks every Java architect who's been forced to maintain a Python sidecar. GraalPy promises exactly that—Python semantics on the GraalVM runtime.

```bash
./scripts/run-llama.sh --prompt "Tell me a joke"
```

**Results:**
```
SystemError: ctypes: returning struct by value is not supported.
```

Well. That's disappointing.

The issue is fundamental: `llama-cpp-python` uses Python's ctypes to call native code, and one of those calls (`llama_model_default_params()`) returns a C struct by value. GraalPy's Truffle NFI simply doesn't support this calling convention yet.

**The Insight**: This is actually a perfect illustration of why "just run Python on the JVM" is harder than it sounds. Python's ecosystem wasn't designed with JVM interop in mind. Every library that uses ctypes, cffi, or native extensions is a potential landmine.

**Verdict**: Not ready for production ML workloads. But keep watching this space—when GraalPy adds struct return support, this becomes a genuinely interesting option.

---

## Chapter 3: The JNI Bridge

**java-llama.cpp**

If you can't run Python's llama.cpp bindings on the JVM, what about Java bindings to the same library? Enter `java-llama.cpp`—JNI bindings to llama.cpp with prebuilt natives for all major platforms.

```bash
./gradlew :demos:java-llama-cpp:run
```

**Results:**
```
Model loaded in 19.47s
Response: Why do programmers prefer dark mode? Because light attracts bugs.
Tokens/sec: ~47
Eval time: 21.28 ms per token
```

Wait, what? **47 tokens per second?** That's nearly 5x faster than Python.

Here's why: java-llama.cpp ships with precompiled natives that have Metal acceleration baked in. When you run the Java code, it's calling directly into highly optimized C++ with GPU acceleration. The JNI overhead is negligible compared to Python's ctypes dance.

**The Catch**: That 19-second model load time is painful. The library is extracting and loading native libraries, initializing Metal contexts, and warming up the GPU. In a long-running server, this is amortized. For CLI tools, it hurts.

**Verdict**: The performance champion. If you need raw speed and can accept native dependencies, this is your answer. The API is clean, the performance is excellent, and it "just works" on macOS, Linux, and Windows.

---

## Chapter 4: Pure Java, No Compromises

**Llama3.java**

Here's where things get philosophically interesting. What if we didn't use any native code at all? What if we implemented transformer inference in pure Java?

That's exactly what Alfonso² Petersson's `Llama3.java` does—a single-file, ~3000-line Java implementation of Llama inference. No JNI. No native libraries. Just Java and the Vector API.

```bash
java --enable-preview --add-modules jdk.incubator.vector Llama3.java \
  --instruct --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Tell me a joke"
```

**Results:**
```
Parse model: 673 millis
Load LlaMa model: 345 millis
Response: A man walked into a library and asked the librarian...
Generation: 12.20 tokens/s
```

**12 tokens per second in pure Java.** No GPU. No native code. Just the JVM doing math.

Let that sink in. We're running a billion-parameter language model at 12 tokens/second using nothing but Java bytecode and SIMD intrinsics. The Vector API is doing the heavy lifting, turning those matrix multiplications into vectorized CPU instructions.

**The Trade-off**: You're leaving GPU acceleration on the table. On a machine with a powerful GPU, java-llama.cpp will destroy this. But on a CPU-only server? On an ARM instance without CUDA? Llama3.java runs anywhere the JVM runs.

**The Hidden Gem**: That sub-second model load time. No native library extraction, no GPU initialization. Just memory-map the file and go. For serverless or CLI scenarios, this matters enormously.

**Verdict**: The purist's choice. Slower than native bindings, but with zero external dependencies and remarkable portability. This is what "write once, run anywhere" looks like in the age of AI.

---

## Chapter 5: GPU Acceleration, The Java Way

**TornadoVM GPULlama3**

What if we could have both? Pure Java code that runs on the GPU?

TornadoVM is a plugin for the JVM that automatically compiles Java bytecode to OpenCL, CUDA, or SPIR-V. GPULlama3.java uses TornadoVM to run transformer inference on the GPU—without a single line of native code in the application layer.

```bash
export TORNADOVM_HOME=./tornadovm-sdk
./scripts/run-gpullama3.sh --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Tell me a joke"
```

**Results:**
```
achieved tok/s: 6.64. Tokens: 21, seconds: 3.16
```

**6.6 tokens per second.** Hmm. That's... slower than pure Java on the CPU?

Here's the uncomfortable truth: GPU acceleration isn't magic. There's overhead in:
1. Compiling Java bytecode to GPU kernels (first run)
2. Transferring data between CPU and GPU memory
3. Synchronizing between host and device

For small models like Llama 3.2 1B, this overhead can dominate. The GPU is fast at computation but slow at data movement. With a 1B model that fits comfortably in CPU cache, the Vector API on a fast CPU can actually win.

**Where TornadoVM Shines**: Larger models. Batch inference. Workloads where the computation time dwarfs the transfer time. At 7B or 13B parameters, the calculus changes dramatically.

**Verdict**: A glimpse of the future, not quite ready for the present. The promise of "Java on the GPU" is real, but the current implementation struggles with small models and single-request latency.

---

## The Scoreboard

| Approach | Tokens/sec | Model Load | Dependencies | GPU | Fair Comparison? |
|----------|------------|------------|--------------|-----|------------------|
| java-llama.cpp | **~47** | 19s | Native libs | Metal | ⚠️ GPU-accelerated |
| Llama3.java | ~12 | **<1s** | **None** | No | ✅ CPU baseline |
| llama-cpp-python | ~10* | 2s | Native libs | Metal? | ⚠️ GPU not forced |
| TornadoVM GPULlama3 | ~7 | 5s | TornadoVM | OpenCL | ⚠️ Different GPU API |
| GraalPy | ❌ | - | - | Blocked | N/A |

*\* Python result likely unfair—GPU layers not explicitly enabled. With `n_gpu_layers=-1`, expect ~40+ tok/s.*

**The only fair comparison**: Llama3.java (~12 tok/s) represents true CPU-only performance. Everything else involves GPU acceleration with different backends.

---

## So What Should You Use?

**For maximum performance**: java-llama.cpp. Accept the native dependency, enjoy the speed.

**For maximum portability**: Llama3.java. Runs on any JVM, no questions asked. The performance is surprisingly competitive.

**For Python compatibility**: Wait for GraalPy to fix ctypes struct returns, or just run Python separately.

**For research/experimentation**: TornadoVM. The technology is fascinating, even if the benchmarks are humbling.

---

## The Bigger Picture

What this benchmark really shows is the maturity of Java's compute capabilities in 2025:

1. **The Vector API works.** Llama3.java achieving 12 tok/s in pure Java would have been science fiction five years ago.

2. **JNI isn't dead.** When you need native performance, java-llama.cpp shows that Java can be a first-class citizen in the ML ecosystem.

3. **The GraalVM story is incomplete.** GraalPy is promising but not production-ready for ML workloads. Truffle NFI needs work.

4. **GPU programming in Java is early.** TornadoVM is impressive technology, but it's not a drop-in replacement for CUDA yet.

The JVM in the age of AI isn't about replacing Python—it's about giving Java developers real options. And for the first time, those options are genuinely competitive.

---

## Running the Benchmarks Yourself

```bash
# Download the model
./scripts/download-models.sh --fp16

# Python baseline
python3 demos/graalpy-llama/llama_inference.py \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Tell me a joke"

# java-llama.cpp
./gradlew :demos:java-llama-cpp:run

# Llama3.java
./demos/llama3-java/scripts/run-llama3.sh --prompt "Tell me a joke"

# TornadoVM (requires setup)
export TORNADOVM_HOME=./demos/tornadovm/build/tornadovm-sdk/tornadovm-2.2.0-opencl
./demos/tornadovm/scripts/run-gpullama3.sh \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Tell me a joke"
```

---

*Benchmarks conducted January 2026. Your results will vary based on hardware, model, and phase of the moon.*

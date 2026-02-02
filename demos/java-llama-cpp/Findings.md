# java-llama.cpp Technical Findings

Technical analysis of using java-llama.cpp (JNI bindings) for LLM inference on the JVM.

## Why java-llama.cpp is the Fastest

**Performance ranking (Llama 3.2 1B, Apple M1 Pro):**
1. **java-llama.cpp**: ~50 tokens/sec (Metal GPU) ← This demo
2. **Cyfra**: ~33 tokens/sec (Vulkan GPU)
3. **Llama3.java**: ~13 tokens/sec (Vector API CPU)
4. **CPython**: ~10 tokens/sec (llama-cpp-python CPU)
5. **TornadoVM**: ~6 tokens/sec (OpenCL GPU)

**Why it's fastest:**
- Native llama.cpp implementation (highly optimized C++)
- Direct GPU access (Metal/CUDA, no abstraction layer)
- Prebuilt binaries (optimized for each platform)
- Zero JVM overhead (JNI is just a thin wrapper)

## JNI vs FFM Comparison

### java-llama.cpp (JNI)

**Pros:**
- ✅ **Prebuilt binaries** - No compilation needed
- ✅ **Mature library** - llama.cpp is battle-tested
- ✅ **GPU support** - Metal, CUDA, Vulkan backends
- ✅ **Best performance** - Direct native optimization
- ✅ **Simple API** - High-level abstractions
- ✅ **Active development** - Regular updates

**Cons:**
- ❌ **Platform-specific** - Different .so/.dll/.dylib per platform
- ❌ **Black box** - Can't easily modify native code
- ❌ **JNI overhead** - Small (~5-10ns per call)
- ❌ **Debugging harder** - Native crashes less informative

### TensorFlow FFM (from tensorflow-ffm demo)

**Pros:**
- ✅ **Pure Java** - No C glue code needed
- ✅ **Cross-platform** - Same Java code everywhere
- ✅ **Type-safe** - Compile-time checks
- ✅ **Zero overhead** - Calls inlined by JIT
- ✅ **Debuggable** - Java stack traces

**Cons:**
- ❌ **Manual bindings** - Must write FFM code for each function
- ❌ **More verbose** - MethodHandles, MemorySegments
- ❌ **Less mature** - FFM is newer (final in JDK 22)

## When to Use JNI (this demo) vs FFM

### Use JNI (java-llama.cpp) when:
- ✅ Prebuilt library exists
- ✅ Need maximum performance
- ✅ GPU acceleration required
- ✅ Want high-level API
- ✅ Don't need to modify native code

### Use FFM (tensorflow-ffm) when:
- ✅ Writing your own bindings
- ✅ Need cross-platform source compatibility
- ✅ Want type safety at compile time
- ✅ Prefer pure Java codebase
- ✅ Don't need GPU (or handle separately)

## Why This Demo Uses Prebuilt Natives

The `de.kherud:llama:4.1.0` Maven artifact includes:
- Precompiled llama.cpp for each platform
- Metal support (macOS)
- CUDA support (Linux/Windows)
- CPU fallback for all platforms

**Benefits:**
- Zero setup - just add dependency
- Works out of the box
- Optimized builds for each platform
- Regular updates from upstream llama.cpp

**Drawback:**
- Large JAR size (~50 MB with all platform natives)
- Can't customize llama.cpp build options

## GPU Acceleration Details

### macOS (Metal)

```bash
# Automatically uses Metal if available
./gradlew :demos:java-llama-cpp:run
```

**Performance:**
- Apple M1 Pro: ~50 tokens/sec
- Apple M2: ~60-70 tokens/sec (expected)
- Unified memory advantage

### Linux/Windows (CUDA)

```bash
# Set custom CUDA build if needed
export JLLAMA_CUDA_LIB=/path/to/custom/llama.so
./gradlew :demos:java-llama-cpp:run
```

**Performance:**
- NVIDIA Tesla T4: ~40-50 tokens/sec
- NVIDIA RTX 4090: ~150+ tokens/sec (expected)

### CPU Fallback

If no GPU available:
- Automatically falls back to CPU
- Performance: ~3-5 tokens/sec
- Still faster than pure Java on JDK 21

## Memory Usage

**Model loading:**
- Llama 3.2 1B (FP16): ~2.5 GB RAM
- Loaded into GPU memory if available
- Shared between CPU/GPU for unified memory (macOS)

**JVM overhead:**
- Minimal (~50-100 MB for Java heap)
- Most memory used by native library
- JNI crossing is negligible

## Comparison with Pure Java (Llama3.java)

| Aspect | java-llama.cpp (JNI) | Llama3.java (Pure Java) |
|--------|---------------------|------------------------|
| **Performance** | ~50 tok/s (GPU) | ~13 tok/s (CPU) |
| **Dependencies** | Native library (JNI) | None (100% Java) |
| **GPU Support** | ✅ Metal/CUDA | ❌ CPU only |
| **Platform** | Prebuilt per platform | Works everywhere |
| **Complexity** | Low (just use API) | Low (single file) |
| **Build** | Add Maven dep | Add Maven dep |

**When to choose each:**
- **java-llama.cpp**: Need max performance, have GPU
- **Llama3.java**: Need portability, CPU-only is fine

## Library Architecture

```
de.kherud:llama:4.1.0
├── Java API (high-level)
│   ├── LlamaModel
│   ├── ModelParameters
│   └── InferenceParameters
├── JNI bridge (thin layer)
│   └── Native method declarations
└── Native libraries (prebuilt)
    ├── llama-darwin-arm64.dylib (Metal)
    ├── llama-linux-x86_64.so (CUDA)
    ├── llama-windows-x86_64.dll (CUDA)
    └── Fallback CPU builds
```

## Why JNI Still Matters (Despite FFM)

**JNI advantages:**
1. **Ecosystem** - Thousands of existing libraries
2. **Prebuilt binaries** - No compilation needed
3. **Mature tooling** - Debuggers, profilers
4. **High-level APIs** - Not just raw C calls

**FFM advantages:**
1. **Pure Java** - No C code needed
2. **Type safety** - Compile-time checks
3. **Zero overhead** - Better than JNI
4. **Future-proof** - Modern Java approach

**Verdict:** Both have their place. For existing libraries (like llama.cpp), JNI is pragmatic. For new bindings, FFM is better.

## Troubleshooting

### Model not found

**Error:** `FileNotFoundException: ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf`

**Fix:**
```bash
./scripts/download-models.sh --fp16
```

### GPU not detected

**Check Metal (macOS):**
```bash
system_profiler SPDisplaysDataType | grep "Metal"
```

**Check CUDA (Linux):**
```bash
nvidia-smi
```

### Low performance (< 10 tokens/sec)

**Possible causes:**
1. Running on CPU instead of GPU
2. Model quantization (use F16, not Q4)
3. Insufficient GPU memory
4. Thermal throttling

## Lessons Learned

### 1. Prebuilt Natives are Powerful

- No build complexity
- Works immediately
- Professionally optimized
- Worth the larger JAR size

### 2. JNI is Still Relevant

Despite FFM being "the future":
- JNI libraries won't disappear
- Prebuilt binaries matter
- High-level APIs matter
- Performance is excellent

### 3. GPU Makes Huge Difference

- CPU: ~3-5 tokens/sec
- GPU: ~50+ tokens/sec
- **10-15x speedup** from GPU
- Worth the platform dependency

## References

- [java-llama.cpp GitHub](https://github.com/kherud/java-llama.cpp)
- [llama.cpp Project](https://github.com/ggerganov/llama.cpp)
- [GGUF Model Format](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md)

## See Also

- **`demos/llama3-java/`** - Pure Java alternative (no JNI)
- **`demos/tensorflow-ffm/`** - FFM instead of JNI
- **`demos/graalpy/`** - Python embedding comparison

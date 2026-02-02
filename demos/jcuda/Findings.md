# JCuda Technical Findings

Analysis of using JCuda for GPU computing from Java, comparing with alternatives.

## JCuda Overview

**JCuda** provides Java bindings to the NVIDIA CUDA driver and runtime APIs, enabling direct GPU programming from Java.

**Architecture:**
```
Java Application
    ↓ (JNI)
JCuda Bindings (Java)
    ↓ (JNI)
CUDA Driver API (C)
    ↓
NVIDIA GPU
```

## Why JCuda is Useful

### Direct CUDA Access

JCuda maps directly to CUDA C API:

```java
// Java (JCuda)
cuInit(0);
int[] deviceCount = new int[1];
cuDeviceGetCount(deviceCount);

// Equivalent C (CUDA)
cuInit(0);
int deviceCount;
cuDeviceGetCount(&deviceCount);
```

**Benefits:**
- ✅ Full CUDA API access
- ✅ Existing CUDA knowledge transfers
- ✅ Low-level control
- ✅ Can use CUDA kernels (.ptx files)

## JCuda vs Alternatives

### Comparison Matrix

| Approach | Platform Support | Performance | Ease of Use | GPU Access |
|----------|-----------------|-------------|-------------|------------|
| **JCuda** | NVIDIA only | Excellent | Medium | Full CUDA API |
| **TornadoVM** | NVIDIA, AMD, Intel | Good | Easy | High-level (TaskGraph) |
| **FFM (custom)** | Any (DIY) | Excellent | Hard | Full (manual bindings) |
| **Aparapi** | OpenCL | Good | Easy | Limited (deprecated) |

### JCuda (this demo)

**Pros:**
- ✅ Full CUDA feature access
- ✅ Well-maintained (v12.6.0, updated regularly)
- ✅ Direct API mapping (easy for CUDA developers)
- ✅ Can load custom kernels (.ptx)
- ✅ Multiple APIs (Driver, Runtime, cuBLAS, cuDNN, etc.)

**Cons:**
- ❌ NVIDIA-only (no AMD/Intel)
- ❌ Requires CUDA drivers
- ❌ More verbose than TornadoVM
- ❌ Lower-level (more code needed)

### TornadoVM (see demos/tornadovm/)

**Pros:**
- ✅ Cross-platform (OpenCL, CUDA, PTX, SPIR-V)
- ✅ High-level API (TaskGraph)
- ✅ Java annotations (@Parallel)
- ✅ Automatic parallelization

**Cons:**
- ❌ Less control than JCuda
- ❌ Slower for some workloads
- ❌ Limited to supported operations
- ❌ Experimental (2.2.0)

### FFM Custom Bindings (see demos/tensorflow-ffm/)

**Pros:**
- ✅ Pure Java (no JNI)
- ✅ Zero overhead
- ✅ Type-safe
- ✅ Cross-platform source

**Cons:**
- ❌ Must write bindings manually
- ❌ Verbose (MethodHandles, MemorySegments)
- ❌ No high-level abstractions
- ❌ More work than using JCuda

## Platform Support Details

### Supported Platforms

**Linux x86_64:**
- ✅ Primary CUDA platform
- Native: `jcuda-natives:12.6.0:linux-x86_64`
- Requires NVIDIA drivers + CUDA toolkit

**Windows x86_64:**
- ✅ Full CUDA support
- Native: `jcuda-natives:12.6.0:windows-x86_64`
- Requires NVIDIA drivers + CUDA toolkit

### Unsupported Platforms

**macOS (all):**
- ❌ No CUDA support (Apple uses Metal)
- Demo handles gracefully (shows message)
- Alternative: Use TornadoVM or Metal-based solutions

**Linux ARM64:**
- ❌ No prebuilt JCuda natives for ARM64
- Would need custom build
- Alternative: Use TornadoVM (supports ARM GPUs via OpenCL)

## Build Configuration Insights

### Native Library Handling

```kotlin
implementation("org.jcuda:jcuda:12.6.0") {
  exclude(group = "org.jcuda", module = "jcuda-natives")
}
runtimeOnly("org.jcuda:jcuda-natives:12.6.0:linux-x86_64")
runtimeOnly("org.jcuda:jcuda-natives:12.6.0:windows-x86_64")
```

**Why exclude then re-add:**
- JCuda has classifiers for each platform
- Default dependency fails (Gradle can't resolve `${jcuda.os}` variable)
- Must explicitly specify platform classifiers
- Include both Linux and Windows for cross-platform builds

**Alternative approach:**
```kotlin
// This would fail:
implementation("org.jcuda:jcuda:12.6.0")
// Error: Could not resolve jcuda-natives:${jcuda.os}
```

### Graceful Degradation

The demo handles CUDA absence gracefully:

```java
try {
  JCudaDriver.setExceptionsEnabled(true);
  cuInit(0);
  // CUDA available - show device info
} catch (Exception e) {
  // CUDA not available - show helpful message
  System.out.println("[JCuda] CUDA not available on this platform");
}
```

**Benefits:**
- Works on all platforms (shows different output)
- Doesn't crash on macOS
- Useful for testing build without GPU

## JCuda API Layers

JCuda provides bindings to multiple CUDA libraries:

| Library | Purpose | JCuda Artifact |
|---------|---------|----------------|
| **CUDA Driver** | Low-level GPU control | org.jcuda:jcuda |
| **CUDA Runtime** | Higher-level API | org.jcuda:jcuda-runtime |
| **cuBLAS** | Linear algebra | org.jcuda:jcublas |
| **cuDNN** | Deep learning primitives | org.jcuda:jcudnn |
| **cuFFT** | Fast Fourier Transform | org.jcuda:jcufft |
| **cuSPARSE** | Sparse matrices | org.jcuda:jcusparse |

This demo uses **CUDA Driver API** (lowest level, most control).

## Performance Characteristics

**JCuda overhead:**
- JNI call: ~5-10ns
- GPU kernel launch: ~5-50µs (CUDA overhead, not JCuda)
- Memory transfer: Bandwidth-limited (PCIe or unified memory)

**Compared to pure CUDA C:**
- Negligible difference for compute-heavy kernels
- JNI overhead is tiny compared to GPU execution time
- Real bottleneck is always the kernel, not Java

## When to Use JCuda

### ✅ Good Use Cases

- **CUDA-specific features** needed
- **Existing CUDA kernels** to reuse
- **Maximum performance** on NVIDIA GPUs
- **Full GPU control** required
- **cuBLAS/cuDNN** integration

### ❌ Not Recommended For

- **Cross-platform GPU** - Use TornadoVM
- **macOS** - No CUDA, use Metal alternatives
- **Simple parallelism** - TornadoVM is easier
- **No NVIDIA GPU** - Won't work

## Lessons Learned

### 1. Platform-Specific is Okay

- Not everything needs to be cross-platform
- If targeting NVIDIA GPUs, JCuda is the right choice
- Graceful fallback handles other platforms

### 2. Native Classifiers are Tricky

- Gradle dependency resolution with classifiers is subtle
- Must explicitly specify platform classifiers
- Exclude-then-include pattern works reliably

### 3. JNI Still Has Its Place

- For GPU computing, JNI overhead is negligible
- Prebuilt libraries (like JCuda) save huge development time
- FFM can't easily replace established GPU libraries yet

## References

- [JCuda Official Site](http://jcuda.org/)
- [JCuda GitHub](https://github.com/jcuda/jcuda)
- [NVIDIA CUDA Documentation](https://docs.nvidia.com/cuda/)
- [CUDA Driver API Reference](https://docs.nvidia.com/cuda/cuda-driver-api/)

## See Also

- **`demos/tornadovm/`** - Cross-platform GPU (OpenCL/CUDA/PTX)
- **`demos/tensorflow-ffm/`** - FFM for native calls
- **`demos/java-llama-cpp/`** - JNI for llama.cpp

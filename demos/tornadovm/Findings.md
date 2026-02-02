# TornadoVM Technical Findings

Analysis of TornadoVM for GPU acceleration from Java, comparing with other GPU programming approaches.

## TornadoVM Architecture

```
Java Code (@Parallel)
      ↓
Graal JIT Compiler
      ↓
TornadoVM Runtime
      ↓
Backend (OpenCL/PTX/SPIR-V)
      ↓
GPU Execution
```

**Key components:**
1. **TaskGraph** - Explicit data/task management
2. **@Parallel** - Marks parallelizable loops
3. **Graal JIT** - Compiles Java to GPU kernels
4. **Multi-backend** - OpenCL, PTX, SPIR-V support

## Performance Analysis

### VectorAdd (10M elements)

**Apple M1 Pro:**
- CPU Baseline: 15.2ms, 7.5 GB/s
- TornadoVM OpenCL: 1.3ms, 89 GB/s
- **Speedup: 12x**

**NVIDIA Tesla T4:**
- CPU Baseline: 25ms, 4.5 GB/s
- TornadoVM OpenCL: 0.8ms, 140 GB/s
- **Speedup: 30x**

### LLM Inference (Llama 3.2 1B)

**Apple M1 Pro:**
- java-llama.cpp (Metal): 50 tok/s
- Cyfra (Vulkan): 33 tok/s
- **TornadoVM (OpenCL): 6 tok/s**

**Why TornadoVM is slower for LLM:**
1. Not optimized for transformer workloads
2. Frequent CPU ↔ GPU transfers (autoregressive)
3. OpenCL overhead vs Metal/CUDA
4. JIT compilation time

**TornadoVM excels at:** Simple, large array operations
**TornadoVM struggles with:** Complex algorithms, frequent transfers

## TornadoVM vs Alternatives

### Comparison Matrix

| Feature | TornadoVM | JCuda | Babylon/HAT | Native (Metal/CUDA) |
|---------|-----------|-------|-------------|---------------------|
| **Platforms** | Multi (OpenCL) | NVIDIA only | Future | Platform-specific |
| **API Level** | High (TaskGraph) | Low (CUDA API) | High (@CodeReflection) | Lowest (C/C++) |
| **Performance** | Good (12-30x) | Excellent | Unknown | Best |
| **Ease of Use** | Medium | Hard | Easy (planned) | Very Hard |
| **Maturity** | Beta | Stable | Experimental | Production |
| **JDK Required** | JDK 21 + JVMCI | Any JDK | Custom build | N/A |

### When to Use TornadoVM

**✅ Good for:**
- Cross-platform GPU support needed
- Array/matrix operations
- Research and experimentation
- Don't want platform-specific code

**❌ Not ideal for:**
- LLM inference (use java-llama.cpp)
- NVIDIA-only (use JCuda for better performance)
- Production critical path (still beta)
- Complex control flow

## TaskGraph API Deep Dive

### Explicit Data Management

```java
TaskGraph taskGraph = new TaskGraph("id")
  .transferToDevice(FIRST_EXECUTION, a, b)  // Upload once
  .task("add", Class::method, a, b, c)       // GPU kernel
  .transferToHost(EVERY_EXECUTION, c);       // Download each time
```

**Benefits:**
- Control when data moves
- Minimize transfers (expensive)
- Can chain multiple kernels
- Clear performance model

**Comparison with CUDA:**
- CUDA: Manual cudaMemcpy calls
- TornadoVM: Declarative transfers
- Both give full control

### @Parallel Annotation

```java
public static void add(IntArray a, IntArray b, IntArray c) {
  for (@Parallel int i = 0; i < c.getSize(); i++) {
    c.set(i, a.get(i) + b.get(i));
  }
}
```

**How it works:**
1. Graal detects @Parallel loop
2. Generates GPU kernel
3. Each iteration → one GPU thread
4. Automatically handles indexing

**Limitations:**
- Loop must be parallelizable
- No dependencies between iterations
- Limited to supported operations

## Backend Comparison

### OpenCL (default)

**Pros:**
- Cross-platform (NVIDIA, AMD, Intel, Apple)
- Good compatibility
- Fallback to CPU possible

**Cons:**
- Slower than platform-specific solutions
- Driver quality varies
- Apple deprecated it (still works)

### PTX (CUDA)

**Pros:**
- Better performance on NVIDIA
- Direct CUDA path
- Full GPU utilization

**Cons:**
- NVIDIA-only
- Experimental in TornadoVM
- Requires CUDA drivers

### SPIR-V

**Pros:**
- Modern, Vulkan-based
- Future direction
- Good performance potential

**Cons:**
- Experimental
- Limited device support
- Not production-ready

## Installation Challenges

### Auto-Download Approach (this demo)

```bash
./demos/tornadovm/scripts/run-tornado.sh
# Downloads TornadoVM 2.2.0 (~100 MB)
# Extracts to build/tornadovm-sdk/
```

**Benefits:**
- Zero manual setup
- Works in CI/CD
- Version locked

### Manual Install

**Challenges:**
1. Must use JDK 21 with JVMCI
2. GraalVM CE recommended (other JDKs need JVMCI_CONFIG_CHECK=ignore)
3. OpenCL/CUDA drivers required
4. Backend selection (opencl vs ptx)

## Why Scripts are Essential

Unlike other demos, TornadoVM **cannot be fully integrated into Gradle** because:

1. **Complex runtime**: TornadoVM SDK needed at runtime
2. **Special JDK**: JVMCI required
3. **Device selection**: Environment variables needed
4. **Multiple backends**: OpenCL vs PTX vs SPIR-V
5. **Used by infrastructure**: Benchmarks, Docker, GCP scripts

**Solution:**
- Gradle: Baseline demo (CPU, educational)
- Scripts: Full functionality (GPU, production)

## Lessons Learned

### 1. Cross-Platform GPU is Hard

- No single solution fits all
- OpenCL is widest but not fastest
- Platform-specific (Metal/CUDA) wins for performance

### 2. High-Level APIs Have Limits

- TaskGraph is convenient
- But: Limited compared to raw CUDA
- Trade-off: Ease of use vs control

### 3. Different Workloads, Different Winners

- Simple arrays: TornadoVM excels (12-30x)
- LLM inference: TornadoVM struggles (6 tok/s)
- Choose tool based on workload

### 4. JVM GPU is Maturing

- Multiple approaches (TornadoVM, JCuda, Babylon)
- No clear winner yet
- Exciting future ahead

## References

- [TornadoVM GitHub](https://github.com/beehive-lab/TornadoVM)
- [TornadoVM Docs](https://tornadovm.readthedocs.io/)
- [TaskGraph API](https://tornadovm.readthedocs.io/en/latest/programming.html)
- [GPULlama3.java](https://github.com/beehive-lab/GPULlama3.java)

## See Also

- **`scripts/run-tornado.sh`** - Full GPU demo
- **`scripts/run-gpullama3.sh`** - GPU LLM inference
- **`demos/jcuda/`** - CUDA-specific approach
- **`demos/babylon/`** - Code Reflection approach
- **`demos/java-llama-cpp/`** - Best LLM performance

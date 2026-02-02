# Babylon Technical Findings

Analysis of Project Babylon's Code Reflection API and HAT (Heterogeneous Accelerated Toolkit).

## Project Babylon Overview

**Project Babylon** is an OpenJDK initiative to enable:
1. **Code Reflection** - Runtime introspection of Java code structure
2. **HAT (Heterogeneous Accelerated Toolkit)** - GPU programming from Java
3. **Code Models** - Abstract representation of code for transformation

**Status:** Early access builds available at https://jdk.java.net/babylon/

## Code Reflection API

### What It Enables

```java
// Traditional Java - no code introspection
void foo(int x) {
  int y = x * 2;
  return y;
}

// With Code Reflection - can introspect structure
CodeReflection codeModel = method.getCodeModel();
// Can analyze: variables, operations, control flow, etc.
```

**Use cases:**
- **GPU code generation** - Translate Java to GPU kernels
- **DSL compilation** - Domain-specific optimizations
- **Static analysis** - Deep code understanding
- **Custom transformations** - Rewrite code at runtime

### Current State (Feb 2026)

**Module:** `jdk.incubator.code`
**Availability:** Custom Babylon JDK builds only
**API Status:** Experimental, subject to change
**Documentation:** Limited, evolving rapidly

## HAT (Heterogeneous Accelerated Toolkit)

### Architecture

```
Java Code (with HAT annotations)
      ↓
Code Reflection API (introspect structure)
      ↓
Backend (OpenCL, CUDA, SPIR-V)
      ↓
GPU Execution
```

### Example: Matrix Multiplication

```java
@CodeReflection
static void matmul(float[] a, float[] b, float[] c, int size) {
  for (int i = 0; i < size; i++) {
    for (int j = 0; j < size; j++) {
      float sum = 0;
      for (int k = 0; k < size; k++) {
        sum += a[i * size + k] * b[k * size + j];
      }
      c[i * size + j] = sum;
    }
  }
}

// HAT translates this to GPU kernel automatically
```

**Benefits:**
- Write once in Java
- Runs on CPU or GPU
- No manual kernel writing
- Type-safe

## Why Code Reflection Matters

### Traditional Approach (JNI/CUDA)

```java
// 1. Write Java code
void matmul(...) { /* CPU code */ }

// 2. Write separate CUDA kernel
__global__ void matmul_kernel(...) { /* GPU code */ }

// 3. Bind with JNI
// 4. Maintain two codebases
```

**Problems:**
- Two implementations to maintain
- No type safety between Java and GPU code
- Complex build (nvcc, JNI, etc.)

### Babylon Approach (HAT)

```java
// Single Java implementation
@CodeReflection
void matmul(...) { /* Java code */ }

// HAT generates GPU kernel automatically
```

**Benefits:**
- Single codebase
- Type-safe
- No manual GPU programming
- Automatic optimization

## Babylon vs Alternatives

| Approach | Code Location | GPU Access | Type Safety | Maturity |
|----------|---------------|------------|-------------|----------|
| **Babylon/HAT** | Java (annotated) | Via code reflection | ✅ Full | 🔬 Experimental |
| **TornadoVM** | Java (@Parallel) | Via Truffle | ✅ Full | ⚠️ Beta (2.2.0) |
| **JCuda** | Java + CUDA | Direct CUDA API | ⚠️ Limited | ✅ Stable |
| **Aparapi** | Java (annotated) | OpenCL | ⚠️ Limited | ❌ Deprecated |

## Why This Demo is Limited

**Current limitations:**
1. **Requires custom JDK** - Not available via SDKMAN
2. **No prebuilt binaries** - Must compile from source
3. **Rapidly changing** - API not stable
4. **Limited documentation** - Experimental status

**This demo only:**
- Checks if Code Reflection module exists
- Shows JDK version information
- Doesn't demonstrate actual HAT usage (requires Babylon JDK)

**For full HAT demos:**
- See `docs/Babylon workflow.md`
- Requires cloning Babylon repository
- Must build Babylon JDK from source

## Babylon vs TornadoVM

Both enable GPU programming from Java, but different approaches:

### Babylon/HAT
- **Approach:** Code Reflection → GPU kernel generation
- **Backend:** OpenCL, CUDA, SPIR-V (pluggable)
- **Status:** Experimental (OpenJDK research project)
- **API:** `@CodeReflection` annotation
- **Control:** High (direct kernel control)

### TornadoVM
- **Approach:** Truffle JIT compilation
- **Backend:** OpenCL, PTX, SPIR-V
- **Status:** Beta (production-ready v2.2.0)
- **API:** `@Parallel`, TaskGraph
- **Control:** Medium (high-level abstractions)

**When to choose:**
- **Babylon**: Research, cutting-edge features, direct control
- **TornadoVM**: Production use, stability, ease of use

## Installation Challenges

### Building Babylon JDK

**Requirements:**
- autoconf, make, gcc
- ~30 GB disk space
- ~1-2 hours build time

**Process:**
```bash
git clone --branch code-reflection https://github.com/openjdk/babylon.git
cd babylon
bash configure
make images
```

**Why it's hard:**
- Build complexity (C++ toolchain)
- Large codebase
- No prebuilt binaries
- Moving target (frequent changes)

## Future of Babylon

**Expected timeline:**
- 2026-2027: Continued experimentation
- JDK 27-28: Possible first preview
- Beyond: Integration into mainline JDK

**Key question:** Will Code Reflection become standard?

**Possibilities:**
1. ✅ **Integrated** - Becomes part of Java SE
2. ⚠️ **Separate** - Remains optional module
3. ❌ **Abandoned** - Research doesn't pan out

## Lessons Learned

### 1. Early Access is Really Early

- Babylon is research-grade, not production
- API changes frequently
- Limited documentation
- Worth watching, not depending on yet

### 2. GPU from Java is Hard

Multiple projects trying different approaches:
- Babylon (code reflection)
- TornadoVM (Truffle)
- JCuda (direct API bindings)

No clear winner yet.

### 3. Tooling Matters

- Babylon: Hard to install, experimental
- TornadoVM: Easy to use, but limited
- JCuda: Mature, but NVIDIA-only

## References

- [Project Babylon](https://openjdk.org/projects/babylon/)
- [Babylon Early Access Builds](https://jdk.java.net/babylon/)
- [HAT MatMul Example](https://openjdk.org/projects/babylon/articles/hat-matmul/hat-matmul)
- [Code Reflection JEP Draft](https://openjdk.org/jeps/8305907)

## See Also

- **[docs/Babylon workflow.md](../../docs/Babylon%20workflow.md)** - HAT examples
- **`demos/tornadovm/`** - Alternative GPU approach
- **`demos/jcuda/`** - Direct CUDA bindings
- **`demos/valhalla/`** - Related OpenJDK research

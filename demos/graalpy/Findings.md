# GraalPy Technical Findings and Analysis

This document contains detailed technical insights, performance analysis, and architectural findings from exploring GraalPy for LLM inference and Python embedding.

## The ctypes Struct Limitation

### Root Cause Analysis

**Error:**
```
SystemError: Unsupported return type struct LLamaTokenData in ctypes callback
```

**Technical details:**
- llama-cpp-python uses Python's `ctypes` module to call llama.cpp C functions
- The llama.cpp API includes functions that return C structs by value (e.g., `llama_model_default_params()`)
- GraalPy's Truffle NFI (Native Function Interface) does **not support** returning structs by value
- CPython's ctypes implementation **does support** this

**Truffle NFI Supported Types:**
- `VOID`, `SINT*`, `UINT*`, `FLOAT`, `DOUBLE`, `POINTER`, `STRING`, `OBJECT`, `ENV`
- **Missing**: Struct types, union types, complex C type compositions

**Why this is fundamental:**
- Not a bug - architectural choice in GraalPy's design
- Truffle NFI prioritizes safety and cross-platform compatibility
- Supporting arbitrary C struct layouts requires deep platform-specific knowledge
- CPython uses libffi which handles this complexity at the cost of portability

**Impact:**
- ✅ Pure Python code: works perfectly
- ✅ Simple C extensions: work (NumPy, pandas, etc.)
- ✅ C extensions using pointers/primitives: work
- ❌ **C extensions with struct returns/callbacks: fail**

### Affected Libraries

Libraries known to fail on GraalPy due to ctypes struct issues:
- **llama-cpp-python** - LLM inference (this demo)
- **pygame** - Game development (uses SDL structs)
- **Some audio libraries** - Complex audio buffer structs

Libraries that work:
- **NumPy** - Uses different binding mechanism
- **Pandas** - Built on NumPy
- **Requests** - Pure Python + simple C extensions
- **Most data science libs** - GraalPy has good compatibility

## Performance Analysis

### Context Creation Overhead

**GraalPy:**
```
Context creation: 500-800ms
First eval: ~100ms
Subsequent evals: <10ms
```

**CPython:**
```
Import time: ~50ms
First call: ~10ms
Subsequent calls: <1ms
```

**Analysis:**
- GraalPy has **10-16x higher startup cost**
- Truffle needs to initialize the interpreter, JIT compiler, runtime
- Cost is amortized over long-running applications
- For one-off scripts: prohibitive overhead

### LLM Inference Performance (Llama 3.2 1B, 32 tokens)

| Approach | Speed | Technology | Notes |
|----------|-------|------------|-------|
| **java-llama.cpp** | ~50 tok/s | JNI + Metal GPU | Best |
| **Cyfra** | ~33 tok/s | Scala + Vulkan GPU | Pure JVM |
| **Llama3.java (JDK 25)** | ~13 tok/s | Pure Java Vector API | CPU |
| **CPython (this demo)** | ~10 tok/s | llama-cpp-python CPU | Standard |
| **TornadoVM** | ~6 tok/s | OpenCL GPU | Experimental |
| **GraalPy** | ❌ N/A | - | ctypes fails |

**Key insight:** For Python-based LLM inference, standard CPython works better than GraalPy due to full ctypes compatibility.

### Memory Comparison

**GraalPy Context:**
- Baseline: ~200-300 MB
- After warmup: ~400 MB
- Reason: Truffle runtime, JIT compiler, deoptimization metadata

**CPython Process:**
- Baseline: ~20-30 MB
- With llama-cpp-python: ~50 MB (model loaded separately)
- Reason: Minimal runtime, no JIT overhead

**When GraalPy wins:**
- Long-running applications (startup cost amortized)
- After JIT warmup (peak performance exceeds CPython)
- Multi-language applications (no separate processes needed)

## Maven Dependencies Deep Dive

### How GraalPy is Distributed

**Modern approach (GraalVM 23+):**
```kotlin
dependencies {
  compileOnly("org.graalvm.sdk:graal-sdk:25.0.1")
  runtimeOnly("org.graalvm.polyglot:python:25.0.1")
}
```

**What this includes:**
- Full GraalPy interpreter (~100 MB)
- Python 3.12.8 standard library
- Truffle runtime and NFI
- All necessary native libraries

**Why exclude Truffle modules:**
```kotlin
runtimeOnly("org.graalvm.polyglot:python:25.0.1") {
  exclude(group = "org.graalvm.truffle", module = "truffle-runtime")
  exclude(group = "org.graalvm.truffle", module = "truffle-compiler")
}
```

**Reason:** These modules are already in the JDK (GraalVM or standard with JVMCI). Including them twice causes classloader conflicts.

**Benefits of Maven approach:**
1. **Works with any JDK 21+** - not just GraalVM
2. **No `gu install` needed** - pure Gradle dependency
3. **Reproducible builds** - locked versions
4. **CI/CD friendly** - no manual setup
5. **Polyglot mixing** - add JavaScript, Ruby, R via same approach

### Legacy vs Modern

**Legacy (GraalVM 22 and earlier):**
```bash
sdk install java 21.0.2-graalce
gu install graalpy
graalpy --version
```

**Modern (GraalVM 23+):**
```kotlin
// Just add Maven dependency
runtimeOnly("org.graalvm.polyglot:python:25.0.1")
```

The modern approach is **strongly recommended** for new projects.

## GraalPy vs Other JVM Python Solutions

### Comparison Matrix

| Feature | GraalPy | Jython | JPype | ProcessBuilder |
|---------|---------|--------|-------|----------------|
| **Python Version** | 3.12+ | 2.7 only | 3.x (any) | 3.x (any) |
| **Startup Time** | Slow (~600ms) | Medium (~200ms) | Fast (~50ms) | Fast (~100ms) |
| **Peak Performance** | Excellent | Poor | Good | Good |
| **Java Interop** | Seamless | Seamless | Good | None |
| **C Extensions** | Limited | None | Full (CPython) | Full (CPython) |
| **Memory** | High (~300MB) | Medium (~100MB) | Medium (~50MB) | Low (~20MB) |
| **Maintenance** | Active (Oracle) | Dead (2022) | Active | Built-in |

### When to Choose Each

**GraalPy (this demo):**
- ✅ Long-running polyglot applications
- ✅ Need seamless Java ↔ Python value sharing
- ✅ Sandboxed Python execution
- ✅ Pure Python code (no complex C deps)

**JPype:**
- ✅ Full CPython compatibility needed
- ✅ Complex C extensions required
- ✅ Lower memory footprint important
- ✅ Calling Java from existing Python code

**ProcessBuilder (subprocess):**
- ✅ Complete isolation needed
- ✅ Existing Python scripts unchanged
- ✅ Minimal memory overhead
- ❌ No Java ↔ Python interop

**Jython:**
- ❌ **Don't use** - Python 2.7 only, unmaintained

## Architectural Insights

### Why GraalPy Has Better Peak Performance

**Graal JIT Optimizations:**
1. **Inlining across languages** - Python → Java calls optimized away
2. **Escape analysis** - Stack allocate Python objects
3. **Partial evaluation** - Truffle AST optimization
4. **Speculation** - Type feedback and deoptimization

**After warmup (100+ iterations):**
- GraalPy can be **2-5x faster** than CPython for pure Python
- Especially for numeric code, loops, object allocation

**But:**
- Warmup takes 10-20 iterations
- Memory usage is 10x higher
- Startup is 10x slower

**Verdict:** Great for long-running services, poor for scripts.

### The Polyglot API Design

**Why it's powerful:**
```java
Context ctx = Context.newBuilder("python")
  .allowIO(IOAccess.ALL)           // Explicit permissions
  .allowNativeAccess(true)         // Explicit C extension access
  .option("python.PythonPath", path) // Configuration
  .build();

Value result = ctx.eval("python", "2 + 2");
double value = result.asDouble(); // Type-safe conversion
```

**Key design principles:**
1. **Security by default** - all access must be explicitly allowed
2. **Type safety** - `Value` wrapper with safe conversions
3. **Resource management** - try-with-resources pattern
4. **Language agnostic** - same API for Python, JavaScript, Ruby, R

**Comparison with JNI:**
- JNI: Unsafe, error-prone, platform-specific
- Polyglot API: Safe, simple, cross-platform

## The CPython Baseline

### Why CPython Works Perfectly

Running the same `llama_inference.py` with standard Python:

```bash
python3 llama_inference.py --prompt "hello" --max-tokens 32
# ✅ Works: ~10 tokens/sec
```

**Why it works:**
- Full ctypes implementation (via libffi)
- Native callback support
- Struct return handling
- 100% llama-cpp-python compatibility

**Performance on Apple M1 Pro (CPU only):**
- Model load: ~23 seconds
- Inference: ~10 tokens/sec
- Memory: ~2.8 GB (model in RAM)

**With GPU (not tested in this demo):**
- llama-cpp-python can use Metal GPU
- Expected: ~40-50 tokens/sec
- Requires: `CMAKE_ARGS="-DGGML_METAL=on" pip install llama-cpp-python`

## Lessons Learned

### 1. Know Your C Extension Requirements

Before choosing GraalPy, check if your Python dependencies use:
- Complex ctypes callbacks? → Use CPython
- Struct returns from native code? → Use CPython
- Pure Python or simple C extensions? → GraalPy works

### 2. Startup Cost Matters

GraalPy's 600ms startup makes it unsuitable for:
- CLI tools
- Lambda functions
- Kubernetes Jobs (if pod lifetime is short)
- One-off scripts

Good for:
- Long-running services
- Embedded scripting engines
- Applications where polyglot is the main value

### 3. For LLM Inference in Java

**Ranking** (best to worst):
1. **java-llama.cpp** - JNI bindings, Metal/CUDA GPU (~50 tok/s)
2. **Cyfra** - Scala/Vulkan GPU (~33 tok/s)
3. **Llama3.java** - Pure Java, Vector API (~13 tok/s)
4. **CPython subprocess** - Standard Python (~10 tok/s)
5. **TornadoVM** - OpenCL GPU (~6 tok/s)
6. **GraalPy** - ❌ Doesn't work (ctypes limitation)

**Don't use Python embedding for LLM inference** - use native Java solutions.

### 4. The Modern GraalVM Philosophy

GraalVM is moving toward:
- ✅ Maven/Gradle dependencies (not `gu install`)
- ✅ Works with any JDK (not just GraalVM distributions)
- ✅ Polyglot as a library (not a runtime feature)

This demo shows the modern approach.

## References

- [GraalPy Official Docs](https://www.graalvm.org/python/)
- [Truffle NFI Documentation](https://www.graalvm.org/latest/graalvm-as-a-platform/language-implementation-framework/NFI/)
- [Polyglot API Javadoc](https://www.graalvm.org/sdk/javadoc/org/graalvm/polyglot/package-summary.html)
- [GraalPy Compatibility Matrix](https://www.graalvm.org/python/compatibility/)
- [GraalPy GitHub Issues](https://github.com/oracle/graalpython/issues)

## Conclusion

**GraalPy is excellent for:**
- Polyglot applications needing Java ↔ Python interop
- Embedding Python as a scripting language
- Pure Python workloads in long-running JVM apps

**GraalPy is NOT suitable for:**
- LLM inference (use java-llama.cpp or Llama3.java)
- Libraries with complex C callbacks (use CPython)
- Short-lived processes (startup cost too high)

The ability to run the same `llama_inference.py` with both CPython (works) and GraalPy (fails) in this demo clearly illustrates the ctypes limitation and helps developers make informed choices.

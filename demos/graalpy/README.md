# GraalPy Demo - Embedding Python in Java

This demo shows how to embed **GraalPy** (Python on GraalVM) into a Java application using the **GraalVM Polyglot API**.

## What This Demo Shows

Two Java programs demonstrate different aspects of GraalPy integration:

1. **`GraalPyFromJava`** - Basic GraalPy embedding
   - Creates a Python context from Java
   - Evaluates Python expressions
   - Accesses Python values from Java
   - ✅ **Works perfectly**

2. **`GraalPyLlama`** - Python LLM inference attempt
   - Attempts to run `llama-cpp-python` from Java
   - Shows how to configure native access and venv paths
   - ❌ **Fails due to GraalPy ctypes limitations** (see Known Issues)

## Requirements

**Option 1: GraalVM with GraalPy (legacy approach)**
```bash
# Install GraalVM CE 21
sdk install java 21.0.2-graalce
sdk use java 21.0.2-graalce

# Install GraalPy component
gu install graalpy

# Verify
graalpy --version
```

**Option 2: Any JDK + GraalPy Maven Dependency (modern approach - used by this demo)**
```bash
# Any JDK 21+ works (Temurin, GraalVM, etc.)
sdk install java 21.0.5-tem

# GraalPy runtime is automatically downloaded as a Gradle dependency
./gradlew :demos:graalpy:dependencies --configuration runtimeClasspath
```

This demo uses **Option 2** - the Maven dependencies approach, which means:
- ✅ Works with **any JDK 21+** (not just GraalVM)
- ✅ No `gu install` needed
- ✅ GraalPy runtime downloaded automatically via Gradle

## How It Works

### Dependencies

The magic happens in `build.gradle.kts`:

```kotlin
dependencies {
  // GraalVM SDK for compile-time API
  compileOnly("org.graalvm.sdk:graal-sdk:25.0.1")

  // GraalPy runtime - brings the full Python interpreter
  runtimeOnly("org.graalvm.polyglot:python:25.0.1") {
    exclude(group = "org.graalvm.truffle", module = "truffle-runtime")
    exclude(group = "org.graalvm.truffle", module = "truffle-compiler")
  }
}
```

**Why this works:**
- `graal-sdk` provides the Polyglot API (`Context`, `Value`, etc.)
- `python:25.0.1` provides the full GraalPy interpreter as a Maven artifact
- Excludes Truffle runtime/compiler to avoid conflicts (they're in the JDK)

### GraalPyFromJava - Basic Example

```java
try (Context ctx = Context.newBuilder("python").build()) {
  // Evaluate Python code
  Value result = ctx.eval("python", "1.5 + 2.25");
  System.out.println("Result: " + result.asDouble()); // 3.75

  // Access Python version
  Value version = ctx.eval("python", "import sys; sys.version");
  System.out.println(version.asString());
}
```

**Key insights:**
- Context creation takes ~500-800ms (GraalPy initialization)
- Subsequent evals are fast
- Seamless Java ↔ Python value conversion
- Automatic resource cleanup with try-with-resources

### GraalPyLlama - Advanced (but failing) Example

Demonstrates advanced Polyglot API features:

```java
Context ctx = Context.newBuilder("python")
  .allowIO(IOAccess.ALL)          // Allow file system access
  .allowNativeAccess(true)        // Allow C extensions
  .option("python.PythonPath", venvPath) // Add virtualenv to path
  .build();
```

**What it tries to do:**
1. Configure Python path to use `graalpy-llama/.venv`
2. Import `llama_inference.py` module
3. Call `run_inference()` to run LLM inference via `llama-cpp-python`

**Why it fails:** See Known Issues below.

## Running the Demos

### Basic Demo (works)

```bash
# From project root
./gradlew :demos:graalpy:run

# Or with SDKMAN environment
cd demos/graalpy
sdk env install && sdk env
../../gradlew :demos:graalpy:run
```

**Expected output:**
```
[GraalPy] GraalPy Java Host Demo
[GraalPy] Context created in 650ms
[GraalPy] python.version=3.12.8 (GraalVM CE)
[GraalPy] Result: 1.5 + 2.25 = 3.75
[GraalPy] Demo completed successfully
```

### LLM Inference Demo (fails)

```bash
./gradlew :demos:graalpy:runLlama
```

**Expected output:**
```
[GraalPy] Polyglot Exception: SystemError:
  Unsupported return type struct LLamaTokenData in ctypes callback
```

See **Known Issues** for why this fails.

## Known Issues

### ❌ GraalPy Cannot Run llama-cpp-python

**Problem:** GraalPy's Truffle NFI (Native Function Interface) **does not support struct return types** in ctypes callbacks.

**Error:**
```
SystemError: Unsupported return type struct LLamaTokenData in ctypes callback
```

**Root cause:**
- `llama-cpp-python` uses ctypes to call llama.cpp C library
- llama.cpp uses callbacks that return C structs
- GraalPy's ctypes implementation doesn't support this (CPython does)

**Workaround:** None. This is a fundamental limitation of GraalPy's ctypes.

**Alternative:** Use `java-llama.cpp` (JNI bindings) instead - see `demos/java-llama-cpp/`

### Why This Matters

This demonstrates an important limitation when choosing GraalPy:
- ✅ Pure Python code works great
- ✅ Most C extensions work (NumPy, etc.)
- ❌ **C extensions with complex ctypes callbacks may fail**

If you need `llama-cpp-python`, use CPython or PyPy, not GraalPy.

## Performance Insights

**Context Creation:** ~500-800ms
- GraalPy needs to initialize the Truffle interpreter
- This is a one-time cost per application
- Much slower than CPython (~50ms)

**Execution Speed:**
- Pure Python: comparable to CPython
- With Graal JIT warmup: can be faster than CPython
- Peak performance after ~10-20 iterations

**Memory:**
- Higher baseline memory than CPython (~200MB vs ~20MB)
- Better for long-running applications with JIT optimization

## When to Use GraalPy

### ✅ Good Use Cases
- **Polyglot applications** - seamless Java ↔ Python interop
- **Embedding Python in Java apps** - configuration, scripting, plugins
- **Sandboxed Python execution** - security boundaries
- **Pure Python algorithms** - benefit from Graal JIT

### ❌ Not Recommended For
- **Quick scripts** - startup time too high
- **Complex C extensions** - ctypes limitations
- **Existing Python codebases** - compatibility issues
- **LLM inference** - use java-llama.cpp instead

## Technical Details

**Package:** `com.skowronski.talk.jvmai`

**Classes:**
- `GraalPyFromJava` - Basic Polyglot API demo
- `GraalPyLlama` - Advanced (failing) LLM inference attempt

**Dependencies:**
- GraalVM SDK 25.0.1 (compile-time)
- GraalPy Polyglot 25.0.1 (runtime)
- Works with any JDK 21+ (not just GraalVM)

## Comparison with Alternatives

| Approach | Startup | Performance | Compatibility | Complexity |
|----------|---------|-------------|---------------|------------|
| **CPython** | Fast (~50ms) | Baseline | Excellent | Simple |
| **GraalPy (this demo)** | Slow (~600ms) | Good (JIT) | Limited | Medium |
| **Jython** | Medium | Slow | Python 2.7 only | Simple |
| **JPype** | Fast | Good | Excellent | Medium |

**Verdict:** For LLM inference in Java, use native bindings (java-llama.cpp) rather than Python embedding.

## Further Reading

- [GraalPy Documentation](https://www.graalvm.org/python/)
- [Polyglot API Guide](https://www.graalvm.org/sdk/javadoc/org/graalvm/polyglot/package-summary.html)
- [GraalPy Compatibility](https://www.graalvm.org/python/compatibility/)
- [Why GraalPy Llama Fails](../graalpy-llama/README.md)

## See Also

- **`demos/graalpy-llama/`** - Standalone GraalPy LLM attempt (also fails)
- **`demos/java-llama-cpp/`** - JNI bindings for llama.cpp (✅ works perfectly)
- **`demos/llama3-java/`** - Pure Java LLM implementation (no Python needed)

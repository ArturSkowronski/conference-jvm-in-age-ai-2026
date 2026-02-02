# GraalPy Demo - Python on the JVM

This demo explores **three different approaches** to running Python code on/with the JVM, demonstrating both successes and fundamental limitations.

## What This Demo Contains

Three runnable programs showing different Python integration strategies:

### 1. GraalPy Basic Embedding (✅ Works)
**`GraalPyFromJava.java`** - Java embedding GraalPy via Polyglot API
- Creates a Python context from Java
- Evaluates Python expressions
- Seamless Java ↔ Python value conversion
- **Status**: ✅ Works perfectly

### 2. CPython with llama-cpp-python (✅ Works)
**`llama_inference.py`** - Standard Python LLM inference
- Uses standard CPython (not GraalPy)
- Runs llama-cpp-python for LLM inference
- Shows what works with full ctypes support
- **Status**: ✅ Works perfectly (~10 tokens/sec)

### 3. GraalPy LLM Attempt (❌ Fails - Educational)
**`GraalPyLlama.java`** - Java → GraalPy → llama-cpp-python
- Attempts to run llama-cpp-python from Java via GraalPy
- Demonstrates GraalPy's ctypes struct limitation
- Shows advanced Polyglot API configuration
- **Status**: ❌ Fails (demonstrates fundamental limitation)

## Quick Start

### Option 1: Basic GraalPy Embedding (recommended)

```bash
# From project root
./gradlew :demos:graalpy:run

# Or with SDKMAN
cd demos/graalpy
sdk env install && sdk env
../../gradlew :demos:graalpy:run
```

**Expected output:**
```
[GraalPy] GraalPy Java Host Demo
[GraalPy] Context created in 650ms
[GraalPy] python.version=3.12.8
[GraalPy] Result: 1.5 + 2.25 = 3.75
✅ Demo completed successfully
```

### Option 2: CPython LLM Inference

```bash
# Setup venv (first time only)
cd demos/graalpy
python3 -m venv .venv
source .venv/bin/activate
pip install llama-cpp-python

# Run with Gradle
./gradlew :demos:graalpy:runCPython

# Or run Python directly
python3 llama_inference.py --prompt "tell me a joke" --max-tokens 32
```

**Expected output:**
```
Model loaded in 23.2s
Generating response...
A programmer's wife asks: "Could you go to the store and get a gallon of milk?"
He never returned.
✅ Generated 23 tokens in 2.3s (~10 tokens/sec)
```

### Option 3: GraalPy LLM (demonstrates failure)

```bash
# Setup CPython venv first (see Option 2)

# Run the failing GraalPy demo
./gradlew :demos:graalpy:runLlama
```

**Expected output:**
```
[GraalPy] Polyglot Exception: SystemError:
  Unsupported return type struct LLamaTokenData in ctypes callback
❌ This intentionally fails to demonstrate GraalPy limitations
```

## Requirements

**For Basic Demo (GraalPyFromJava):**
- Any JDK 21+ (Temurin, GraalVM, etc.)
- GraalPy runtime (auto-downloaded via Gradle dependency)

**For CPython Demo:**
- Python 3.10+ (standard CPython)
- llama-cpp-python (`pip install llama-cpp-python`)
- Model file: `~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf`

**For GraalPy LLM Demo:**
- Same as CPython demo (to show it fails with GraalPy)

## How It Works

### Modern Dependency Approach

This demo uses **Maven dependencies** instead of `gu install graalpy`:

```kotlin
dependencies {
  // GraalVM SDK for compile-time API
  compileOnly("org.graalvm.sdk:graal-sdk:25.0.1")

  // GraalPy runtime - full Python interpreter as a Maven artifact
  runtimeOnly("org.graalvm.polyglot:python:25.0.1")
}
```

**Benefits:**
- ✅ Works with **any JDK 21+** (not just GraalVM)
- ✅ No `gu install` needed
- ✅ Reproducible builds (version locked)
- ✅ Works in CI/CD without special setup

### GraalPy Basic Embedding

```java
try (Context ctx = Context.newBuilder("python").build()) {
  Value result = ctx.eval("python", "1.5 + 2.25");
  System.out.println(result.asDouble()); // 3.75
}
```

**Performance:**
- Context creation: ~500-800ms (one-time cost)
- Expression evaluation: <10ms
- Total demo runtime: ~800ms

### CPython vs GraalPy for LLM Inference

**Same Python code (`llama_inference.py`), different interpreters:**

| Interpreter | Command | Result |
|-------------|---------|--------|
| **CPython** | `./gradlew :demos:graalpy:runCPython` | ✅ Works (~10 tok/s) |
| **GraalPy** | `./gradlew :demos:graalpy:runLlama` | ❌ Fails (ctypes limitation) |

## The ctypes Struct Limitation

### Why GraalPy Fails

**Error:**
```
SystemError: Unsupported return type struct LLamaTokenData in ctypes callback
```

**Root cause:**
- llama-cpp-python uses ctypes to call llama.cpp C functions
- Some functions return C structs by value
- GraalPy's Truffle NFI **does not support struct return types**
- CPython's ctypes **does support** this

**What this means:**
- ✅ Pure Python code works on GraalPy
- ✅ Most C extensions work (NumPy, etc.)
- ❌ **C extensions with struct callbacks fail**

This is not a bug - it's an architectural limitation of GraalPy's native interface.

## Performance Comparison

**Context Creation:**
- GraalPy: ~600ms (Truffle initialization)
- CPython: ~50ms

**LLM Inference (Llama 3.2 1B, 32 tokens):**
- CPython (this demo): ~10 tokens/sec (CPU)
- java-llama.cpp: ~50 tokens/sec (Metal GPU)
- Llama3.java (JDK 25): ~13 tokens/sec (Vector API CPU)

## When to Use Each Approach

### ✅ Use GraalPy (GraalPyFromJava) For:
- **Polyglot applications** - seamless Java ↔ Python interop
- **Embedding Python** - configuration, scripting, plugins
- **Sandboxed execution** - security boundaries
- **Pure Python algorithms** - benefit from Graal JIT
- **Long-running apps** - amortize startup cost

### ✅ Use CPython (runCPython) For:
- **Standard Python libraries** - full compatibility
- **Quick scripts** - fast startup
- **Complex C extensions** - full ctypes support
- **LLM inference** - llama-cpp-python works

### ❌ Don't Use GraalPy For:
- **Complex C extensions** - ctypes struct limitation
- **Quick one-off scripts** - startup too slow
- **LLM inference** - use java-llama.cpp instead

## All Available Tasks

```bash
# Basic GraalPy embedding (works)
./gradlew :demos:graalpy:run

# CPython LLM inference (works)
./gradlew :demos:graalpy:runCPython

# GraalPy LLM attempt (fails - educational)
./gradlew :demos:graalpy:runLlama

# List all tasks
./gradlew :demos:graalpy:tasks
```

## Code Structure

```
demos/graalpy/
├── src/main/java/com/skowronski/talk/jvmai/
│   ├── GraalPyFromJava.java   # Basic embedding (works)
│   └── GraalPyLlama.java      # LLM attempt (fails)
├── llama_inference.py         # Python LLM script
├── scripts/
│   └── run-llama.sh           # Venv setup wrapper
├── build.gradle.kts           # 3 tasks: run, runCPython, runLlama
├── .sdkmanrc                  # GraalVM CE 25
└── README.md                  # This file
```

## Technical Insights

### Why Maven Dependencies Work

GraalPy 25+ is distributed as a Maven artifact:
- `org.graalvm.polyglot:python:25.0.1` - Full Python interpreter
- `org.graalvm.sdk:graal-sdk:25.0.1` - Polyglot API

This means:
1. No need for GraalVM-specific JDK
2. Works with Temurin, Corretto, Zulu, etc.
3. Reproducible builds
4. Easy CI/CD integration

### GraalPy vs Jython

| Feature | GraalPy | Jython |
|---------|---------|--------|
| Python Version | 3.12+ | 2.7 only |
| C Extensions | Limited (no struct returns) | None |
| JIT Performance | Excellent (Graal) | Poor |
| Startup Time | Slow (~600ms) | Medium (~200ms) |
| Java Interop | Excellent | Good |
| Maintenance | Active | Unmaintained |

## Troubleshooting

### "No language and polyglot implementation was found"

**Cause:** Running with wrong JDK or missing GraalPy runtime dependency.

**Fix:** Make sure GraalPy is in classpath:
```bash
./gradlew :demos:graalpy:dependencies --configuration runtimeClasspath | grep python
```

Should show: `org.graalvm.polyglot:python:25.0.1`

### "SystemError: returning struct by value is not supported"

**Cause:** This is expected for `runLlama` - it demonstrates GraalPy's limitation.

**Fix:** Use `runCPython` instead:
```bash
./gradlew :demos:graalpy:runCPython
```

## See Also

- **`demos/java-llama-cpp/`** - JNI bindings for llama.cpp (✅ fastest, ~50 tok/s with GPU)
- **`demos/llama3-java/`** - Pure Java LLM (✅ no dependencies, ~13 tok/s)
- **`demos/tornadovm/`** - TornadoVM GPU acceleration (✅ ~6 tok/s)

## Further Reading

- [GraalPy Documentation](https://www.graalvm.org/python/)
- [Polyglot API Guide](https://www.graalvm.org/sdk/javadoc/org/graalvm/polyglot/package-summary.html)
- [GraalPy Compatibility](https://www.graalvm.org/python/compatibility/)
- [Truffle NFI Limitations](https://www.graalvm.org/latest/graalvm-as-a-platform/language-implementation-framework/NFI/)

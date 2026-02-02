# GraalPy Demo - Python on the JVM

Three approaches to running Python on/with the JVM, demonstrating both capabilities and limitations.

## Three Demos in One

| Demo | Technology | Status | Command |
|------|------------|--------|---------|
| **Basic Embedding** | Java → GraalPy | ✅ Works | `./gradlew :demos:graalpy:run` |
| **CPython LLM** | Standard Python | ✅ Works (~10 tok/s) | `./gradlew :demos:graalpy:runCPython` |
| **GraalPy LLM** | Java → GraalPy → llama.cpp | ❌ Fails (educational) | `./gradlew :demos:graalpy:runLlama` |

## Quick Start

### 1. Basic GraalPy Embedding (✅ Works)

```bash
./gradlew :demos:graalpy:run
```

**What it does:**
- Creates a Python context from Java (Polyglot API)
- Evaluates Python expressions: `1.5 + 2.25`
- Shows Python version and seamless value conversion

**Expected output:**
```
[GraalPy] Context created in 650ms
[GraalPy] python.version=3.12.8
[GraalPy] Result: 1.5 + 2.25 = 3.75
✅ Demo completed successfully
```

### 2. CPython LLM Inference (✅ Works)

**Setup (first time only):**
```bash
cd demos/graalpy
python3 -m venv .venv
source .venv/bin/activate
pip install llama-cpp-python
```

**Run:**
```bash
# With Gradle
./gradlew :demos:graalpy:runCPython

# Or directly
python3 llama_inference.py --prompt "tell me a joke" --max-tokens 32
```

**Expected output:**
```
Model loaded in 23.2s
A programmer's wife asks: "Could you go to the store and get a gallon of milk?"
He never returned.
✅ ~10 tokens/sec
```

### 3. GraalPy LLM Attempt (❌ Fails - Educational)

```bash
./gradlew :demos:graalpy:runLlama
```

**Expected output:**
```
[GraalPy] Polyglot Exception: SystemError:
  Unsupported return type struct LLamaTokenData in ctypes callback
❌ Demonstrates GraalPy's ctypes struct limitation
```

## Requirements

**Basic Demo:**
- Any JDK 21+
- GraalPy (auto-downloaded via Gradle)

**CPython Demo:**
- Python 3.10+
- llama-cpp-python
- Model: `~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf` (download: `../../scripts/download-models.sh --fp16`)

**GraalPy LLM Demo:**
- Same as CPython (shows it fails with GraalPy)

## Results Summary

| Approach | Startup | Performance | Compatibility | Result |
|----------|---------|-------------|---------------|--------|
| **GraalPy Basic** | 600ms | Excellent (JIT) | Pure Python only | ✅ Works |
| **CPython LLM** | 50ms | ~10 tok/s | Full ctypes | ✅ Works |
| **GraalPy LLM** | 600ms | N/A | Limited ctypes | ❌ Fails |

## Key Findings

✅ **GraalPy is excellent for:**
- Embedding Python in Java applications
- Polyglot interop (seamless Java ↔ Python)
- Pure Python code with JIT optimization
- Sandboxed execution

❌ **GraalPy is NOT suitable for:**
- LLM inference (ctypes struct limitation)
- Complex C extensions with callbacks
- Quick one-off scripts (startup too slow)

**Recommendation:** For LLM inference in Java, use **`demos/java-llama-cpp/`** (JNI bindings, ~50 tok/s) or **`demos/llama3-java/`** (pure Java, ~13 tok/s).

## Code Structure

```
demos/graalpy/
├── src/main/java/com/skowronski/talk/jvmai/
│   ├── GraalPyFromJava.java      # Basic demo (works)
│   └── GraalPyLlama.java         # LLM attempt (fails)
├── llama_inference.py            # Python LLM script
├── scripts/run-llama.sh          # Venv wrapper
├── build.gradle.kts              # 3 Gradle tasks
├── .sdkmanrc                     # GraalVM CE 25
├── README.md                     # This file (usage)
└── Findings.md                   # Technical analysis
```

## Deep Dive

For detailed technical analysis, performance benchmarks, and architectural insights, see **[Findings.md](Findings.md)**.

Topics covered:
- ctypes struct limitation (root cause)
- Performance analysis (startup, peak, memory)
- Maven dependencies deep dive
- GraalPy vs Jython vs JPype comparison
- Polyglot API design principles
- When to use each approach
- Lessons learned

## See Also

- **[Findings.md](Findings.md)** - Technical deep dive and analysis
- **`demos/java-llama-cpp/`** - JNI bindings (✅ fastest, ~50 tok/s)
- **`demos/llama3-java/`** - Pure Java LLM (✅ ~13 tok/s)
- **`demos/tornadovm/`** - GPU acceleration (✅ ~6 tok/s)

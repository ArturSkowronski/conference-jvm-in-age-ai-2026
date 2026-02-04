# GraalPy Demo - Python on the JVM

Three approaches to running Python on/with the JVM, demonstrating both capabilities and limitations.

## Three Demos in One

| Demo | Technology | Status | Command |
|------|------------|--------|---------|
| **Smoke Test** | Java → GraalPy | ✅ Works | `./gradlew :demos:graalpy:runtimeCheck` |
| **CPython LLM** | Standard Python | ✅ Works (~10 tok/s) | `./gradlew :demos:graalpy:llamaPython` |
| **GraalPy LLM** | Java → GraalPy → llama.cpp | ❌ Fails (educational) | `./gradlew :demos:graalpy:llama` |

**Run all three demos in sequence:**
```bash
./gradlew :demos:graalpy:run
```

## Quick Start

### Run All Demos (Recommended)

```bash
# Master task - runs all three demos: runtimeCheck → llamaPython → llama
./gradlew :demos:graalpy:run
```

**What happens:**
1. ✅ **runtimeCheck** - GraalPy basic embedding (works)
2. ✅ **llamaPython** - Python LLM via CPython (works, ~10 tok/s)
3. ❌ **llama** - Python LLM via GraalPy (fails with ctypes error)

### Individual Demos

#### 1. Smoke Test - Basic GraalPy Embedding

```bash
./gradlew :demos:graalpy:runtimeCheck
```

**What it does:**
- Creates a Python context from Java (Polyglot API)
- Evaluates Python expressions: `1.5 + 2.25`
- Shows Python version and value conversion

**Expected output:**
```
[GraalPy] Context created in 650ms
[GraalPy] python.version=3.12.8
[GraalPy] Result: 1.5 + 2.25 = 3.75
✅ Demo completed successfully
```

#### 2. CPython LLM Inference

**Setup (first time only):**
```bash
cd demos/graalpy
python3 -m venv .venv
source .venv/bin/activate
pip install llama-cpp-python

# Download model if needed
cd ../..
./scripts/download-models.sh --fp16
```

**Run:**
```bash
# With Gradle
./gradlew :demos:graalpy:llamaPython

# Or run Python directly
cd demos/graalpy
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

#### 3. GraalPy LLM Attempt

**Prerequisites:** CPython venv setup (see above)

```bash
./gradlew :demos:graalpy:llama
```

**Expected output:**
```
[GraalPy] Polyglot Exception: SystemError:
  Unsupported return type struct LLamaTokenData in ctypes callback
❌ This intentionally fails to demonstrate GraalPy's ctypes limitation
```

## Requirements

**Smoke Test:**
- Any JDK 21+ (Temurin, GraalVM, etc.)
- GraalPy runtime (auto-downloaded via Gradle)

**CPython LLM:**
- Python 3.10+ (standard CPython)
- llama-cpp-python (`pip install llama-cpp-python`)
- Model file: `~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf` (~2.5 GB)

**GraalPy LLM:**
- Same as CPython (to demonstrate the failure)

## Results Summary

| Demo | Startup | Performance | Compatibility | Result |
|------|---------|-------------|---------------|--------|
| **runtimeCheck** | ~600ms | Fast (basic ops) | Pure Python | ✅ Works |
| **llamaPython** | ~50ms | ~10 tok/s | Full ctypes | ✅ Works |
| **llama** | ~600ms | N/A | Limited ctypes | ❌ Fails |

## Key Findings

✅ **GraalPy is excellent for:**
- Embedding Python in Java applications
- Polyglot interop (seamless Java ↔ Python)
- Pure Python code with JIT optimization
- Sandboxed execution

❌ **GraalPy is NOT suitable for:**
- LLM inference (ctypes struct limitation)
- Complex C extensions with struct callbacks
- Quick one-off scripts (startup cost too high)

**Conclusion:** The same `llama_inference.py` works with CPython but fails with GraalPy, clearly demonstrating the ctypes limitation.

**Recommendation:** For LLM inference in Java, use:
- **`demos/java-llama-cpp/`** - JNI bindings (~50 tok/s with Metal GPU)
- **`demos/llama3-java/`** - Pure Java (~13 tok/s with Vector API)

## Code Structure

```
demos/graalpy/
├── src/main/java/com/skowronski/talk/jvmai/
│   ├── GraalPyFromJava.java      # Smoke test (works)
│   └── GraalPyLlama.java         # LLM attempt (fails)
├── llama_inference.py            # Python LLM script
├── scripts/run-llama.sh          # Venv wrapper
├── build.gradle.kts              # 5 tasks including runAll
├── .sdkmanrc                     # GraalVM CE 25
├── README.md                     # This file (quick reference)
└── Findings.md                   # Technical deep dive
```

## Deep Dive

For comprehensive technical analysis, see **[Findings.md](Findings.md)**:
- ctypes struct limitation (root cause)
- Performance analysis (startup, peak, memory)
- Maven dependencies explained
- GraalPy vs alternatives comparison
- Architectural insights
- When to use each approach
- Lessons learned

## See Also

- **[Findings.md](Findings.md)** - Technical analysis
- **`demos/java-llama-cpp/`** - JNI bindings (✅ ~50 tok/s)
- **`demos/llama3-java/`** - Pure Java (✅ ~13 tok/s)
- **`demos/tornadovm/`** - GPU acceleration (✅ ~6 tok/s)


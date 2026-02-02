# CPython Llama Demo - Python LLM Inference

This demo runs Llama model inference using **standard CPython** with `llama-cpp-python`.

## What This Demo Shows

- Running LLM inference with Python on the JVM ecosystem
- Using `llama-cpp-python` (ctypes bindings to llama.cpp)
- Cross-language model sharing (same `.gguf` file used by TornadoVM, java-llama.cpp, etc.)
- Proper Llama 3.2 Instruct chat template formatting
- Why CPython works but GraalPy doesn't (ctypes compatibility)

## Requirements

- **Python 3.10+** (standard CPython, not GraalPy)
- **llama-cpp-python** library
- **Model file**: Llama 3.2 1B Instruct in FP16 format (~2.5 GB)

## Setup

### 1. Download Model

```bash
# Using the project download script
./scripts/download-models.sh --fp16

# Or manually
mkdir -p ~/.llama/models
curl -L -o ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"
```

### 2. Install Python Dependencies

The run script automatically creates a virtualenv and installs dependencies on first run.

Or manually:
```bash
cd demos/cpython-llama
python3 -m venv .venv
source .venv/bin/activate
pip install llama-cpp-python
```

## Running

### Using Gradle (easiest)

```bash
# From project root
./gradlew :demos:cpython-llama:run
```

This runs with default prompt: "Tell me a short joke about programming."

### Using the Script Directly

```bash
cd demos/cpython-llama
./scripts/run-llama.sh --prompt "tell me a joke"
```

**Options:**
```
--model PATH       Path to GGUF model (default: ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf)
--prompt TEXT      Prompt for the model
--max-tokens N     Maximum tokens to generate (default: 256)
--temperature F    Temperature for sampling (default: 0.7)
```

**Examples:**
```bash
# Basic usage
./scripts/run-llama.sh --prompt "explain closures in JavaScript"

# Custom settings
./scripts/run-llama.sh --max-tokens 512 --temperature 0.1 --prompt "what is 2+2?"

# Custom model
./scripts/run-llama.sh --model ~/models/custom.gguf --prompt "hello"
```

### Using Python Directly

```bash
cd demos/cpython-llama
python3 llama_inference.py --prompt "tell me a joke" --max-tokens 128
```

## Performance

**Tested on macOS ARM64 (Apple M1 Pro):**

| Metric | Value |
|--------|-------|
| Model load time | ~23s |
| Inference time (32 tokens) | ~3-5s |
| Throughput | ~10 tokens/sec (CPU only) |

**Note:** This uses CPU-only inference. For GPU acceleration on macOS, use `demos/java-llama-cpp/` which supports Metal GPU (~50 tokens/sec).

## Why CPython vs GraalPy?

### CPython (this demo) ✅
- **Works perfectly** with llama-cpp-python
- Full ctypes compatibility
- Standard Python ecosystem
- ~10 tokens/sec on CPU

### GraalPy ❌
- **Fails** with llama-cpp-python
- ctypes limitation: cannot return structs by value
- Error: `SystemError: returning struct by value is not supported`
- See `demos/graalpy/` for details and attempt

**Verdict:** For Python-based LLM inference, use CPython. For Java-based, use `demos/java-llama-cpp/` or `demos/llama3-java/`.

## Comparison with Other Demos

| Demo | Language | Backend | Speed (M1 Pro) | Status |
|------|----------|---------|----------------|--------|
| **java-llama.cpp** | Java (JNI) | llama.cpp + Metal GPU | ~50 tok/s | ✅ Best |
| **Cyfra** | Scala | Vulkan GPU | ~33 tok/s | ✅ |
| **Llama3.java (JDK 25)** | Pure Java | Vector API CPU | ~13 tok/s | ✅ |
| **CPython (this)** | Python | llama.cpp CPU | ~10 tok/s | ✅ |
| **TornadoVM** | Java | OpenCL GPU | ~6 tok/s | ✅ |
| **GraalPy** | Python (GraalVM) | - | - | ❌ ctypes fails |

## Code Structure

```
demos/cpython-llama/
├── llama_inference.py    # Main inference script
├── scripts/
│   └── run-llama.sh      # Wrapper with venv setup
├── build.gradle.kts      # Gradle integration
└── README.md             # This file
```

## Technical Details

**llama_inference.py** includes:
- Llama 3.2 Instruct chat template formatting
- GGUF model loading via llama-cpp-python
- Token counting and timing
- Proper error handling

**Dependencies:**
- `llama-cpp-python` - Python bindings for llama.cpp
- Automatically compiled with CPU support on first install

## See Also

- **`demos/graalpy/`** - Java → GraalPy embedding (basic demo works, LLM fails)
- **`demos/java-llama-cpp/`** - JNI bindings for llama.cpp (✅ fastest, ~50 tok/s with GPU)
- **`demos/llama3-java/`** - Pure Java LLM (✅ no dependencies, ~13 tok/s)
- **`demos/tornadovm/`** - TornadoVM GPU acceleration (✅ ~6 tok/s)

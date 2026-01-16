# Demo: GraalPy Llama Inference

This demo runs Llama model inference using GraalPy (Python on GraalVM) with the same model used by the TornadoVM GPULlama3 demo.

## Requirements

- GraalPy installed via one of these methods:

  **Option 1: pyenv (recommended)**
  ```bash
  pyenv install graalpy-community-24.1.1
  pyenv local graalpy-community-24.1.1
  ```

  **Option 2: Standalone download**
  Download from https://github.com/oracle/graalpython/releases

- Model file (Llama 3.2 1B Instruct in FP16 format)

## Model Setup

Download the same model used by TornadoVM (~2.5 GB):

```bash
mkdir -p ~/.tornadovm/models
curl -L -o ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf \
  "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"
```

## Running

```bash
./scripts/run-llama.sh --prompt "tell me a joke"
```

The script will:
1. Find your GraalPy installation
2. Create a virtual environment (first run only)
3. Install `llama-cpp-python` (first run only)
4. Run inference with your prompt

### Options

```
--model PATH       Path to GGUF model (default: ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf)
--prompt TEXT      Prompt for the model (default: "Tell me a short joke about programming.")
--max-tokens N     Maximum tokens to generate (default: 256)
--temperature F    Temperature for sampling (default: 0.7)
```

### Examples

```bash
# Basic usage
./scripts/run-llama.sh --prompt "tell me a joke"

# Custom model and settings
./scripts/run-llama.sh --model ~/models/llama.gguf --prompt "explain recursion" --max-tokens 512

# Lower temperature for more deterministic output
./scripts/run-llama.sh --prompt "what is 2+2?" --temperature 0.1
```

## Comparison with TornadoVM GPULlama3

| Feature | GraalPy Llama | TornadoVM GPULlama3 |
|---------|---------------|---------------------|
| Language | Python (GraalPy) | Java |
| Model | Llama 3.2 1B Instruct (FP16) | Llama 3.2 1B Instruct (FP16) |
| Backend | llama.cpp (CPU) | TornadoVM (GPU) |
| Model Format | GGUF | GGUF |

## Known Limitation: ctypes Struct Return

**Status:** This demo currently does not work due to a GraalPy limitation.

When running with GraalPy 25.0.1, the following error occurs:

```
File ".venv/lib/python3.12/site-packages/llama_cpp/llama.py", line 225, in __init__
    self.model_params = llama_cpp.llama_model_default_params()
SystemError: ctypes: returning struct by value is not supported.
```

### Root Cause

The `llama-cpp-python` library uses ctypes to call native `llama.cpp` functions. The function `llama_model_default_params()` returns a C struct by value, which GraalPy's ctypes implementation does not support.

The underlying [Truffle NFI (Native Function Interface)](https://www.graalvm.org/latest/graalvm-as-a-platform/language-implementation-framework/NFI/) supports these types: `VOID`, `SINT*`, `UINT*`, `FLOAT`, `DOUBLE`, `POINTER`, `STRING`, `OBJECT`, `ENV` — but **struct types are not listed** as supported return values.

### Workaround (Tested ✓)

Until GraalPy adds support for returning structs by value, you can run this demo with standard CPython instead:

```bash
pip3 install llama-cpp-python
python3 llama_inference.py --prompt "tell me a joke"
```

**Tested with CPython 3.13.0 on macOS ARM64:**

| Metric | Value |
|--------|-------|
| Model load time | ~23s |
| Inference time | ~5s |
| Throughput | ~10 tokens/sec |

Example output:
```
A man walked into a library and asked the librarian, "Do you have any
books on Pavlov's dogs and Schrödinger's cat?"

The librarian replied, "It rings a bell, but I'm not sure if it's here or not."
```

### References

- [Truffle NFI Documentation](https://www.graalvm.org/latest/graalvm-as-a-platform/language-implementation-framework/NFI/)
- [GraalPy GitHub Repository](https://github.com/oracle/graalpython)

## What This Demo Shows

- Running Python ML libraries on GraalVM's GraalPy
- Using the same model across different JVM ecosystem tools
- llama.cpp Python bindings compatibility with GraalPy (pending ctypes struct support)
- Cross-language model sharing (same `.gguf` file for Java and Python)
- Proper Llama 3.2 Instruct chat template formatting

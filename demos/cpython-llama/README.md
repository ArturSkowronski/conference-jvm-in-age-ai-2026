# CPython Llama Demo

Gradle wrapper for running the Llama inference demo using CPython (instead of GraalPy).

## Quick Start

Run with default prompt:
```bash
./gradlew :demos:cpython-llama:run
```

This executes: `python3 llama_inference.py --prompt "Tell me a short joke about programming."`

## Custom Prompts

To run with custom prompts, use the Python script directly:

```bash
cd demos/graalpy-llama
python3 llama_inference.py --prompt "Your custom prompt here"
python3 llama_inference.py --prompt "Explain closures in JavaScript" --max-tokens 100
```

## Why CPython?

GraalPy has a limitation with `ctypes.CFUNCTYPE` callbacks that causes crashes with llama-cpp-python. CPython works without this issue.

## Requirements

- Python 3.10+
- llama-cpp-python installed (see `demos/graalpy-llama/README.md` for setup)
- Llama model at `~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf`

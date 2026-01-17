# Demo: Llama3.java (Pure Java LLM Inference)

This demo runs Llama model inference using [Llama3.java](https://github.com/mukel/llama3.java) - a pure Java implementation with no native dependencies.

## What This Demo Shows

- **100% Pure Java** LLM inference - no JNI, no native libraries
- Java Vector API for SIMD acceleration
- GraalVM optimizations for best performance
- Single-file implementation (~3000 lines of Java)
- GGUF model format support (Q4_0, Q8_0, F16, BF16)

## Requirements

- JDK 21+ (GraalVM recommended for best performance)
- Model file in GGUF format (Q4_0 quantization recommended)

## Model Setup

Llama3.java works best with Q4_0 quantized models. Download a compatible model:

```bash
mkdir -p ~/.llama/models
curl -L -o ~/.llama/models/Llama-3.2-1B-Instruct-Q4_0.gguf \
  "https://huggingface.co/hugging-quants/Llama-3.2-1B-Instruct-Q4_0-GGUF/resolve/main/llama-3.2-1b-instruct-q4_0.gguf"
```

Note: The FP16 model used by other demos will also work but Q4_0 is recommended for Llama3.java.

## Running

```bash
# Basic usage with default Q4_0 model
./scripts/run-llama3.sh --prompt "Tell me a joke"

# With FP16 model (same as other demos)
./scripts/run-llama3.sh \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Tell me a joke"

# Interactive chat mode
./scripts/run-llama3.sh --chat

# With GraalVM for better performance
sdk use java 24.ea-graal
./scripts/run-llama3.sh --prompt "Tell me a joke"
```

### Options

```
--model PATH      Path to GGUF model
--prompt TEXT     Prompt for the model
--max-tokens N    Maximum tokens to generate (default: 256)
--chat            Run in interactive chat mode
--instruct        Run in instruct mode (default)
```

## Running Directly (Without Script)

You can also run Llama3.java directly:

```bash
java --enable-preview --source 21 --add-modules jdk.incubator.vector \
  Llama3.java --instruct \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-Q4_0.gguf \
  --prompt "Tell me a joke"
```

## GraalVM Native Image (Optional)

For instant startup and minimal memory footprint:

```bash
# Compile to native image with model preloaded
PRELOAD_GGUF=~/.llama/models/Llama-3.2-1B-Instruct-Q4_0.gguf \
  native-image --enable-preview -O3 -march=native \
  --add-modules jdk.incubator.vector \
  -o llama3 Llama3.java

# Run native image
./llama3 --instruct --prompt "Tell me a joke"
```

## Comparison with Other Demos

| Demo | Type | Dependencies | GPU Support |
|------|------|--------------|-------------|
| **Llama3.java** | Pure Java | None | No (CPU + Vector API) |
| java-llama.cpp | JNI bindings | llama.cpp native lib | Yes (Metal/CUDA) |
| TornadoVM GPULlama3 | Pure Java | TornadoVM | Yes (OpenCL/CUDA) |
| llama-cpp-python | Python + ctypes | llama.cpp native lib | Yes (Metal/CUDA) |

## Key Features

- **No native dependencies** - runs anywhere Java runs
- **Vector API acceleration** - uses SIMD when available
- **GraalVM optimized** - best performance with Graal JIT
- **AOT compilation** - supports GraalVM Native Image
- **Educational** - clean, readable single-file implementation

## References

- [Llama3.java GitHub](https://github.com/mukel/llama3.java)
- [Llama2.java (predecessor)](https://github.com/mukel/llama2.java)
- [Java Vector API](https://openjdk.org/jeps/448)

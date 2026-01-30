# Demo: java-llama.cpp (JNI Bindings for llama.cpp)

This demo runs Llama model inference using [java-llama.cpp](https://github.com/kherud/java-llama.cpp) - Java JNI bindings for llama.cpp.

## What This Demo Shows

- Pure Java LLM inference via JNI bindings to llama.cpp
- Same GGUF model format as TornadoVM GPULlama3 and GraalPy Llama demos
- Native performance with Java API convenience
- Cross-platform support (Linux, macOS, Windows)

## Requirements

- JDK 17+
- Model file (Llama 3.2 1B Instruct in FP16 format)

## Model Setup

Download the same model used by other demos (~2.5 GB):

```bash
mkdir -p ~/.llama/models
curl -L -o ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"
```

## Running

```bash
# Using default model and prompt
./gradlew :demos:java-llama-cpp:run

# With custom prompt
./gradlew :demos:java-llama-cpp:runLlama -Pprompt="Tell me a joke"

# With custom model path
./gradlew :demos:java-llama-cpp:runLlama -Pmodel=/path/to/model.gguf -Pprompt="Hello"
```

## Expected Output

```
============================================================
java-llama.cpp Inference Demo
============================================================
Java: 25
VM: OpenJDK 64-Bit Server VM
OS: Mac OS X aarch64
============================================================

Loading model: /Users/.../.llama/models/Llama-3.2-1B-Instruct-f16.gguf
Model loaded in 19.47s

Prompt: Tell me a short joke about programming.
----------------------------------------
Response:
Why do programmers prefer dark mode?

Because light attracts bugs.
----------------------------------------

Stats:
  Model load time: 19.47s
  Inference time: 0.43s
  Tokens generated: 18
  Tokens/sec: 42.35
```

Note: On Apple Silicon, java-llama.cpp uses Metal acceleration achieving ~47 tokens/sec during inference.

## CUDA GPU Acceleration

The Maven artifact `de.kherud:llama:4.1.0` bundles **CPU-only** native libraries. To use NVIDIA GPU acceleration, you must build the native library from source with CUDA support.

### Building from source

```bash
# Clone and build with CUDA
git clone --depth 1 https://github.com/kherud/java-llama.cpp.git /tmp/java-llama-cpp
cd /tmp/java-llama-cpp
mvn compile -q

# Build native library with CUDA (on GCP, add -DCMAKE_CUDA_COMPILER explicitly)
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
cmake --build build --config Release -j$(nproc)

# Copy the CUDA-enabled native library
mkdir -p ~/jllama-cuda
find /tmp/java-llama-cpp -name "libjllama.so" -exec cp {} ~/jllama-cuda/ \;
```

### Running with CUDA

Point java-llama.cpp at the CUDA-built native and enable GPU layer offload:

```bash
./gradlew :demos:java-llama-cpp:run \
  -Dde.kherud.llama.lib.path=$HOME/jllama-cuda
```

The demo's `JavaLlamaCppDemo.java` calls `setGpuLayers(99)` to offload all transformer layers to the GPU when `LLAMA_GPU_LAYERS` is set.

### Performance: CPU vs CUDA

On a GCP n1-standard-4 + Tesla T4 with Llama 3.2 1B Instruct FP16:

| Mode | Tokens/sec | Speedup |
|------|-----------|---------|
| CPU-only (Maven native) | 6.42 tok/s | 1x |
| CUDA (17/17 layers on T4) | **72.89 tok/s** | **11x** |

CUDA offloads all 17 transformer layers to the GPU (`load_tensors: offloaded 17/17 layers to GPU`), putting 2.3 GB of the model in GPU VRAM and achieving 72.89 tok/s generation speed.

### CUDA Troubleshooting

- **cmake can't find nvcc**: Pass `-DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc` explicitly and ensure `/usr/local/cuda/bin` is on `PATH`
- **`ggml_cuda_init: failed to initialize CUDA: unknown error`**: Check for NVIDIA driver/library version mismatch (`nvidia-smi` will report it). Reboot the machine to reload the kernel module.
- **Falls back to CPU despite GPU offload**: Verify `nvidia-smi` works, check that `libjllama.so` was built with `-DGGML_CUDA=ON`, and confirm the lib path override is set correctly

## Comparison with Other Demos

| Demo | Technology | Backend | Binding Type |
|------|------------|---------|--------------|
| java-llama.cpp | Java + JNI | llama.cpp (CPU or CUDA GPU) | JNI |
| TornadoVM GPULlama3 | Java | OpenCL (GPU) | Pure Java |
| llama-cpp-python | Python | llama.cpp (CPU) | ctypes |

## Key Source File

- `src/main/java/conf/jvm/llama/JavaLlamaCppDemo.java`

## References

- [java-llama.cpp GitHub](https://github.com/kherud/java-llama.cpp)
- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [GGUF Model Format](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md)

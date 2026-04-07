# TornadoVM 3.0 Demo - GPU Acceleration with JDK 25 & LLM Inference

Alternative version of the TornadoVM demo targeting **TornadoVM 3.0.0-jdk25** with:
- **JDK 25** requirement (first TornadoVM release targeting JDK 25)
- **Metal backend** for native Apple Silicon acceleration
- **GPULlama3.java** for GPU-accelerated LLM inference
- **Auto-detection** of best backend (Metal/OpenCL/PTX)

## Quick Start

### Baseline (CPU) - Works Everywhere

```bash
./gradlew :demos:tornadovm-3:run
```

### TornadoVM 3.0 (GPU) - Requires JDK 25

```bash
cd demos/tornadovm-3
./scripts/run-tornado.sh --size 10000000 --iters 5
```

### GPU LLM Inference (GPULlama3.java)

```bash
cd demos/tornadovm-3
./scripts/run-gpullama3.sh --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf --prompt "Hello"
```

## Version Comparison

| Feature | TornadoVM 2.2.0 | TornadoVM 3.0.0 | TornadoVM 4.0.0 |
|---------|-----------------|-----------------|-----------------|
| **JDK** | 21 (GraalVM CE) | **25** | 21, 25 |
| **Backends** | OpenCL, PTX, SPIR-V | OpenCL, PTX, SPIR-V, **Metal** | OpenCL, PTX, SPIR-V, Metal |
| **macOS Apple Silicon** | OpenCL (deprecated) | **Metal (native)** | Metal (native) |
| **Download format** | .tar.gz | .zip | .zip |
| **ImmutableTaskGraph** | Yes | Yes (enhanced) | Yes (enhanced) |
| **CUDA Graphs** | No | No | `withCUDAGraph()` |

## What This Demo Shows

**VectorAddBaseline** (Gradle task):
- Simple vector addition on CPU
- Baseline performance measurement
- Works on any JDK 21+

**VectorAddTornado** (script-based):
- Same operation on GPU via TornadoVM 3.0
- TaskGraph API for GPU offload
- @Parallel annotation for parallelization
- Auto-detects Metal on macOS Apple Silicon

**GPULlama3** (script-based):
- Full LLM inference on GPU
- Uses GPULlama3.java with TornadoVM 3.0
- Supports Llama 3.2, Qwen, Phi3, Granite models

## Requirements

**Baseline demo:**
- JDK 21+ (any distribution)

**TornadoVM 3.0 GPU demo:**
- **JDK 25** (required by TornadoVM 3.0)
- TornadoVM 3.0 SDK (auto-downloaded by script)
- Metal (macOS) or OpenCL/CUDA drivers (Linux)

**GPU LLM inference:**
- All of the above
- Model file: `~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf` (~2.5 GB)

## Running

```bash
# CPU baseline (Gradle)
./gradlew :demos:tornadovm-3:run
./gradlew :demos:tornadovm-3:runtimeCheck

# GPU version (script - auto-downloads TornadoVM 3.0)
cd demos/tornadovm-3
./scripts/run-tornado.sh --size 10000000 --iters 5

# Force specific backend
TORNADOVM_BACKEND=metal ./scripts/run-tornado.sh
TORNADOVM_BACKEND=opencl ./scripts/run-tornado.sh
TORNADOVM_BACKEND=ptx ./scripts/run-tornado.sh

# GPU LLM inference
./scripts/run-gpullama3.sh --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf --prompt "Hello"
```

## Code Structure

```
demos/tornadovm-3/
├── src/
│   ├── main/java/com/skowronski/talk/jvmai/
│   │   └── VectorAddBaseline.java   # CPU version (Gradle)
│   └── tornado/java/demo/tornadovm/
│       └── VectorAddTornado.java    # GPU version (script)
├── scripts/
│   ├── run-baseline.sh              # CPU demo
│   ├── run-tornado.sh               # GPU demo (TornadoVM 3.0, auto-downloads)
│   └── run-gpullama3.sh             # GPU LLM (TornadoVM 3.0)
├── build.gradle.kts                 # Gradle build (baseline only)
└── README.md                        # This file
```

## See Also

- **`demos/tornadovm/`** - Original TornadoVM 2.2.0 demo (JDK 21)
- **`demos/tornadovm-4/`** - TornadoVM 4.0.0 demo (JDK 21/25, CUDA Graphs)
- **`demos/llama3-java/`** - Pure Java LLM (CPU, Vector API)
- **`demos/java-llama-cpp/`** - JNI LLM (~50 tok/s)
- **`demos/babylon/`** - Future GPU approach (Code Reflection)

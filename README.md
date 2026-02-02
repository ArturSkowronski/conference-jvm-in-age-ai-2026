# Conference Talk: JVM in the Age of AI - 2026 Edition

This repository contains demos, benchmarks, and documentation from the "JVM in the Age of AI" conference talk (2026). All demos are functional and can be run on your own hardware.

## Documentation

- **[docs/Talk.md](docs/Talk.md)** - Live demo script and presentation flow
- **[docs/Benchmark.md](docs/Benchmark.md)** - Comprehensive benchmark analysis and results
- **[docs/CloudEnvironmentsAnalysis.md](docs/CloudEnvironmentsAnalysis.md)** - Cloud deployment guide and platform comparison
- **[docs/Babylon workflow.md](docs/Babylon%20workflow.md)** - Project Babylon specifics and HAT framework
- **[benchmark-results/gcp/GCP-Benchmark.md](benchmark-results/gcp/GCP-Benchmark.md)** - GCP GPU benchmark results

**Demo-specific findings:**
- **[demos/graalpy/Findings.md](demos/graalpy/Findings.md)** - GraalPy technical analysis and ctypes limitations
- **[demos/valhalla/FINDINGS.md](demos/valhalla/FINDINGS.md)** - Float16 and Vector API research

## Demos

- `demos/tornadovm/` - simple TornadoVM demo (baseline vs TaskGraph)
- `cyfra-demo/` - Cyfra LLM inference (Scala 3 → Vulkan GPU via SPIR-V)
- `demos/jcuda/` - JCuda support demo (CUDA driver + device info)
- `demos/tensorflow-ffm/` - TensorFlow C API via FFM (no JNI / no Python)

Demo materials:
- `demos/graalpy/` - GraalPy Python embedding (3 demos: basic embedding, CPython LLM, GraalPy LLM)
- `demos/llama3-java/` - Pure Java LLM inference with Vector API
- `demos/java-llama-cpp/` - JNI bindings for llama.cpp (fastest)
- `demos/babylon/` - Project Babylon code reflection
- `demos/valhalla/` - Project Valhalla value types and FP16

## Prereqs

- SDKMAN!: `https://sdkman.io`

## Setup (SDKMAN!)

This repo includes a `.sdkmanrc`. In the repo root:

- Install declared candidates: `sdk env install`
- Use the declared versions in this shell: `sdk env`

## Run

- JCuda: `./gradlew :demos:jcuda:run`
- TensorFlow (FFM): `./gradlew :demos:tensorflow-ffm:runTensorFlow`
- GraalPy (all 3 demos): `./gradlew :demos:graalpy:run`

## Switching JDKs

- Change the `java=` entry in `.sdkmanrc`, then `sdk env install && sdk env`
- Or override Gradle’s toolchain version: `./gradlew :demos:jcuda:run -PjavaVersion=23`

## TensorFlow (FFM, no JNI / no Python)

This repo includes a small demo of calling the TensorFlow C API from Java (using the Foreign Function & Memory API).

Requires JDK 22+ (FFM is final).

Run:

- `./gradlew :demos:tensorflow-ffm:runTensorFlow`
- Or with your own TensorFlow build: `./gradlew :demos:tensorflow-ffm:runTensorFlow -PtensorflowHome=/path/to/unpacked/libtensorflow`

### Supported Platforms

| Platform | Status |
|----------|--------|
| Linux x86_64 | ✅ Supported |
| macOS ARM64 (Apple Silicon) | ✅ Supported |
| Windows x86_64 | ✅ Supported |
| macOS x86_64 (Intel) | ❌ Not supported |

**Why no macOS x86_64?** TensorFlow dropped support for Intel Macs after version 2.16.2. This demo uses TensorFlow 2.18.0 for consistency across all platforms. If you need macOS x86_64 support, provide your own TF C library via `-PtensorflowHome=...`.

Notes:
- The build downloads the TensorFlow C library (v2.18.0) into `build/tensorflow/` automatically.

## GraalVM (notes)

- Install GraalVM via SDKMAN! (set `java=` to a GraalVM distribution) and re-run `sdk env`

## GraalPy (notes)

If you install a GraalVM distribution, you can add Python with `gu` and use `graalpy` for experiments:

- `gu install python`
- `graalpy --version`

## TornadoVM (notes)

TornadoVM requires a compatible JDK + its runtime; treat it as a separate SDKMAN "java" candidate and point `.sdkmanrc` at it when needed.

## Cyfra (Scala/Vulkan GPU)

Cyfra is a Scala 3 library that compiles GPU programs to SPIR-V and runs them on Vulkan. The `llm.scala` branch includes a full Llama inference implementation.

Run:
```bash
./cyfra-demo/scripts/run-cyfra-llama.sh \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Hello" --measure
```

Requirements:
- **sbt** (Scala Build Tool): https://www.scala-sbt.org/download
- **Vulkan drivers** (included with NVIDIA/AMD/Intel drivers on Linux/Windows)

### macOS / MoltenVK Setup

macOS requires MoltenVK (Vulkan-over-Metal translation layer). Two options:

**Option 1: Install Vulkan SDK (recommended)**
1. Download from https://vulkan.lunarg.com/sdk/home
2. Set environment:
   ```bash
   export VULKAN_SDK="$HOME/VulkanSDK/<version>/macOS"
   ```
   The run script automatically configures LWJGL to use MoltenVK.

**Option 2: Homebrew (may have issues)**
```bash
brew install molten-vk
```

**Known MoltenVK issues on macOS:**
- **LWJGL can't find libvulkan** - If you see `Failed to create Vulkan instance`, ensure `VULKAN_SDK` is set and contains `lib/libvulkan.1.dylib`.
- **MoltenVK version mismatch** - Some Homebrew versions may be incompatible with LWJGL. Prefer the official Vulkan SDK.
- **Apple Silicon vs Intel** - Both architectures are supported, but ensure you download the correct SDK variant.

Performance on Apple M1 Pro: ~30 tok/s (Llama-3.2-1B-Instruct-f16.gguf)

## Docker / GCP GPU Benchmarks

The full benchmark suite (all demos + LLM inference) can be run inside a Docker container on any machine with an NVIDIA GPU, or deployed to a GCP Spot instance.

### Docker (local or any NVIDIA GPU machine)

```bash
# Build the image (includes CUDA-enabled java-llama.cpp, TornadoVM, JDK 25 + JDK 21)
docker build -t jvm-ai-benchmark -f docker/Dockerfile .

# Run all benchmarks (model is downloaded automatically if missing)
docker run --rm --gpus all \
  -v ~/models:/models \
  -v ~/results:/results \
  jvm-ai-benchmark
```

Results (Markdown + JSON + per-demo logs) are written to the `/results` volume.

### GCP Spot Instance (automated)

```bash
# Deploy, run bare-metal + Docker benchmarks, fetch results, delete the VM:
./docker/run-on-gcp.sh --zone europe-west1-b --gpu nvidia-tesla-t4 --delete
```

This creates an `n1-standard-4` Spot VM with a Tesla T4 (~$0.35/hr), installs all dependencies, runs 6 bare-metal demos + 8 Docker demos, copies results to `benchmark-results/gcp/`, and deletes the VM.

See `benchmark-results/gcp/GCP-Benchmark.md` for full results and analysis.

### GCP / CUDA Troubleshooting

Six issues were encountered during GCP deployment and are documented here for future reference:

1. **GCP Deep Learning VM image renamed** - The image family `common-cu121-ubuntu-2204` no longer exists. Use `common-cu128-ubuntu-2204-nvidia-570` instead (CUDA 12.8, driver 570.x).

2. **Docker not pre-installed on new DL VM images** - The `common-cu128` image does not include Docker. The deployment script installs Docker CE and `nvidia-container-toolkit` automatically.

3. **TornadoVM backend mismatch** - GPULlama3.java requires the OpenCL backend (`tornado.drivers.opencl` module). Using the PTX backend will fail. Also requires:
   - `gcc-13` from `ubuntu-toolchain-r` PPA (for `GLIBCXX_3.4.32`)
   - OpenCL ICD configured for NVIDIA: `/etc/OpenCL/vendors/nvidia.icd` containing `libnvidia-opencl.so.1`

4. **NVIDIA driver/library version mismatch after apt-get** - Installing packages (e.g., `gcc-13`) can trigger an NVIDIA userspace library upgrade (e.g., 570.195 → 570.211) while the kernel module stays at the old version. Symptoms:
   - `nvidia-smi` reports `Failed to initialize NVML: Driver/library version mismatch`
   - CUDA programs fail with `CUDA_ERROR_UNKNOWN`
   - OpenCL reports `clGetPlatformIDs -> Returned: -1001`
   - `nvidia-persistenced` is dead

   **Fix**: Reboot the VM (`sudo reboot`) to reload the kernel module matching the upgraded userspace libraries.

5. **cmake cannot find CUDA compiler on bare metal** - cmake's CUDA language detection can fail on GCP VMs even when `nvcc` is installed. Fix by passing the compiler path explicitly:
   ```bash
   export PATH="/usr/local/cuda/bin:$PATH"
   cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
   ```

6. **Vulkan not working on GCP (NVIDIA Open Kernel Modules)** - GCP Deep Learning VMs use NVIDIA Open Kernel Modules (`nvidia-*-open`) by default, which do **not** support Vulkan. Symptom:
   ```
   ERROR: Could not get 'vkCreateInstance' via 'vk_icdGetInstanceProcAddr' for ICD libGLX_nvidia.so.0
   ```
   **Fix**: Install the proprietary NVIDIA driver which includes Vulkan support:
   ```bash
   sudo apt-get install -y nvidia-driver-570-server
   # Verify Vulkan sees the GPU
   vulkaninfo --summary | grep deviceName  # Should show "Tesla T4"
   ```
   The deployment script (`docker/run-on-gcp.sh`) installs the proprietary driver automatically

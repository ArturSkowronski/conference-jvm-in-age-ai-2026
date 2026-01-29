# GCP GPU Benchmark Results: JVM in the Age of AI

**Date**: January 29, 2026
**Cloud**: Google Cloud Platform (europe-west1-b, Spot instance)
**Cost**: ~$0.35/hr (n1-standard-4 + Tesla T4 spot)

---

## Environment

| Property | Value |
|----------|-------|
| Machine Type | n1-standard-4 (4 vCPU, 15 GB RAM) |
| GPU | NVIDIA Tesla T4 (16 GB VRAM, Compute Capability 7.5) |
| CUDA Driver | 570.211.01 |
| CUDA Toolkit | 12.8 (bare metal) / 12.6 (Docker) |
| OS | Ubuntu 22.04 (Deep Learning VM) |
| JDK 25 | Temurin 25.0.3-beta |
| JDK 21 | GraalVM CE 21.0.10 |
| TornadoVM | 2.2.0 (OpenCL backend) |
| Model | Llama 3.2 1B Instruct FP16 (~2.5 GB) |

---

## Results: Bare Metal vs Docker

### LLM Inference

| Approach | Bare Metal | Docker | GPU Used | Backend |
|----------|-----------|--------|----------|---------|
| **java-llama.cpp (CUDA)** | **72.89 tok/s** | **65.48 tok/s** | Yes (17/17 layers) | CUDA on T4 |
| TornadoVM GPULlama3 | 18.89 tok/s | 20.27 tok/s | Yes | OpenCL on T4 |
| Llama3.java (JDK 25) | 5.15 tok/s | 4.76 tok/s | No | Vector API (CPU SIMD) |
| Llama3.java (JDK 21) | 0.52 tok/s | 0.52 tok/s | No | Vector API (CPU SIMD) |

### Non-LLM Demos

| Demo | Bare Metal | Docker | Notes |
|------|-----------|--------|-------|
| JCuda | OK | OK (12s) | Tesla T4, Compute Capability 7.5, CUDA 12080 |
| TornadoVM VectorAdd | 10.91 GB/s | 11.41 GB/s | 10M elements, OpenCL on T4 |
| TensorFlow FFM | not tested | OK (16s) | TF 2.18.0 via Java 25 FFM API |
| GraalPy Java Host | not tested | OK (17s) | Python 3.12.8 on GraalVM |

**All 8 Docker demos and 6 bare-metal demos passed successfully.**

---

## Key Insights

### 1. java-llama.cpp with CUDA: 72.89 tok/s -- the fastest JVM inference path

Building java-llama.cpp from source with `-DGGML_CUDA=ON` and offloading all 17 layers to the T4 GPU produced **72.89 tok/s** on bare metal. This is:

- **14x faster** than Llama3.java JDK 25 on CPU (5.15 tok/s)
- **140x faster** than Llama3.java JDK 21 on CPU (0.52 tok/s)
- **3.9x faster** than TornadoVM GPULlama3 (18.89 tok/s)
- **11x faster** than the previous CPU-only java-llama.cpp run (6.42 tok/s)

Key details from the log:
```
load_tensors: offloaded 17/17 layers to GPU
load_tensors:   CPU_Mapped model buffer size =   501.00 MiB
load_tensors:        CUDA0 model buffer size =  2357.26 MiB
prompt eval time =     159.79 ms /    30 tokens (5.33 ms per token, 187.74 tokens/s)
       eval time =     370.10 ms /    27 tokens (13.71 ms per token, 72.96 tokens/s)
```

The Maven artifact `de.kherud:llama:4.1.0` does NOT include CUDA-capable natives. CUDA support requires building `libjllama.so` from source and passing `-Dde.kherud.llama.lib.path` to override the bundled native library.

### 2. Bare metal vs Docker: 11% overhead

| Approach | Bare Metal | Docker | Overhead |
|----------|-----------|--------|----------|
| java-llama.cpp CUDA | 72.89 tok/s | 65.48 tok/s | 10.2% |
| Llama3.java JDK 25 | 5.15 tok/s | 4.76 tok/s | 7.6% |
| Llama3.java JDK 21 | 0.52 tok/s | 0.52 tok/s | 0% |

Docker adds a small but measurable overhead for GPU-accelerated workloads. The NVIDIA container runtime passes through the GPU device but introduces some indirection. For CPU-only workloads (JDK 21), the overhead is negligible.

### 3. JDK 25 vs JDK 21: ~10x speedup via Vector API

| JDK Version | Generation Speed | Prompt Processing |
|-------------|-----------------|-------------------|
| JDK 21 (GraalVM CE) | 0.52 tok/s | 0.50 tok/s |
| JDK 25 (Temurin) | 5.15 tok/s | 4.94 tok/s |
| **Speedup** | **9.9x** | **9.9x** |

Upgrading from JDK 21 to JDK 25 gives a nearly 10x speedup for Vector API workloads with zero code changes. The Vector API maturation between these versions has yielded massive performance gains in the HotSpot JIT compiler's ability to map vector operations to hardware SIMD (AVX2) instructions.

### 4. GPU acceleration hierarchy

```
java-llama.cpp (CUDA, native C++)     72.89 tok/s  ████████████████████████████████████ 100%
TornadoVM GPULlama3 (OpenCL, Java)    18.89 tok/s  █████████                              26%
Llama3.java JDK 25 (CPU Vector API)    5.15 tok/s  ██▌                                     7%
Llama3.java JDK 21 (CPU Vector API)    0.52 tok/s  ▎                                       1%
```

Three tiers of JVM AI inference:
1. **Native CUDA via JNI** (java-llama.cpp): Fastest, but requires building native libs from source with CUDA toolkit
2. **Java-to-GPU compilation** (TornadoVM): Pure Java, 26% of native CUDA speed, impressive for auto-compiled code
3. **CPU Vector API** (Llama3.java): No GPU needed, but JDK version matters enormously (10x between JDK 21 and 25)

### 5. TornadoVM on dedicated GPU vs Apple Silicon

| Platform | TornadoVM GPULlama3 | Llama3.java (best JDK) | GPU wins? |
|----------|--------------------|-----------------------|-----------|
| Mac M1 Pro | 6.6 tok/s | 12 tok/s (JDK 25) | No |
| GCP Tesla T4 | **18.89 tok/s** | 5.15 tok/s (JDK 25) | **Yes, 3.7x** |

On the Mac, CPU beats TornadoVM-on-GPU because Apple's OpenCL-on-Metal translation layer adds overhead and the M1 Pro has fast unified memory. On the T4, GPU wins decisively with mature NVIDIA OpenCL drivers and dedicated GPU memory bandwidth.

### 6. TornadoVM VectorAdd: GPU memory bandwidth

```
TornadoVM: size=10000000, best=10.248 ms, throughput=10.91 GB/s
```

The T4's theoretical memory bandwidth is 320 GB/s. Achieving 10.91 GB/s through the Java-to-OpenCL pipeline shows significant overhead for memory-bound kernels, but the functionality works correctly.

---

## Comparison: Mac M1 Pro vs GCP Tesla T4

| Approach | Mac M1 Pro (32GB) | GCP T4 (15GB) | Notes |
|----------|-------------------|---------------|-------|
| java-llama.cpp (GPU) | 47 tok/s | **72.89 tok/s** | Metal vs CUDA |
| Llama3.java (JDK 25) | 12 tok/s | 5.15 tok/s | ARM NEON vs x86 AVX2 |
| TornadoVM GPULlama3 | 6.6 tok/s | **18.89 tok/s** | OpenCL-Metal vs OpenCL-NVIDIA |
| Llama3.java (JDK 21) | 0.3 tok/s | 0.52 tok/s | x86 slightly faster at baseline |
| java-llama.cpp (CPU) | -- | 6.42 tok/s | CPU-only (no GPU natives) |

Key takeaways:
- **CUDA on T4 beats Metal on M1 Pro by 55%** for java-llama.cpp (72.89 vs 47 tok/s)
- **TornadoVM is 2.9x faster on NVIDIA** than on Apple Silicon (18.89 vs 6.6 tok/s)
- **Apple Silicon's CPU is 2.3x faster** for Vector API workloads (12 vs 5.15 tok/s)

---

## Infrastructure Notes

### Docker Image

The benchmark runs inside a Docker container (`nvidia/cuda:12.6.0-devel-ubuntu22.04` base) with:
- Temurin JDK 25 EA and GraalVM CE 21 pre-installed
- TornadoVM 2.2.0 OpenCL SDK
- **java-llama.cpp native library built from source with CUDA** (`-DGGML_CUDA=ON`)
- Gradle dependency cache pre-warmed
- GPULlama3.java pre-cloned and built

### Bare Metal Setup

The bare-metal benchmarks install everything directly on the GCP Deep Learning VM:
- JDK 25 (Temurin EA) and GraalVM CE 21 downloaded to `~/jdks/`
- TornadoVM 2.2.0 OpenCL SDK in `~/tornadovm/`
- java-llama.cpp built from source with CUDA in `~/jllama-cuda/`
- gcc-13 from ubuntu-toolchain-r PPA (required by TornadoVM for GLIBCXX_3.4.32)
- OpenCL ICD configured for NVIDIA GPU

### GCP Setup Issues Resolved

Five issues were fixed during deployment:

1. **GCP Deep Learning VM image renamed**: `common-cu121-ubuntu-2204` no longer exists; updated to `common-cu128-ubuntu-2204-nvidia-570`
2. **Docker not pre-installed**: The new DL VM image requires manual Docker CE installation
3. **TornadoVM backend mismatch**: GPULlama3.java requires the OpenCL module; switched from PTX to OpenCL backend. Also needed GLIBCXX 3.4.32 (gcc-13 from PPA) and OpenCL ICD configuration
4. **NVIDIA driver/library version mismatch**: apt-get upgraded NVIDIA userspace libraries from 570.195 to 570.211 but the kernel module stayed at 570.195. Required VM reboot to reload the kernel module
5. **cmake CUDA compiler detection**: On bare metal, cmake needed explicit `-DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc` to find the CUDA compiler

### Reproducing

```bash
# Full deployment (bare metal + Docker):
./docker/run-on-gcp.sh --zone europe-west1-b --gpu nvidia-tesla-t4 --delete

# Docker only (on any machine with NVIDIA GPU):
docker build -t jvm-ai-benchmark -f docker/Dockerfile .
docker run --rm --gpus all -v ~/models:/models -v ~/results:/results jvm-ai-benchmark
```

---

*Benchmark conducted January 29, 2026 on a GCP Spot instance (n1-standard-4 + Tesla T4, europe-west1-b).*

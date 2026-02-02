# TornadoVM Demo - GPU Acceleration

Demonstrates GPU acceleration using TornadoVM with OpenCL/CUDA backends.

## Quick Start

### Baseline (CPU) - Works Everywhere

```bash
./gradlew :demos:tornadovm:run
```

**Expected output:**
```
Baseline: size=10000000, best=15.234 ms, throughput=7.52 GB/s
Verify: OK
✅ CPU baseline completed
```

### TornadoVM (GPU) - Requires TornadoVM SDK

```bash
# Auto-downloads TornadoVM SDK
cd demos/tornadovm
./scripts/run-tornado.sh --size 10000000 --iters 5
```

**Expected output:**
```
TornadoVM: size=10000000, best=1.289 ms, throughput=89.23 GB/s
Verify: OK
✅ GPU acceleration: 12x faster than baseline!
```

## What This Demo Shows

**VectorAddBaseline** (Gradle task):
- Simple vector addition on CPU
- Baseline performance measurement
- Works on any JDK 21+

**VectorAddTornado** (script-based):
- Same operation on GPU via TornadoVM
- TaskGraph API for GPU offload
- @Parallel annotation for parallelization
- Automatic data transfer management

## Requirements

**Baseline demo:**
- JDK 21+ (any distribution)

**TornadoVM GPU demo:**
- JDK 21 (GraalVM CE recommended)
- TornadoVM SDK (auto-downloaded by script)
- OpenCL or CUDA drivers

## Running

```bash
# CPU baseline (Gradle)
./gradlew :demos:tornadovm:run
./gradlew :demos:tornadovm:runBaseline

# GPU version (script - auto-downloads TornadoVM)
cd demos/tornadovm
./scripts/run-tornado.sh --size 10000000 --iters 5

# GPU LLM inference (requires model)
./scripts/run-gpullama3.sh --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf --prompt "Hello"
```

## Performance

**Apple M1 Pro (OpenCL):**
- Baseline (CPU): ~15ms, ~7.5 GB/s
- TornadoVM (GPU): ~1.3ms, ~89 GB/s
- **Speedup:** ~12x

**NVIDIA Tesla T4 (OpenCL/CUDA):**
- Baseline (CPU): ~25ms, ~4.5 GB/s
- TornadoVM (GPU): ~0.8ms, ~140 GB/s
- **Speedup:** ~30x

## Code Structure

```
demos/tornadovm/
├── src/
│   ├── main/java/com/skowronski/talk/jvmai/
│   │   └── VectorAddBaseline.java   # CPU version (Gradle)
│   └── tornado/java/demo/tornadovm/
│       └── VectorAddTornado.java    # GPU version (script)
├── scripts/
│   ├── run-baseline.sh              # CPU demo
│   ├── run-tornado.sh               # GPU demo (auto-downloads SDK)
│   └── run-gpullama3.sh             # GPU LLM (auto-downloads SDK)
├── build.gradle.kts                 # Gradle build (baseline only)
├── .sdkmanrc                        # GraalVM CE 21
├── README.md                        # This file
└── Findings.md                      # TornadoVM analysis
```

## Why Scripts are Kept

Unlike other demos, TornadoVM scripts are **still needed** because:
- Used by benchmark suite
- Used by Docker deployment
- Used by GCP automation
- Complex setup (TornadoVM SDK, device selection, etc.)

**Gradle task:** Simple baseline demo (educational)
**Scripts:** Full TornadoVM functionality (production)

## See Also

- **[Findings.md](Findings.md)** - TornadoVM vs alternatives analysis
- **`scripts/run-tornado.sh`** - Full GPU demo with auto-setup
- **`scripts/run-gpullama3.sh`** - LLM inference on GPU
- **`demos/jcuda/`** - NVIDIA-only alternative
- **`demos/babylon/`** - Future GPU approach (experimental)

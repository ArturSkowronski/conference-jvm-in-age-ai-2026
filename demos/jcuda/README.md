# JCuda Demo - CUDA from Java

Demonstrates accessing NVIDIA CUDA drivers directly from Java using JCuda bindings.

## Quick Start

```bash
./gradlew :demos:jcuda:run
```

**Expected output (with CUDA):**
```
[JCuda] JCuda Device Info Demo
[JCuda] os.name=Linux
[JCuda] CUDA Driver Version: 12.6
[JCuda] Number of CUDA devices: 1
[JCuda] ============================================================
[JCuda] Device 0: NVIDIA Tesla T4
[JCuda]   Compute Capability: 7.5
[JCuda]   Total Memory: 15360 MB
[JCuda] ============================================================
✅ JCuda initialized successfully
```

**Expected output (without CUDA - macOS/CPU-only):**
```
[JCuda] JCuda Device Info Demo
[JCuda] os.name=Mac OS X
[JCuda] CUDA not available on this platform
[JCuda] This is expected on macOS (no CUDA support)
✅ Demo gracefully handles CUDA absence
```

## What This Demo Shows

- **CUDA driver API access** from Java
- **GPU detection** and capabilities query
- **Graceful fallback** when CUDA not available
- **Platform-specific natives** handling in Gradle

## Requirements

**With CUDA (Linux/Windows):**
- JDK 21+
- NVIDIA GPU
- CUDA drivers installed

**Without CUDA (macOS/CPU-only):**
- JDK 21+
- Demo runs but shows "CUDA not available"

## Running

```bash
# Default task
./gradlew :demos:jcuda:run

# Explicit smoke test
./gradlew :demos:jcuda:runtimeCheck
```

## Results

**NVIDIA Tesla T4 (GCP):**
- Driver: CUDA 12.6
- Compute Capability: 7.5
- Memory: 15 GB
- ✅ Full CUDA support

**macOS (Apple Silicon):**
- No CUDA support (Apple uses Metal)
- Demo handles gracefully
- ✅ Shows informative message

## Code Structure

```
demos/jcuda/
├── src/main/java/com/skowronski/talk/jvmai/
│   └── JCudaInfoDemo.java       # CUDA device info query
├── build.gradle.kts             # Simple build (26 lines)
├── .sdkmanrc                    # Temurin 21
├── README.md                    # This file
└── Findings.md                  # JCuda technical analysis
```

## See Also

- **[Findings.md](Findings.md)** - JCuda vs CUDA vs alternatives
- **`demos/tensorflow-ffm/`** - FFM instead of JNI
- **`demos/tornadovm/`** - Cross-platform GPU (OpenCL/CUDA)

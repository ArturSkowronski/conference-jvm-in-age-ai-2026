# Babylon Demo - Code Reflection API + HAT

Demonstrates Project Babylon's Code Reflection API and HAT (Heterogeneous Accelerated Toolkit) for GPU programming from Java.

## Quick Start

### Option 1: Full Demo (RuntimeCheck + HAT MatMul)

```bash
# Runs both demos
./demos/babylon/run-babylon.sh
```

**Expected output:**
```
1. RuntimeCheck - Code Reflection Detection
============================================================
Code Reflection Module Present: true ✅
JDK Version: 26-internal (Babylon)

2. HAT MatMul - GPU Matrix Multiplication
============================================================
Matrix size: 1024×1024
Elapsed Time: ~6-25ms per iteration
Result is correct! ✅
```

### Option 2: RuntimeCheck Only (Gradle)

```bash
./gradlew :demos:babylon:run
```

**Expected output:**
```
Code Reflection Module Present: true ✅
(With Babylon JDK)

OR

Code Reflection Module Present: false ⚠️
(With standard JDK - expected)
```

## What This Demo Shows

**Two demonstrations:**

### 1. RuntimeCheck (Gradle task)
- Detects if Code Reflection API is available
- Shows loaded modules
- Works with any JDK 25+ (shows true/false for Code Reflection)

### 2. HAT MatMul (Script - from HAT repository)
- GPU matrix multiplication using HAT framework
- Java code compiled to OpenCL kernel
- Demonstrates Code Reflection in action
- Performance: ~6-25ms for 1024×1024 matrices

## Requirements

**For RuntimeCheck only:**
- Any JDK 25+

**For full demo (RuntimeCheck + HAT MatMul):**
- Babylon JDK 26 from `~/.sdkman/candidates/java/babylon-26-code-reflection`
- HAT framework built at `~/Github/babylon/hat`
- OpenCL drivers (GPU)

## Setup

**If you have Babylon JDK installed:**
```bash
cd demos/babylon
sdk env install && sdk env
```

**If you don't have Babylon JDK:**
```bash
# Download from:
https://jdk.java.net/babylon/

# Or build from source:
git clone --branch code-reflection https://github.com/openjdk/babylon.git
cd babylon
bash configure && make images

# Build HAT framework:
cd hat
java @hat/bld
```

## Running

```bash
# Complete demo (RuntimeCheck + HAT MatMul)
./demos/babylon/run-babylon.sh

# RuntimeCheck only (Gradle)
./gradlew :demos:babylon:run
./gradlew :demos:babylon:runtimeCheck

# HAT MatMul directly (from HAT repository)
cd ~/Github/babylon/hat
java @hat/run ffi-opencl matmul 2DTILING
```

## Results

**With Babylon JDK + HAT:**
- ✅ Code Reflection: Available
- ✅ HAT MatMul: Runs on GPU
- ✅ Performance: 6-25ms for 1024×1024 matrix multiplication

**With Standard JDK:**
- ⚠️ Code Reflection: Not available (expected)
- ❌ HAT MatMul: Cannot run (requires Babylon JDK)

## Performance

**HAT MatMul (1024×1024, OpenCL GPU):**
- First run: ~214ms (includes compilation)
- Subsequent: 4-25ms
- Speedup vs CPU: ~50-100x (typical)

## Code Structure

```
demos/babylon/
├── src/main/java/com/skowronski/talk/jvmai/
│   └── RuntimeCheck.java        # Code Reflection detection
├── HatMatMul.java               # Reference (API version mismatch)
├── run-babylon.sh               # Runs both demos
├── build.gradle.kts             # Gradle build (RuntimeCheck only)
├── .sdkmanrc                    # babylon-26-code-reflection
├── README.md                    # This file
└── Findings.md                  # Babylon/HAT analysis
```

**Note:** HatMatMul.java in this directory is from an older HAT version and won't compile. Working HAT examples are in `~/Github/babylon/hat/examples/`.

## See Also

- **[Findings.md](Findings.md)** - Babylon and HAT technical analysis
- **[docs/Babylon workflow.md](../../docs/Babylon%20workflow.md)** - Detailed HAT setup
- **`demos/tornadovm/`** - Alternative GPU approach (TornadoVM)
- **`demos/jcuda/`** - Direct CUDA bindings
- **`demos/valhalla/`** - Vector API research


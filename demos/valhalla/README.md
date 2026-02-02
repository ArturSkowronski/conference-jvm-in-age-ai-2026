# Valhalla Demo - Float16 and Vector API

Demonstrates half-precision floating point (FP16) and Vector API SIMD operations on JDK 24+.

## Quick Start

```bash
# Run Vector API demo (Float32 SIMD)
./gradlew :demos:valhalla:run

# Run FP16 demo (half-precision)
./gradlew :demos:valhalla:runFP16
```

**Expected output (Vector API):**
```
Vector API Demo - Float32 SIMD Operations
Array size: 1024 elements
Scalar dot product: 524800.0 (time: 0.05ms)
Vector dot product: 524800.0 (time: 0.02ms)
✅ Results match! SIMD is 2.5x faster
```

**Expected output (FP16):**
```
Float16 Vector API Demo
Testing FP16 value type (JDK 24+)
FP16 value: 3.14 → 3.140625 (precision loss expected)
✅ FP16 scalar operations work
⚠️  Float16Vector not yet available (under development)
```

## What This Demo Shows

**VectorAPIDemo.java:**
- Float32 SIMD operations using Vector API
- Dot product: scalar vs SIMD comparison
- Performance gains from vectorization (~2-3x)

**FP16VectorDemo.java:**
- Float16 value type (JDK 24+) for memory efficiency
- Mixed precision: FP16 storage, FP32 computation
- Status of Float16Vector (not yet available)

## Requirements

- **JDK 25+** (has Float16 support and latest Vector API)
- Vector API incubator module (auto-configured)

## Running

```bash
# Vector API (FP32) - default
./gradlew :demos:valhalla:run

# Vector API (FP32) - explicit
./gradlew :demos:valhalla:runVectorAPI

# FP16 value type demo
./gradlew :demos:valhalla:runFP16
```

## Results

**Vector API (FP32):**
- ✅ Works on JDK 21+
- SIMD speedup: 2-3x vs scalar
- Dot product benchmark included

**Float16:**
- ✅ Float16 value type works (JDK 24+)
- ❌ Float16Vector not available yet (JDK-8370691)
- Expected in future JDK release

## Code Structure

```
demos/valhalla/
├── src/main/java/com/skowronski/talk/jvmai/
│   ├── VectorAPIDemo.java       # FP32 SIMD operations
│   └── FP16VectorDemo.java      # FP16 value type
├── build.gradle.kts             # Gradle tasks
├── .sdkmanrc                    # JDK 25 (or Valhalla EA)
├── README.md                    # This file
└── FINDINGS.md                  # Float16/Vector API research
```

## See Also

- **[FINDINGS.md](FINDINGS.md)** - Float16 and Vector API research (comprehensive)
- **`demos/llama3-java/`** - Vector API in production (LLM inference)
- **`demos/tensorflow-ffm/`** - FFM for native SIMD libraries

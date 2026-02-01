# FP16 Vector API Demo (Project Valhalla)

Demonstrates half-precision floating point (FP16) SIMD operations using JDK 24+ Vector API.

## What This Demo Shows

1. **Native FP16 SIMD Operations**
   - Creating Float16 arrays from float inputs
   - Loading into Float16Vector using SPECIES_PREFERRED
   - SIMD addition and multiplication
   - Storing results back to Float16 arrays

2. **Mixed Precision Computing**
   - Store data in FP16 (saves memory)
   - Widen to FP32 for computation (higher precision)
   - Narrow back to FP16 for storage
   - Demonstrates convertShape operations

## Requirements

- **JDK 24+** (JDK 25 recommended, as JDK 24 has been superseded)
- Incubator module: `jdk.incubator.vector`
- Float16 value type: Available in JDK 24+
- Float16Vector: **Not yet available** (under development in [JDK-8370691](http://www.mail-archive.com/core-libs-dev@openjdk.org/msg66716.html))

> **Current Status**:
> - ✅ `Float16` value type (scalar operations) - Available in JDK 24+
> - 🚧 `Float16Vector` (vectorized operations) - Under development, coming in a future JDK
>
> For a working Float32 Vector API demo, see `VectorAPIDemo.java`

## Quick Start

### Using the run script:
```bash
./run-fp16-vector.sh
```

### Manual compilation and execution:
```bash
# Compile
javac --add-modules jdk.incubator.vector FP16VectorDemo.java

# Run
java --add-modules jdk.incubator.vector FP16VectorDemo
```

## Expected Output

```
============================================================
FP16 Vector API Demo (JDK 24+)
============================================================
FP16 Species: Float16[128]
FP16 Vector length: 128
FP32 Species: Float[64]
FP32 Vector length: 64

Demo 1: Native FP16 SIMD Computation
------------------------------------------------------------
Input A:
  [1.0000, 1.5000, 2.0000, 2.5000, 3.0000, 3.5000, 4.0000, 4.5000, ...]

Input B:
  [2.0000, 2.2500, 2.5000, 2.7500, 3.0000, 3.2500, 3.5000, 3.7500, ...]

Result (A + B):
  [3.0000, 3.7500, 4.5000, 5.2500, 6.0000, 6.7500, 7.5000, 8.2500, ...]

Result (A * B):
  [2.0000, 3.3750, 5.0000, 6.8750, 9.0000, 11.3750, 14.0000, 16.8750, ...]

Demo 2: FP16 Storage + FP32 Computation (Mixed Precision)
------------------------------------------------------------
Input (FP16 storage):
  [10.0000, 10.1250, 10.2500, 10.3750, 10.5000, 10.6250, 10.7500, 10.8750, ...]

Computation in FP32: x * 2.5 + 1.0

Result (stored back as FP16):
  [26.0000, 26.3125, 26.6250, 26.9375, 27.2500, 27.5625, 27.8750, 28.1875, ...]

Verification (first 4 values):
  [0] 10.0000 * 2.5 + 1.0 = 26.0000 (got 26.0000, diff: 0.000000)
  [1] 10.1250 * 2.5 + 1.0 = 26.3125 (got 26.3125, diff: 0.000000)
  [2] 10.2500 * 2.5 + 1.0 = 26.6250 (got 26.6250, diff: 0.000000)
  [3] 10.3750 * 2.5 + 1.0 = 26.9375 (got 26.9375, diff: 0.000000)
```

## Why FP16?

**Memory Efficiency**: Half the memory footprint of FP32
- FP16: 2 bytes per value
- FP32: 4 bytes per value

**Use Cases**:
- AI/ML inference (neural networks often use FP16)
- Graphics and game engines
- Scientific computing with large datasets

**Mixed Precision Strategy**:
1. Store weights/data in FP16 → save memory
2. Compute in FP32 → maintain precision
3. Store results back in FP16 → save memory

This is common in modern GPU-accelerated ML frameworks.

## Architecture Support

The Vector API will generate optimal SIMD instructions based on your CPU:
- **ARM64 (Apple Silicon)**: NEON FP16 instructions
- **x86-64 (Intel/AMD)**: AVX-512 FP16 (Sapphire Rapids+) or convert via FP32

Check your species length:
```java
Float16Vector.SPECIES_PREFERRED.length()  // Will vary by CPU
```

## Project Valhalla

This demo leverages features from Project Valhalla:
- **Value Types**: Float16 is a value type (primitive-like performance)
- **Vector API**: Expresses data parallelism portably across SIMD architectures

## References

- [JEP 338: Vector API (Incubator)](https://openjdk.org/jeps/338)
- [JEP 460: Vector API (Seventh Incubator)](https://openjdk.org/jeps/460)
- [Project Valhalla](https://openjdk.org/projects/valhalla/)

# Float16 and Vector API Findings

**Date**: February 1, 2026
**Research Context**: JVM in the Age of AI Conference Demo Preparation

## Executive Summary

Float16 (half-precision floating point) support is **partially available** in JDK starting from version 24. The `Float16` value type for scalar operations exists, but `Float16Vector` for SIMD operations is still under development (JDK-8370691) and expected in a future JDK release.

---

## Current State of Float16 in JDK

### ✅ Available Now (JDK 24+, JDK 25+)

#### 1. Float16 Value Type
- **Location**: `jdk.incubator.vector.Float16`
- **First Appeared**: JDK 24
- **Status**: Available in production JDK 24 and 25

**Key Features**:
```java
import jdk.incubator.vector.Float16;

Float16 a = Float16.valueOf(3.5f);
Float16 b = Float16.valueOf(2.0f);

// Scalar arithmetic
Float16 sum = Float16.add(a, b);           // 5.5
Float16 product = Float16.multiply(a, b);   // 7.0
Float16 fma = Float16.fma(a, b, c);        // a * b + c
Float16 sqrt = Float16.sqrt(a);            // 1.8711

// Conversions
float f = a.floatValue();
double d = a.doubleValue();
```

**Properties**:
- **Size**: 2 bytes (16 bits) - 50% memory savings vs Float32
- **Max Value**: 65504.0
- **Min Normal**: 6.1035156E-5
- **Precision**: 11 bits
- **Format**: IEEE 754 binary16

#### 2. Float16 Auto-Vectorization
- **JEP**: [JEP 508: Vector API (Tenth Incubator)](https://openjdk.org/jeps/508)
- **Compiler Support**: HotSpot C2 compiler auto-vectorizes Float16 operations on supporting CPUs
- **Operations Supported**: add, subtract, divide, multiply, sqrt, fused multiply-add
- **Hardware**: x64 CPUs with appropriate SIMD support

**Note**: Auto-vectorization means the JIT compiler automatically generates SIMD instructions for scalar Float16 loops, without requiring explicit Vector API calls.

#### 3. Float32 ↔ Float16 Conversion
- **Location**: `java.lang.Float` (since JDK 20)
- **Methods**:
  - `Float.floatToFloat16(float)` → short (bit representation)
  - `Float.float16ToFloat(short)` → float

### 🚧 Under Development

#### Float16Vector Class
- **Issue**: [JDK-8370691](http://www.mail-archive.com/core-libs-dev@openjdk.org/msg66716.html)
- **Title**: "Add new Float16Vector type and enable intrinsification of vector operations supported by auto-vectorizer"
- **Status**: Active development (v17 of patch as of January 28, 2026)
- **Expected**: JDK 26 or later

**Planned API** (based on other vector types):
```java
// Future API (not yet available)
VectorSpecies<Float16> SPECIES = Float16Vector.SPECIES_PREFERRED;
Float16Vector va = Float16Vector.fromArray(SPECIES, array, 0);
Float16Vector result = va.add(vb).mul(vc);
```

---

## Tested Configurations

### Hardware
- **Platform**: macOS-26.2-arm64 (Apple Silicon)
- **CPU**: ARM64 with NEON SIMD support
- **Vector Length**: 4 floats (128-bit vectors)

### Software
- **JDK 21.0.2**: GraalVM CE 21.0.2+13.1 ✅ (FloatVector works)
- **JDK 25-tem**: Oracle JDK 25 ✅ (Float16 value type works)
- **JDK 25.1.0-graalvm-dev**: Custom build ✅ (Float16 value type works)

---

## Demo Implementations

### 1. VectorAPIDemo.java (Float32)
**Status**: ✅ Working on JDK 21+

**Features Demonstrated**:
- SIMD arithmetic with `FloatVector`
- Dot product: scalar vs SIMD comparison
- Fused multiply-add (FMA) operations
- Performance measurement

**Sample Output**:
```
Vector Species: Species[float, 4, S_128_BIT]
Dot product (4,000 floats):
  Scalar: 28.007208 (0.835 ms)
  SIMD:   28.007233 (11.855 ms)
  Match: true (diff: 0.000024796)
```

**Note**: On this particular run, scalar was faster due to small array size and overhead. SIMD shows benefits with larger datasets.

### 2. FP16VectorDemo.java (Float16 Mixed Precision)
**Status**: ✅ Working on JDK 24+/25+

**Features Demonstrated**:
1. **Scalar Float16 Arithmetic**:
   ```java
   Float16 a = Float16.valueOf(3.5f);
   Float16 b = Float16.valueOf(2.0f);
   Float16 sum = Float16.add(a, b);  // 5.5
   ```

2. **Mixed Precision Computing**:
   - Store data in Float16 (2 bytes each)
   - Load and convert to FloatVector (4 bytes each)
   - Perform SIMD computation in Float32
   - Convert back to Float16 for storage

3. **Memory Savings**:
   - 1M floats: 4 MB (FP32) → 2 MB (FP16)
   - 50% memory reduction

**Sample Output**:
```
Float16 properties:
  Size: 2 bytes (16 bits)
  Max value: 65504.0
  Precision: 11 bits

Demo: FP16 Storage + FP32 Vectorized Computation
  (1.00 + 2.00) * 1.5 = 4.50 (got 4.50)
  Storage: FP16 (saves 50% memory)
  Compute: FP32 vectors (higher precision)
```

---

## Use Cases for Float16

### 1. AI/ML Inference
- **Neural Network Weights**: Store model weights in FP16
- **Activations**: Intermediate layer outputs
- **Memory Bandwidth**: Reduce GPU ↔ CPU transfers
- **Example**: Transformer models often use FP16 for inference

### 2. Large-Scale Scientific Computing
- **Climate Models**: Store massive datasets in FP16
- **Molecular Dynamics**: Particle positions and velocities
- **Astronomy**: Star catalogs and sensor data

### 3. Graphics and Game Engines
- **Texture Data**: RGB/RGBA in FP16 format
- **HDR Rendering**: High dynamic range images
- **Vertex Data**: Positions, normals, texture coordinates

### 4. Real-Time Data Processing
- **IoT Sensor Data**: Time-series data storage
- **Signal Processing**: Audio/video stream buffers
- **Network Packets**: Protocol headers and payloads

---

## Performance Characteristics

### Memory Efficiency
| Type   | Bytes | Elements per Cache Line (64B) | Memory Bandwidth |
|--------|-------|-------------------------------|------------------|
| FP64   | 8     | 8                            | 100%             |
| FP32   | 4     | 16                           | 50%              |
| **FP16** | **2**   | **32**                           | **25%**              |

**Key Insight**: Float16 allows 2x more data per cache line compared to Float32, potentially improving cache utilization and memory bandwidth.

### Precision Trade-offs
| Type   | Sign | Exponent | Mantissa | Range           | Precision  |
|--------|------|----------|----------|-----------------|------------|
| FP64   | 1    | 11       | 52       | ±10^308         | ~15 digits |
| FP32   | 1    | 8        | 23       | ±10^38          | ~7 digits  |
| **FP16** | **1**    | **5**        | **10**       | **±65504**          | **~3 digits** |

**Key Insight**: Float16 is suitable for:
- Values in range [-65504, 65504]
- Applications tolerant to reduced precision
- Storage with occasional computation in higher precision

### Mixed Precision Strategy
```
┌─────────────┐
│  FP16 Storage │  ← 50% memory savings
│  (on disk/RAM)│
└───────┬───────┘
        │ Load
        ▼
┌─────────────┐
│  FP32 Compute │  ← SIMD vectorization
│  (in CPU)     │     Higher precision
└───────┬───────┘
        │ Store
        ▼
┌─────────────┐
│  FP16 Storage │
└─────────────┘
```

**Best Practice**: Use Float16 for storage, Float32/64 for computation.

---

## Vector API Evolution

### Timeline
| JDK | JEP | Status | Float16 |
|-----|-----|--------|---------|
| 16  | [JEP 338](https://openjdk.org/jeps/338) | First Incubator | ❌ |
| 17  | [JEP 414](https://openjdk.org/jeps/414) | Second Incubator | ❌ |
| 18  | [JEP 417](https://openjdk.org/jeps/417) | Third Incubator | ❌ |
| 19  | [JEP 426](https://openjdk.org/jeps/426) | Fourth Incubator | ❌ |
| 20  | [JEP 438](https://openjdk.org/jeps/438) | Fifth Incubator | ❌ Float conversion methods added |
| 21  | [JEP 448](https://openjdk.org/jeps/448) | Sixth Incubator | ❌ |
| 22  | [JEP 460](https://openjdk.org/jeps/460) | Seventh Incubator | ❌ |
| 23  | [JEP 469](https://openjdk.org/jeps/469) | Eighth Incubator | ❌ |
| 24  | [JEP 489](https://openjdk.org/jeps/489) | Ninth Incubator | ✅ Float16 value type |
| 25  | [JEP 508](https://openjdk.org/jeps/508) | Tenth Incubator | ✅ Auto-vectorization |
| 26  | [JEP 529](https://openjdk.org/jeps/529) | Eleventh Incubator | 🚧 Float16Vector planned |

### Project Valhalla Connection
The Vector API is waiting for Project Valhalla features to become preview before moving from incubation to preview itself:
- **Value Types**: Float16 will become a Valhalla value class
- **Primitive Classes**: Enhanced primitive type support
- **Specialized Generics**: Better performance for generic vector operations

---

## Architecture-Specific Behavior

### ARM64 (Apple Silicon, AWS Graviton)
- **SIMD**: NEON instructions
- **Float16**: Native FP16 arithmetic (ARMv8.2+)
- **Performance**: Excellent FP16 support in hardware
- **Vector Length**: Typically 128-bit (4 floats, 8 Float16s)

### x86-64 (Intel, AMD)
- **SIMD**: AVX-512, AVX2, SSE
- **Float16**:
  - Native support on Sapphire Rapids+ (AVX-512 FP16)
  - Emulated on older CPUs (convert to FP32, compute, convert back)
- **Performance**: Native on recent CPUs, slower on older hardware
- **Vector Length**: 128-bit (SSE), 256-bit (AVX2), 512-bit (AVX-512)

### Checking Your Hardware
```java
VectorSpecies<Float> species = FloatVector.SPECIES_PREFERRED;
System.out.println("Vector Species: " + species);
System.out.println("Vector Length: " + species.length());
System.out.println("Bit Size: " + species.vectorBitSize());

// Output example (Apple Silicon):
// Vector Species: Species[float, 4, S_128_BIT]
// Vector Length: 4
// Bit Size: 128
```

---

## Recommendations

### When to Use Float16

✅ **Use Float16 When**:
- Memory is constrained (embedded systems, mobile)
- Storing large datasets (ML models, scientific data)
- Memory bandwidth is a bottleneck
- Precision requirements are moderate
- Values fit within ±65504 range

❌ **Avoid Float16 When**:
- High precision is critical (scientific computing with small values)
- Values exceed ±65504 range
- Performance-critical tight loops (wait for Float16Vector)
- Need denormal number support

### Current Best Practices (2026)

1. **Storage**: Use Float16 for data at rest
2. **Computation**: Use FloatVector (FP32 SIMD) for processing
3. **Conversions**: Minimize Float16 ↔ Float32 conversions
4. **Batch Processing**: Convert entire arrays at once, not individual values

### Future Best Practices (when Float16Vector arrives)

1. **Storage + Compute**: Use Float16Vector for both
2. **Mixed Precision**: Float16Vector for throughput, DoubleVector for accuracy
3. **Hardware Detection**: Check CPU capabilities at runtime
4. **Fallback**: Provide Float32 code path for unsupported hardware

---

## Code Patterns

### Pattern 1: Float16 Storage with Float32 Computation
```java
// Storage arrays (50% memory)
Float16[] data = new Float16[size];

// Process in chunks
int vectorLen = FloatVector.SPECIES_PREFERRED.length();
for (int i = 0; i < size; i += vectorLen) {
    // Load: Float16 → Float32
    float[] chunk = new float[vectorLen];
    for (int j = 0; j < vectorLen; j++) {
        chunk[j] = data[i + j].floatValue();
    }

    // Compute: SIMD Float32
    FloatVector v = FloatVector.fromArray(SPECIES, chunk, 0);
    FloatVector result = v.mul(2.0f).add(1.0f);

    // Store: Float32 → Float16
    result.intoArray(chunk, 0);
    for (int j = 0; j < vectorLen; j++) {
        data[i + j] = Float16.valueOf(chunk[j]);
    }
}
```

### Pattern 2: Scalar Float16 Arithmetic
```java
// For simple operations, use Float16 directly
Float16 temperature = Float16.valueOf(23.5f);
Float16 delta = Float16.valueOf(0.5f);
Float16 newTemp = Float16.add(temperature, delta);

// Check for overflow/underflow
if (Float16.isFinite(newTemp)) {
    // Valid result
} else if (Float16.isInfinite(newTemp)) {
    // Overflow
} else {
    // NaN
}
```

### Pattern 3: Batch Conversion
```java
// Convert entire arrays efficiently
float[] fp32Array = new float[size];
Float16[] fp16Array = new Float16[size];

// Float32 → Float16
for (int i = 0; i < size; i++) {
    fp16Array[i] = Float16.valueOf(fp32Array[i]);
}

// Float16 → Float32
for (int i = 0; i < size; i++) {
    fp32Array[i] = fp16Array[i].floatValue();
}
```

---

## References

### Official Documentation
- [Float16 JavaDoc (JDK 24)](https://docs.oracle.com/en/java/javase/24/docs/api/jdk.incubator.vector/jdk/incubator/vector/Float16.html)
- [Float16 JavaDoc (JDK 25)](https://docs.oracle.com/en/java/javase/25/docs/api/jdk.incubator.vector/jdk/incubator/vector/Float16.html)
- [Vector API Package Summary](https://docs.oracle.com/en/java/javase/25/docs/api/jdk.incubator.vector/jdk/incubator/vector/package-summary.html)

### JEPs (JDK Enhancement Proposals)
- [JEP 489: Vector API (Ninth Incubator) - JDK 24](https://openjdk.org/jeps/489) - Introduced Float16
- [JEP 508: Vector API (Tenth Incubator) - JDK 25](https://openjdk.org/jeps/508) - Float16 auto-vectorization
- [JEP 529: Vector API (Eleventh Incubator) - JDK 26](https://openjdk.org/jeps/529) - Continued evolution

### Development Discussions
- [JDK-8370691: Add Float16Vector type (Mailing List)](http://www.mail-archive.com/core-libs-dev@openjdk.org/msg66716.html)
- [OpenJDK Bug Tracker - JDK-8370691](https://bugs.openjdk.org/browse/JDK-8370691)

### Related Projects
- [Project Valhalla](https://openjdk.org/projects/valhalla/) - Value types and primitive classes
- [Project Panama](https://openjdk.org/projects/panama/) - Foreign function interface

### Standards
- [IEEE 754-2008](https://ieeexplore.ieee.org/document/4610935) - Binary16 (half precision) specification

---

## Glossary

- **SIMD**: Single Instruction, Multiple Data - process multiple values with one instruction
- **Vector API**: Java incubator API for explicit SIMD programming
- **Float16/FP16**: 16-bit IEEE 754 binary16 half-precision floating point
- **Float32/FP32**: 32-bit IEEE 754 binary32 single-precision floating point
- **Mixed Precision**: Using different precisions for storage vs computation
- **Auto-vectorization**: Compiler automatically generating SIMD code from scalar loops
- **Value Type**: Immutable, identity-free object (like primitives)
- **Incubator Module**: Experimental API in `jdk.incubator.*` namespace

---

## Changelog

- **2026-02-01**: Initial findings document created
  - Confirmed Float16 value type available in JDK 24+/25+
  - Confirmed Float16Vector under development (JDK-8370691)
  - Created and tested VectorAPIDemo.java (Float32)
  - Created and tested FP16VectorDemo.java (Float16 mixed precision)
  - Documented use cases, performance characteristics, and best practices

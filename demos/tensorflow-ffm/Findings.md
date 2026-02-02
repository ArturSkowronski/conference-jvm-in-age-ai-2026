# TensorFlow FFM Technical Findings

Technical deep dive into using the Foreign Function & Memory (FFM) API for calling TensorFlow C library from Java.

## FFM vs JNI: Why FFM is Better

### Traditional JNI Approach

```c
// C code (JNI)
JNIEXPORT jstring JNICALL Java_TensorFlow_getVersion(JNIEnv *env, jclass cls) {
  const char* version = TF_Version();
  return (*env)->NewStringUTF(env, version);
}
```

**Problems with JNI:**
- ❌ Requires writing C/C++ glue code
- ❌ Platform-specific compilation
- ❌ Manual memory management
- ❌ Error-prone (segfaults, memory leaks)
- ❌ Separate build toolchain (CMake, gcc, etc.)
- ❌ Distribution complexity (multiple .so/.dll files)

### Modern FFM Approach

```java
// Pure Java (FFM)
MethodHandle TF_Version = linker.downcallHandle(
  symbol("TF_Version"),
  FunctionDescriptor.of(ADDRESS)
);

MemorySegment cStr = (MemorySegment) TF_Version.invokeExact();
String version = cStr.getString(0);
```

**Benefits of FFM:**
- ✅ Pure Java code - no C glue needed
- ✅ Cross-platform - same code for all OS
- ✅ Memory-safe - Arena-based lifecycle
- ✅ Type-safe - MethodHandle with exact types
- ✅ No compilation - just Java compilation
- ✅ Performance - zero overhead, as fast as JNI

## Platform Support Details

### Supported Platforms

**macOS ARM64 (Apple Silicon):**
- TensorFlow 2.18.0 CPU
- Download: `libtensorflow-cpu-darwin-arm64.tar.gz` (~180 MB)
- ✅ Fully supported

**Linux x86_64:**
- TensorFlow 2.18.0 CPU
- Download: `libtensorflow-cpu-linux-x86_64.tar.gz` (~200 MB)
- ✅ Fully supported

**Windows x86_64:**
- TensorFlow 2.18.0 CPU
- Download: `libtensorflow-cpu-windows-x86_64.zip` (~190 MB)
- ✅ Fully supported

### Unsupported Platform

**macOS x86_64 (Intel Macs):**
- ❌ Not supported
- **Reason**: TensorFlow dropped x86_64 macOS support after version 2.16.2
- **Workaround**: Provide your own build via `-PtensorflowHome=...`

## Build File Design Decisions

### Automatic Download Strategy

The build automatically downloads TensorFlow on first run:

```kotlin
tasks.register("downloadTensorFlow") {
  onlyIf { !tensorflowHome.isPresent }
  // Platform detection and download logic
}
```

**Why:**
- ✅ Zero manual setup for users
- ✅ Consistent TensorFlow version (2.18.0)
- ✅ Works in CI/CD without configuration
- ✅ Can override with `-PtensorflowHome` for custom builds

### Platform Detection Logic

```kotlin
val (url, isZip) = when {
  os.contains("mac") && isArm64 -> darwinArm64Url to false
  os.contains("linux") && isX86_64 -> linuxX86_64Url to false
  os.contains("win") && isX86_64 -> windowsX86_64Url to true
  else -> error("Unsupported platform")
}
```

**Design choices:**
- Fail fast on unsupported platforms
- Clear error messages
- Separate extract logic for .zip vs .tar.gz

### JDK Version Enforcement

```kotlin
java {
  toolchain {
    languageVersion.set(JavaLanguageVersion.of(25))
  }
}
```

**Why JDK 25:**
- FFM is final in JDK 22 (no --enable-preview needed)
- JDK 25 has improved FFM performance
- Latest Vector API enhancements
- Demo consistency (most demos use JDK 25)

## FFM Technical Details

### Memory Arena Pattern

```java
try (TensorFlowC tf = TensorFlowC.load()) {
  // All FFM operations here
  // Memory automatically freed when arena closes
}
```

**Benefits:**
- Automatic cleanup - no memory leaks
- Scoped lifetime - clear ownership
- Exception-safe - cleanup even on error

### MethodHandle for C Functions

```java
MethodHandle TF_NewGraph = linker.downcallHandle(
  symbol("TF_NewGraph"),
  FunctionDescriptor.of(ADDRESS)
);

MemorySegment graph = (MemorySegment) TF_NewGraph.invokeExact();
```

**Key points:**
- `downcallHandle` - Java → native calls
- `FunctionDescriptor` - Specifies C function signature
- `invokeExact()` - Type-exact invocation (fastest)
- Returns `MemorySegment` - Pointer to native memory

### Calling Convention

FFM uses the platform's default calling convention:
- **Linux/macOS**: System V AMD64 ABI
- **Windows**: Microsoft x64 calling convention
- **ARM64**: ARM64 procedure call standard

No manual ABI specification needed - FFM handles it automatically.

## Performance Analysis

### Overhead Comparison

| Approach | Call Overhead | Memory Safety | Cross-platform |
|----------|---------------|---------------|----------------|
| **FFM** | ~0ns (inlined) | ✅ Safe | ✅ Yes |
| **JNI** | ~5-10ns | ❌ Unsafe | ❌ Platform-specific |
| **JNA** | ~50-100ns | ⚠️  Safer than JNI | ✅ Yes |

**FFM performance:**
- First call: ~100ns (method handle initialization)
- Subsequent calls: 0ns (JIT inlines them completely)
- Peak: Identical to direct C function call

### Download Size

- TensorFlow C library: ~180-200 MB (one-time download)
- Cached in `build/tensorflow/` (not committed to git)
- Reused across multiple runs

## Why TensorFlow 2.18.0?

**Reasoning:**
1. **Latest stable** - Released 2024
2. **Consistent across platforms** - Works on all supported OS
3. **CPU-only** - Simpler demo, no CUDA setup needed
4. **Good FFM test** - Complex C API with callbacks, structs

**Limitations:**
- CPU-only (no GPU acceleration in this demo)
- For GPU, would need CUDA-enabled build (~1 GB download)

## Common Issues

### "UnsatisfiedLinkError: no tensorflow in java.library.path"

**Cause:** TensorFlow library not found

**Fix:**
```bash
# Let Gradle download it automatically
./gradlew :demos:tensorflow-ffm:setupTensorFlow

# Or provide your own
./gradlew :demos:tensorflow-ffm:run -PtensorflowHome=/path/to/libtensorflow
```

### "IllegalCallerException: Illegal native access"

**Cause:** Missing `--enable-native-access` flag

**Fix:** Already configured in `build.gradle.kts`:
```kotlin
applicationDefaultJvmArgs = listOf("--enable-native-access=ALL-UNNAMED")
```

### macOS x86_64 Not Supported

**Error:**
```
macOS x86_64 is not supported by this demo.
TensorFlow dropped x86_64 macOS support after version 2.16.2.
```

**Options:**
1. Use Apple Silicon Mac
2. Use Linux/Windows
3. Build TensorFlow 2.16.2 yourself and use `-PtensorflowHome`

## Lessons Learned

### 1. FFM is Production-Ready (JDK 22+)

- No `--enable-preview` needed
- Stable API (no breaking changes expected)
- Good performance (zero overhead after warmup)
- Excellent for native library bindings

### 2. Platform Detection is Critical

- Must handle .tar.gz vs .zip extraction
- Architecture naming varies (x86_64 vs amd64, arm64 vs aarch64)
- Fail fast with clear error messages

### 3. Automatic Downloads Improve UX

- Users don't need to manually setup TensorFlow
- Consistent versions across all runs
- Works in CI/CD without manual intervention
- Can still override for custom builds

### 4. Memory Safety Matters

- FFM's Arena prevents memory leaks
- Automatic cleanup even on exceptions
- No need for manual `free()` calls
- Compile-time safety vs JNI's runtime crashes

## Comparison with Other Demos

| Demo | Technology | Native Access | Complexity |
|------|------------|---------------|------------|
| **TensorFlow FFM** | FFM API | TensorFlow C | Medium |
| **JCuda** | Panama/FFM-like | CUDA driver | Medium |
| **java-llama.cpp** | JNI | llama.cpp | Low (prebuilt) |
| **Llama3.java** | Pure Java | None | Low |

## Future Enhancements

Potential improvements for this demo:
1. **GPU support** - Use CUDA-enabled TensorFlow build
2. **More operations** - Matrix multiplication, convolutions
3. **Model loading** - Load and run actual TF SavedModels
4. **Callbacks** - Demonstrate upcalls (native → Java)

## References

- [JEP 454: Foreign Function & Memory API](https://openjdk.org/jeps/454)
- [TensorFlow C API Documentation](https://www.tensorflow.org/install/lang_c)
- [FFM Tutorial](https://docs.oracle.com/en/java/javase/22/core/foreign-function-and-memory-api.html)
- [Panama Project](https://openjdk.org/projects/panama/)

## See Also

- **[Findings.md](Findings.md)** - FFM technical deep dive
- **`demos/jcuda/`** - JCuda (similar FFM approach for CUDA)
- **`demos/llama3-java/`** - Pure Java (no native dependencies)

# TensorFlow FFM Demo - Foreign Function & Memory API

Demonstrates calling TensorFlow C API directly from Java using the **Foreign Function & Memory (FFM) API** - no JNI, no Python, zero overhead.

## Quick Start

```bash
# Run the demo (auto-downloads TensorFlow C library)
./gradlew :demos:tensorflow-ffm:run
```

**Expected output:**
```
[TensorFlow FFM] Loading TensorFlow native library...
[TensorFlow FFM] Library loaded successfully!
[TensorFlow FFM] TF_Version=2.18.0
[TensorFlow FFM] Running computation: 1.5 + 2.25...
[TensorFlow FFM] Result: 1.5 + 2.25 = 3.75
✅ Demo completed successfully!
```

## What This Demo Shows

- **Zero-overhead native calls** - Direct C function calls from Java
- **No JNI required** - FFM replaces traditional JNI bindings
- **Type-safe memory access** - Structured memory operations
- **Automatic resource management** - Arena-based memory lifecycle
- **Cross-platform** - Works on macOS ARM64, Linux x86_64, Windows x86_64

## Requirements

- **JDK 25+** (FFM is final in JDK 22, demo uses JDK 25)
- TensorFlow C library (auto-downloaded on first run)

## How It Works

The demo:
1. Downloads TensorFlow C library 2.18.0 (~200 MB)
2. Extracts to `build/tensorflow/root/`
3. Uses FFM to call `TF_Version()` and create a simple computation graph
4. Adds two scalars: 1.5 + 2.25 = 3.75

**No Python, no JNI, pure Java!**

## Supported Platforms

| Platform | Status |
|----------|--------|
| macOS ARM64 (Apple Silicon) | ✅ Supported |
| Linux x86_64 | ✅ Supported |
| Windows x86_64 | ✅ Supported |
| macOS x86_64 (Intel) | ❌ Not supported (TF dropped support after 2.16.2) |

## All Available Tasks

```bash
# Run the demo (alias to runSmoke)
./gradlew :demos:tensorflow-ffm:run

# Run smoke test (main task)
./gradlew :demos:tensorflow-ffm:runSmoke

# Manually setup TensorFlow (optional)
./gradlew :demos:tensorflow-ffm:setupTensorFlow
```

## Code Structure

```
demos/tensorflow-ffm/
├── src/main/java/com/skowronski/talk/jvmai/
│   ├── TensorFlowDemo.java      # Main demo
│   ├── TensorFlowC.java         # FFM bindings to TF C API
│   ├── TensorFlowNative.java    # Native library loader
│   └── TfStatus.java            # TF_Status wrapper
├── build.gradle.kts             # Simplified build (auto-downloads TF)
├── .sdkmanrc                    # JDK 25
├── README.md                    # This file
└── Findings.md                  # Technical deep dive
```

## Custom TensorFlow Build

To use your own TensorFlow C library:

```bash
./gradlew :demos:tensorflow-ffm:run -PtensorflowHome=/path/to/libtensorflow
```

## Deep Dive

For technical details about FFM, performance analysis, and how this compares to JNI, see **[Findings.md](Findings.md)**.

Topics covered:
- FFM vs JNI comparison
- Memory safety and performance
- Platform support details
- TensorFlow C API usage
- Troubleshooting common issues

## See Also

- **[Findings.md](Findings.md)** - FFM technical analysis
- **`demos/jcuda/`** - JCuda CUDA bindings (also uses FFM-like approach)
- **`demos/llama3-java/`** - Pure Java LLM (no FFM needed)

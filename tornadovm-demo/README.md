# Demo: TornadoVM (JVM → GPU/CPU acceleration)

This is a small, self-contained demo for the talk: the same computation run as plain Java (baseline) and as a TornadoVM task (TaskGraph).

## Requirements

- **Baseline**: any JDK 17+.
- **TornadoVM**: JDK 21 + TornadoVM SDK + working OpenCL/CUDA drivers.

### Supported JDK 21 Distributions

TornadoVM 2.2.0 supports multiple JDK 21 distributions:
- GraalVM CE 21 (recommended)
- Eclipse Temurin 21
- Amazon Corretto 21
- Azul Zulu 21
- Microsoft OpenJDK 21
- Red Hat Mandrel 21

**JVMCI Compatibility Note**: TornadoVM uses the JVM Compiler Interface (JVMCI) which may have minor version mismatches with some JDKs. If you encounter `JVMCIError: VM config values missing`, set:
```bash
export JVMCI_CONFIG_CHECK=ignore
```

Quick device check (if you have `tornado` in `PATH`):
```bash
tornado --devices
```

## Running

### 1) Baseline (without TornadoVM)
```bash
./scripts/run-baseline.sh --size 10000000 --iters 10
```

### 2) TornadoVM
Set `TORNADOVM_HOME` to your TornadoVM installation directory (optional - the script auto-downloads TornadoVM SDK if not set):
```bash
export TORNADOVM_HOME=~/path/to/tornadovm
./scripts/run-tornado.sh --size 10000000 --iters 10
```

### 3) GPULlama3 (real LLM inference on GPU)

This uses the upstream project `beehive-lab/GPULlama3.java` (cloned + built automatically into `tornadovm-demo/build/`).

Requirements:
- TornadoVM installed (JDK 21), with working OpenCL/CUDA drivers.
- Python 3 (to run the upstream `llama-tornado` launcher).
- A `.gguf` model file in **FP16 format** (Q4_K_M and other quantized formats not supported).

Model setup (example using Llama 3.2 1B):
```bash
mkdir -p ~/.tornadovm/models
curl -L -o ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf \
  "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"
```

Run:
```bash
export TORNADOVM_HOME=~/path/to/tornadovm
export JVMCI_CONFIG_CHECK=ignore  # Workaround for JVMCI compatibility
./scripts/run-gpullama3.sh --model ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf --prompt "tell me a joke"
```

## What this demo shows

- A Java kernel + the `@Parallel` annotation.
- Building a `TaskGraph`, taking a snapshot, and running a `TornadoExecutionPlan`.
- Timing difference between baseline and TornadoVM execution (depends on device/drivers).

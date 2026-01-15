# Demo: TornadoVM (JVM → GPU/CPU acceleration)

This is a small, self-contained demo for the talk: the same computation run as plain Java (baseline) and as a TornadoVM task (TaskGraph).

## Requirements

- **Baseline**: any JDK 17+.
- **TornadoVM**: TornadoVM installed (e.g. via SDKMAN) + working OpenCL/CUDA drivers.

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
- A local `.gguf` model file (not bundled).

Run:
```bash
export TORNADOVM_HOME=~/path/to/tornadovm
./scripts/run-gpullama3.sh --model /path/to/model.gguf --prompt "tell me a joke"
```

## What this demo shows

- A Java kernel + the `@Parallel` annotation.
- Building a `TaskGraph`, taking a snapshot, and running a `TornadoExecutionPlan`.
- Timing difference between baseline and TornadoVM execution (depends on device/drivers).

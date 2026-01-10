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
Set `TORNADO_SDK` to your TornadoVM installation directory (optional if you're already using TornadoVM as `JAVA_HOME`):
```bash
export TORNADO_SDK=~/path/to/tornadovm
./scripts/run-tornado.sh --size 10000000 --iters 10
```

## What this demo shows

- A Java kernel + the `@Parallel` annotation.
- Building a `TaskGraph`, taking a snapshot, and running a `TornadoExecutionPlan`.
- Timing difference between baseline and TornadoVM execution (depends on device/drivers).

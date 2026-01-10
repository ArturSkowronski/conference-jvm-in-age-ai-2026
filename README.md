# conference-jvm-in-age-ai-2026

## Dema

- `tornadovm-demo/` – proste demo TornadoVM (baseline vs TaskGraph)
- `demos/jcuda/` — JCuda support demo (CUDA driver + device info)

Demo materials:
- `demos/graalpy/` — GraalPy quickstart + Java interop demos
Java playground scaffold intended for quick experiments with different JVMs and JDK versions (Temurin, GraalVM, TornadoVM, etc.).

## Prereqs

- SDKMAN!: `https://sdkman.io`

## Setup (SDKMAN!)

This repo includes a `.sdkmanrc`. In the repo root:

- Install declared candidates: `sdk env install`
- Use the declared versions in this shell: `sdk env`

## Run

- `gradle run`

## Switching JDKs

- Change the `java=` entry in `.sdkmanrc`, then `sdk env install && sdk env`
- Or override Gradle’s toolchain version: `gradle run -PjavaVersion=23`

## TensorFlow (FFM, no JNI / no Python)

This repo includes a small demo of calling the TensorFlow C API from Java (using the Foreign Function & Memory API).

Run:

- `gradle runTensorFlow`
- Or with your own TensorFlow build: `gradle runTensorFlow -PtensorflowHome=/path/to/unpacked/libtensorflow`

Notes:
- The build downloads the TensorFlow C library into `build/tensorflow/` automatically.
- Prebuilt TensorFlow C libraries here are x86_64 only; on Apple Silicon run an x86_64 JDK (Rosetta) or pass `-PtensorflowHome=/path/to/unpacked/libtensorflow`.

## GraalVM / Native Image

- Install GraalVM via SDKMAN! (set `java=` to a GraalVM distribution) and re-run `sdk env`
- Build a native binary: `gradle nativeCompile`

## GraalPy (notes)

If you install a GraalVM distribution, you can add Python with `gu` and use `graalpy` for experiments:

- `gu install python`
- `graalpy --version`

## TornadoVM (notes)

TornadoVM requires a compatible JDK + its runtime; treat it as a separate SDKMAN “java” candidate and point `.sdkmanrc` at it when needed.

# Babylon Workflow Summary

This document outlines the steps taken to build the OpenJDK Babylon project, verify Code Reflection features, build the HAT (Heterogeneous Accelerator Toolkit), and integrate a demo into the conference materials.

## 1. Environment & JDK Build

**Objective:** Build the Babylon JDK (JDK 27-internal) from source on macOS AArch64.

### Prerequisites Found/Installed
- **Boot JDK:** JDK 25 (Temurin) installed via SDKMAN (`sdk use java 25-tem`).
- **Build Tools:** `autoconf`, `cmake`, `freetype` (bundled).
- **JTReg:** Version 7.3 was insufficient. Downloaded and configured **JTReg 8.1** manually.

### Build Steps
1.  **Checkout Branch:**
    ```bash
    git checkout code-reflection
    ```
2.  **Configure:**
    ```bash
    bash configure \
      --with-boot-jdk=$HOME/.sdkman/candidates/java/25-tem \
      --with-jtreg=$HOME/.gemini/tmp/.../jtreg
    ```
3.  **Build Images:**
    ```bash
    make clean && make images
    ```
    *Result:* JDK image created at `build/macosx-aarch64-server-release/images/jdk`.

## 2. Testing Code Reflection

**Objective:** Verify the core Code Reflection API (`jdk.incubator.code`).

### Execution
*   **Test Target:** `test/jdk/java/lang/reflect/code`
*   **Command:**
    ```bash
    make test TEST=test/jdk/java/lang/reflect/code
    ```
*   **Results:**
    *   **Passed:** 97 tests.
    *   **Failed:** 0.

## 3. HAT (Heterogeneous Accelerator Toolkit)

**Objective:** Build HAT and run the Matrix Multiplication example on the GPU (OpenCL).

### Setup
1.  **Jextract:** HAT requires `jextract`.
    *   Installed via SDKMAN: `sdk install jextract 22.ea.6`.
2.  **Environment:**
    *   Sourced `hat/env.bash` to setup `JAVA_HOME` (pointing to the Babylon build) and `JEXTRACT_HOME`.

### Build
```bash
cd hat
source ./env.bash
java @hat/bld
```

### Running Examples (MatMul)
*   **Command:**
    ```bash
    java @hat/run ffi-opencl matmul
    ```
*   **Results:**
    *   **Naive 2D:** ~42ms/iter.
    *   **2D Tiling (Shared Memory):** ~7ms/iter (Verified correct results).

## 4. Conference Demo Integration

**Objective:** specific `HAT` demo to `~/Priv/talks/conference-jvm-in-age-ai-2026`.

### Actions Taken
1.  **Source Code:**
    *   Created `demos/babylon/demo/babylon/HatMatMul.java`.
    *   Ported code from `hat/examples/matmul/Main.java`, adapted package name to `demo.babylon`.
2.  **Execution Script:**
    *   Updated `demos/babylon/run-babylon.sh`.
    *   Added logic to setup classpath for `hat-core`, `hat-optkl`, and `hat-backend-ffi-opencl`.
    *   Added `-Djava.library.path` pointing to HAT build output (for `libopencl_backend.dylib`).
3.  **Documentation:**
    *   Updated `Talk.md` with **Demo 8: Project Babylon & HAT**.
    *   Added description of Code Reflection, HAT, and expected output showing GPU acceleration.

## 5. Summary of Artifacts

*   **Babylon JDK:** `~/GitHub/babylon/build/macosx-aarch64-server-release/jdk`
*   **HAT Build:** `~/GitHub/babylon/hat/build`
*   **Demo Script:** `~/Priv/talks/conference-jvm-in-age-ai-2026/demos/babylon/run-babylon.sh`
*   **Demo Source:** `~/Priv/talks/conference-jvm-in-age-ai-2026/demos/babylon/demo/babylon/HatMatMul.java`

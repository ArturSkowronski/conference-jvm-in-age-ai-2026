# =============================================================================
# JVM in the Age of AI — GCP GPU Benchmark Image
#
# Multi-stage build:
#   1. Builder: downloads JDKs + TornadoVM SDK
#   2. Runtime: installs system deps, copies everything, pre-warms Gradle
#
# Usage:
#   docker build -t jvm-ai-benchmark -f docker/Dockerfile .
#   docker run --rm --gpus all -v ~/models:/models -v ~/results:/results jvm-ai-benchmark
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Download JDKs and TornadoVM SDK
# ---------------------------------------------------------------------------
FROM alpine:3.20 AS builder

RUN apk add --no-cache curl tar

WORKDIR /downloads

# --- GraalVM CE 21 (for TornadoVM + JDK 21 benchmark) ---
RUN curl -fL -o graalvm-21.tar.gz \
      "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_linux-x64_bin.tar.gz" && \
    mkdir -p /opt/jdk/graalvm-21 && \
    tar -xzf graalvm-21.tar.gz --strip-components=1 -C /opt/jdk/graalvm-21 && \
    rm graalvm-21.tar.gz

# --- Temurin JDK 25 (main benchmark JDK) ---
RUN curl -fL -o jdk-25.tar.gz \
      "https://api.adoptium.net/v3/binary/latest/25/ea/linux/x64/jdk/hotspot/normal/eclipse" && \
    mkdir -p /opt/jdk/jdk-25 && \
    tar -xzf jdk-25.tar.gz --strip-components=1 -C /opt/jdk/jdk-25 && \
    rm jdk-25.tar.gz

# --- TornadoVM SDK 2.2.0 OpenCL (required by GPULlama3.java) ---
RUN curl -fL -o tornadovm.tar.gz \
      "https://github.com/beehive-lab/TornadoVM/releases/download/v2.2.0/tornadovm-2.2.0-opencl-linux-amd64.tar.gz" && \
    mkdir -p /opt/tornadovm && \
    tar -xzf tornadovm.tar.gz -C /opt/tornadovm && \
    rm tornadovm.tar.gz

# ---------------------------------------------------------------------------
# Stage 2: Runtime image
# ---------------------------------------------------------------------------
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Fix GPG keyring for cross-platform builds (ARM64 QEMU can't read old keyring format)
RUN rm -f /etc/apt/trusted.gpg.d/ubuntu-keyring-2012-cdimage.gpg && \
    apt-get update 2>/dev/null || true && \
    apt-get install -y --allow-unauthenticated ca-certificates gnupg && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C && \
    apt-get update && apt-get install -y --no-install-recommends \
      git curl wget unzip bc \
      build-essential software-properties-common cmake \
      maven \
      python3 python3-pip python3-venv \
      ocl-icd-libopencl1 opencl-headers clinfo \
    && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update \
    && apt-get install -y --no-install-recommends gcc-13 g++-13 libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Copy JDKs and TornadoVM from builder
COPY --from=builder /opt/jdk/graalvm-21  /opt/jdk/graalvm-21
COPY --from=builder /opt/jdk/jdk-25      /opt/jdk/jdk-25
COPY --from=builder /opt/tornadovm       /opt/tornadovm

# Environment
ENV JAVA_HOME=/opt/jdk/jdk-25
ENV JDK_21=/opt/jdk/graalvm-21
ENV JDK_25_TEM=/opt/jdk/jdk-25
ENV JDK_25_GRAAL=""
ENV TORNADOVM_HOME=/opt/tornadovm/tornadovm-2.2.0-opencl
ENV TORNADOVM_BACKEND=opencl
ENV JVMCI_CONFIG_CHECK=ignore
ENV MODEL_PATH=/models/Llama-3.2-1B-Instruct-f16.gguf
ENV LLAMA_MODEL_DIR=/models
ENV PATH="/opt/jdk/jdk-25/bin:${PATH}"

# OpenCL ICD configuration for NVIDIA GPU
RUN mkdir -p /etc/OpenCL/vendors && \
    echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

# Model and results mount points
RUN mkdir -p /models /results

# Copy project source
WORKDIR /workspace
COPY . /workspace/

# Make scripts executable
RUN chmod +x scripts/*.sh demos/*/scripts/*.sh tornadovm-demo/scripts/*.sh docker/entrypoint.sh 2>/dev/null || true
RUN chmod +x gradlew

# Build java-llama.cpp native library with CUDA support
RUN git clone --depth 1 https://github.com/kherud/java-llama.cpp.git /tmp/java-llama-cpp && \
    cd /tmp/java-llama-cpp && \
    mvn compile -q && \
    cmake -B build -DGGML_CUDA=ON && \
    cmake --build build --config Release -j$(nproc) && \
    mkdir -p /opt/jllama-cuda && \
    find /tmp/java-llama-cpp -name "libjllama.so" -exec cp {} /opt/jllama-cuda/ \; && \
    rm -rf /tmp/java-llama-cpp

ENV JLLAMA_CUDA_LIB=/opt/jllama-cuda

# Pre-warm Gradle dependency cache
RUN ./gradlew --no-daemon dependencies || true

# Clone and build GPULlama3 ahead of time
RUN if [ -d "$TORNADOVM_HOME" ]; then \
      export JAVA_HOME=/opt/jdk/graalvm-21 && \
      git clone --depth 1 https://github.com/beehive-lab/GPULlama3.java.git \
        tornadovm-demo/build/gpullama3-src && \
      cd tornadovm-demo/build/gpullama3-src && \
      ./mvnw -q -DskipTests package || true; \
    fi

ENTRYPOINT ["/workspace/docker/entrypoint.sh"]

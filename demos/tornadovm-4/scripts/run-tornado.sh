#!/usr/bin/env bash
set -euo pipefail

# TornadoVM 4.0 Demo Runner
# Automatically downloads TornadoVM 4.0 SDK and runs the GPU-accelerated demo
# Supports Metal backend on macOS (Apple Silicon) and OpenCL/PTX elsewhere

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tornado"
SRC_DIR="$ROOT_DIR/src/tornado/java"

TORNADOVM_VERSION="${TORNADOVM_VERSION:-4.0.0}"
TORNADOVM_JDK="${TORNADOVM_JDK:-jdk21}"
# Backend selection: metal (macOS), opencl, ptx (NVIDIA)
TORNADOVM_BACKEND="${TORNADOVM_BACKEND:-}"
# Device selection for multi-backend builds: 0:0=OpenCL/Metal, 1:0=PTX/CUDA
TORNADO_DEVICE="${TORNADO_DEVICE:-}"

# Detect OS and architecture
detect_platform() {
  local os arch
  case "$(uname -s)" in
    Linux*)  os="linux" ;;
    Darwin*) os="mac" ;;
    *)       echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *)            echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
  echo "${os}-${arch}"
}

# Auto-detect best backend for platform
detect_backend() {
  if [[ -n "$TORNADOVM_BACKEND" ]]; then
    echo "$TORNADOVM_BACKEND"
    return 0
  fi

  local platform
  platform="$(detect_platform)"

  case "$platform" in
    mac-aarch64)
      # Apple Silicon: prefer Metal
      echo "metal"
      ;;
    mac-amd64)
      # Intel Mac: use OpenCL
      echo "opencl"
      ;;
    linux-*)
      # Linux: check for NVIDIA, fallback to OpenCL
      if command -v nvidia-smi &>/dev/null; then
        echo "opencl"  # OpenCL works on NVIDIA too; use TORNADOVM_BACKEND=ptx for PTX
      else
        echo "opencl"
      fi
      ;;
  esac
}

# Download TornadoVM 4.0 SDK if needed
setup_tornadovm() {
  if [[ -n "${TORNADOVM_HOME:-}" && -d "$TORNADOVM_HOME" ]]; then
    echo "Using existing TORNADOVM_HOME: $TORNADOVM_HOME"
    return 0
  fi

  local platform backend
  platform="$(detect_platform)"
  backend="$(detect_backend)"
  local sdk_dir="$ROOT_DIR/build/tornadovm-sdk"
  # Extracted dir may or may not include jdk suffix
  local sdk_path="$sdk_dir/tornadovm-${TORNADOVM_VERSION}-${TORNADOVM_JDK}-${backend}"
  local alt_sdk_path="$sdk_dir/tornadovm-${TORNADOVM_VERSION}-${backend}"

  if [[ -d "$sdk_path" ]]; then
    export TORNADOVM_HOME="$sdk_path"
    echo "Using cached TornadoVM 4.0 SDK: $TORNADOVM_HOME"
    return 0
  fi

  if [[ -d "$alt_sdk_path" ]]; then
    export TORNADOVM_HOME="$alt_sdk_path"
    echo "Using cached TornadoVM 4.0 SDK: $TORNADOVM_HOME"
    return 0
  fi

  local filename="tornadovm-${TORNADOVM_VERSION}-${TORNADOVM_JDK}-${backend}-${platform}.zip"
  local url="https://github.com/beehive-lab/TornadoVM/releases/download/v${TORNADOVM_VERSION}-${TORNADOVM_JDK}/${filename}"

  echo "Downloading TornadoVM 4.0 SDK..."
  echo "  Version: ${TORNADOVM_VERSION}-${TORNADOVM_JDK}"
  echo "  Backend: $backend"
  echo "  URL: $url"
  mkdir -p "$sdk_dir"
  curl -fL "$url" -o "$sdk_dir/$filename"
  unzip -q "$sdk_dir/$filename" -d "$sdk_dir"
  rm -f "$sdk_dir/$filename"

  # Detect actual extracted directory name
  if [[ -d "$sdk_path" ]]; then
    export TORNADOVM_HOME="$sdk_path"
  elif [[ -d "$alt_sdk_path" ]]; then
    export TORNADOVM_HOME="$alt_sdk_path"
  else
    echo "ERROR: Could not find extracted SDK in $sdk_dir" >&2
    ls "$sdk_dir" >&2
    exit 1
  fi
  echo "TornadoVM 4.0 SDK installed: $TORNADOVM_HOME"
}

# Setup Java - JDK 21+ required
setup_java() {
  # Try SDKMAN GraalVM first
  if [[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
    set +u
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    set -u

    # Check for GraalVM CE 21
    local graalvm_path="$HOME/.sdkman/candidates/java/21.0.2-graalce"
    if [[ -d "$graalvm_path" ]]; then
      export JAVA_HOME="$graalvm_path"
      echo "Using SDKMAN GraalVM CE: $JAVA_HOME"
      return 0
    fi
  fi

  # Fallback to JAVA_HOME or system Java
  if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
    echo "Using JAVA_HOME: $JAVA_HOME"
    return 0
  fi

  # macOS: try java_home
  if command -v /usr/libexec/java_home &>/dev/null; then
    local java21
    java21="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
    if [[ -n "$java21" ]]; then
      export JAVA_HOME="$java21"
      echo "Using macOS Java 21: $JAVA_HOME"
      return 0
    fi
  fi

  echo "ERROR: Java 21 required. Install GraalVM CE 21 via SDKMAN:" >&2
  echo "  sdk install java 21.0.2-graalce" >&2
  exit 1
}

# Compile the demo
compile() {
  echo "Compiling TornadoVM 4.0 demo..."
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR/mods"
  find "$SRC_DIR" -name "*.java" > "$BUILD_DIR/sources.txt"

  local tornado_jars
  tornado_jars="$(find "$TORNADOVM_HOME" -name '*.jar' -print0 | tr '\0' ':')"

  "$JAVA_HOME/bin/javac" -g --enable-preview --release 21 \
    --module-path "$tornado_jars" \
    -d "$BUILD_DIR/mods/demo.tornadovm" \
    @"$BUILD_DIR/sources.txt"

  echo "Compilation successful!"
}

# Run the demo
run() {
  export PATH="$TORNADOVM_HOME/bin:$PATH"

  echo ""
  echo "=== TornadoVM 4.0 Demo ==="
  echo "Devices:"
  tornado --devices 2>&1 | grep -E "(Driver:|device=|Global Memory)" || true
  echo ""

  local device_args=()
  if [[ -n "$TORNADO_DEVICE" ]]; then
    echo "Using device: $TORNADO_DEVICE"
    device_args=(--device "$TORNADO_DEVICE")
  fi

  tornado ${device_args[@]+"${device_args[@]}"} --module-path "$BUILD_DIR/mods" \
    -m demo.tornadovm/demo.tornadovm.VectorAddTornado \
    --params "$*"
}

# Main
main() {
  echo "=== TornadoVM 4.0 Demo Runner ==="
  setup_java
  setup_tornadovm
  compile
  run "${@:---size 1000000 --iters 5 --warmup 2}"
}

main "$@"

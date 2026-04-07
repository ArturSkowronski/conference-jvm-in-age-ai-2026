#!/usr/bin/env bash
set -euo pipefail

# GPULlama3.java Runner for TornadoVM 3.0
# GPU-accelerated LLM inference using TornadoVM 3.0 (JDK 25) with Metal/OpenCL/PTX backends

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/build/gpullama3-src"
REPO_URL="https://github.com/beehive-lab/GPULlama3.java.git"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run-gpullama3.sh --model /path/to/model.gguf --prompt "tell me a joke" [extra args...]

Notes:
  - Requires TornadoVM 3.0 (JDK 25) installed.
  - Set TORNADOVM_HOME to your TornadoVM 3.0 installation directory.
  - Model must be in FP16 format (Q4_K_M and other quantized formats not supported).
  - The first run clones + builds https://github.com/beehive-lab/GPULlama3.java into demos/tornadovm-3/build/.
  - On macOS Apple Silicon, Metal backend is auto-detected.

Examples:
  # Using auto-downloaded SDK (run-tornado.sh downloads it to build/tornadovm-sdk/):
  export TORNADOVM_HOME=./demos/tornadovm-3/build/tornadovm-sdk/tornadovm-3.0.0-jdk25-metal
  ./scripts/run-gpullama3.sh --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf --prompt "say hello" --heap-max 6g
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Support legacy TORNADO_SDK env var
if [[ -n "${TORNADO_SDK:-}" && -z "${TORNADOVM_HOME:-}" ]]; then
  export TORNADOVM_HOME="$TORNADO_SDK"
fi

# Auto-setup TornadoVM 3.0 if not set
if [[ -z "${TORNADOVM_HOME:-}" ]]; then
  echo "TORNADOVM_HOME not set. Attempting auto-setup..."

  export TORNADOVM_VERSION="${TORNADOVM_VERSION:-3.0.0}"
  export TORNADOVM_JDK="${TORNADOVM_JDK:-jdk25}"

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

  # TornadoVM 3.0 only has opencl on macOS (no Metal)
  backend="opencl"
  sdk_dir="$ROOT_DIR/build/tornadovm-sdk"
  sdk_path="$sdk_dir/tornadovm-${TORNADOVM_VERSION}-${TORNADOVM_JDK}-${backend}"
  alt_sdk_path="$sdk_dir/tornadovm-${TORNADOVM_VERSION}-${backend}"

  if [[ -d "$sdk_path" ]]; then
    export TORNADOVM_HOME="$sdk_path"
    echo "Using cached TornadoVM 3.0 SDK: $TORNADOVM_HOME"
  elif [[ -d "$alt_sdk_path" ]]; then
    export TORNADOVM_HOME="$alt_sdk_path"
    echo "Using cached TornadoVM 3.0 SDK: $TORNADOVM_HOME"
  else
    echo "TornadoVM 3.0 SDK not found. Run ./scripts/run-tornado.sh first to download it." >&2
    echo "Or set TORNADOVM_HOME manually." >&2
    exit 2
  fi
fi

# Use TORNADOVM_HOME as JAVA_HOME if not set (for bundled JDK distributions)
if [[ -z "${JAVA_HOME:-}" ]]; then
  export JAVA_HOME="$TORNADOVM_HOME"
fi

# Workaround for JVMCI compatibility issues between JDK versions
export JVMCI_CONFIG_CHECK="${JVMCI_CONFIG_CHECK:-ignore}"

# Device selection for multi-backend builds: 0:0=OpenCL/Metal, 1:0=PTX/CUDA
if [[ -n "${TORNADO_DEVICE:-}" ]]; then
  export JAVA_OPTS="${JAVA_OPTS:-} -Dtornado.device=$TORNADO_DEVICE"
  echo "Using TornadoVM device: $TORNADO_DEVICE"
fi

if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "JAVA_HOME does not look like a JDK: $JAVA_HOME" >&2
  exit 2
fi

if [[ ! -d "$SRC_DIR/.git" ]]; then
  rm -rf "$SRC_DIR"
  mkdir -p "$(dirname -- "$SRC_DIR")"
  git clone --depth 1 "$REPO_URL" "$SRC_DIR"
fi

(
  cd "$SRC_DIR"
  ./mvnw -q -DskipTests package
)

export LLAMA_ROOT="$SRC_DIR"

DEFAULT_ARGS=()

has_flag() {
  local flag="$1"
  shift
  for arg in "$@"; do
    if [[ "$arg" == "$flag" ]]; then
      return 0
    fi
  done
  return 1
}

if ! has_flag --gpu "$@"; then
  DEFAULT_ARGS+=(--gpu)
fi
if ! has_flag --heap-min "$@"; then
  DEFAULT_ARGS+=(--heap-min "${GPULLAMA3_HEAP_MIN:-4g}")
fi
if ! has_flag --heap-max "$@"; then
  DEFAULT_ARGS+=(--heap-max "${GPULLAMA3_HEAP_MAX:-4g}")
fi
if ! has_flag --gpu-memory "$@"; then
  DEFAULT_ARGS+=(--gpu-memory "${GPULLAMA3_GPU_MEMORY:-7GB}")
fi

exec "$SRC_DIR/llama-tornado" "${DEFAULT_ARGS[@]}" "$@"

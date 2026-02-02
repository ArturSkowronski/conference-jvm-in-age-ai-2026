#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/build/gpullama3-src"
REPO_URL="https://github.com/beehive-lab/GPULlama3.java.git"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run-gpullama3.sh --model /path/to/model.gguf --prompt "tell me a joke" [extra args...]

Notes:
  - Requires TornadoVM (JDK 21) installed.
  - Set TORNADOVM_HOME to your TornadoVM installation directory.
  - Model must be in FP16 format (Q4_K_M and other quantized formats not supported).
  - The first run clones + builds https://github.com/beehive-lab/GPULlama3.java into tornadovm-demo/build/.

Examples:
  # Using auto-downloaded SDK (run-tornado.sh downloads it to build/tornadovm-sdk/):
  export TORNADOVM_HOME=./tornadovm-demo/build/tornadovm-sdk/tornadovm-2.2.0-opencl
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

if [[ -z "${TORNADOVM_HOME:-}" ]]; then
  echo "Missing TornadoVM path. Set TORNADOVM_HOME environment variable." >&2
  exit 2
fi

# Use TORNADOVM_HOME as JAVA_HOME if not set (for bundled JDK distributions)
if [[ -z "${JAVA_HOME:-}" ]]; then
  export JAVA_HOME="$TORNADOVM_HOME"
fi

# Workaround for JVMCI compatibility issues between JDK versions
# See: https://tornadovm.readthedocs.io/en/latest/faq.html
export JVMCI_CONFIG_CHECK="${JVMCI_CONFIG_CHECK:-ignore}"

# Device selection for multi-backend builds: 0:0=OpenCL, 1:0=PTX/CUDA
# Passed via JAVA_OPTS to the llama-tornado launcher
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


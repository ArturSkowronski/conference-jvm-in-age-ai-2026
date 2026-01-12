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
  - Set TORNADO_SDK (preferred) or TORNADOVM_HOME to your TornadoVM installation directory.
  - The first run clones + builds https://github.com/beehive-lab/GPULlama3.java into tornadovm-demo/build/.

Examples:
  export TORNADO_SDK=~/.sdkman/candidates/java/22.1.0-tornadovm
  ./scripts/run-gpullama3.sh --model ./beehive-llama-3.2-1b-instruct-fp16.gguf --prompt "say hello" --heap-max 6g
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -n "${TORNADO_SDK:-}" && -z "${TORNADOVM_HOME:-}" ]]; then
  export TORNADOVM_HOME="$TORNADO_SDK"
fi

if [[ -z "${TORNADOVM_HOME:-}" ]]; then
  echo "Missing TornadoVM path. Set TORNADO_SDK or TORNADOVM_HOME." >&2
  exit 2
fi

if [[ -z "${JAVA_HOME:-}" ]]; then
  export JAVA_HOME="$TORNADOVM_HOME"
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


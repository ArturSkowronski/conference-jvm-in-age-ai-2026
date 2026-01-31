#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/build/cyfra-src"
REPO_URL="https://github.com/ComputeNode/cyfra.git"
BRANCH="llm.scala"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run-cyfra-llama.sh --model /path/to/model.gguf --prompt "tell me a joke" [extra args...]

Notes:
  - Requires sbt (Scala Build Tool) installed.
  - Requires Vulkan drivers (NVIDIA, AMD, Intel, or MoltenVK on macOS).
  - Model must be in FP16 format (Llama-3.2-1B-Instruct-f16.gguf).
  - The first run clones + builds https://github.com/ComputeNode/cyfra (branch llm.scala)
    into cyfra-demo/build/.
  - sbt should be launched with at least 4 GB heap (set via SBT_OPTS).

Examples:
  ./scripts/run-cyfra-llama.sh \
    --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
    --prompt "Hello, how are you?"

  # Benchmark mode (warmup + multiple runs):
  ./scripts/run-cyfra-llama.sh \
    --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
    --prompt "Hello" --measure
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# ── Parse arguments ──────────────────────────────────────────────────────────

MODEL=""
PROMPT=""
MEASURE=false
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --model|-m)   MODEL="$2"; shift 2 ;;
    --prompt|-p)  PROMPT="$2"; shift 2 ;;
    --measure)    MEASURE=true; shift ;;
    *)            EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [[ -z "$MODEL" ]]; then
  MODEL="${MODEL_PATH:-$HOME/.llama/models/Llama-3.2-1B-Instruct-f16.gguf}"
fi

if [[ -z "$PROMPT" ]]; then
  PROMPT="Hello, how are you?"
fi

if [[ ! -f "$MODEL" ]]; then
  echo "Error: Model not found at $MODEL" >&2
  echo "Download it with: ./scripts/download-models.sh --fp16" >&2
  exit 1
fi

# ── Check prerequisites ─────────────────────────────────────────────────────

if ! command -v sbt &>/dev/null; then
  echo "Error: sbt not found. Install it from https://www.scala-sbt.org/download" >&2
  exit 2
fi

# ── Clone Cyfra if needed ────────────────────────────────────────────────────

if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "Cloning Cyfra ($BRANCH branch)..."
  rm -rf "$SRC_DIR"
  mkdir -p "$(dirname -- "$SRC_DIR")"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$SRC_DIR"
fi

# ── Build and run ────────────────────────────────────────────────────────────

export SBT_OPTS="${SBT_OPTS:--Xmx4g}"

# macOS Vulkan (MoltenVK) support
if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ -n "${VULKAN_SDK:-}" ]]; then
    export SBT_OPTS="$SBT_OPTS -Dorg.lwjgl.vulkan.libname=libvulkan.1.dylib -Djava.library.path=$VULKAN_SDK/lib"
  fi
fi

RUNNER_ARGS="-m $MODEL -t f16 -p \"$PROMPT\""

if [[ "$MEASURE" == "true" ]]; then
  RUNNER_ARGS="$RUNNER_ARGS --measure"
fi

for arg in "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"; do
  RUNNER_ARGS="$RUNNER_ARGS $arg"
done

cd "$SRC_DIR"
exec sbt "llama/runMain io.computenode.cyfra.llama.Runner $RUNNER_ARGS"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(dirname -- "$SCRIPT_DIR")"
VENV_DIR="$DEMO_DIR/.venv"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run-llama.sh [--model /path/to/model.gguf] [--prompt "your prompt"] [options]

Options:
  --model PATH       Path to GGUF model (default: ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf)
  --prompt TEXT      Prompt for the model (default: "Tell me a short joke about programming.")
  --max-tokens N     Maximum tokens to generate (default: 256)
  --temperature F    Temperature for sampling (default: 0.7)
  -h, --help         Show this help

Prerequisites:
  - GraalPy installed via pyenv (e.g., pyenv install graalpy-community-24.1.1)
    or standalone from https://github.com/oracle/graalpython/releases
  - Model file (~2.5 GB, same model used by TornadoVM GPULlama3 demo)

Model download:
  mkdir -p ~/.llama/models
  curl -L -o ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
    "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"

Examples:
  ./scripts/run-llama.sh --prompt "tell me a joke"
  ./scripts/run-llama.sh --model ~/models/llama.gguf --prompt "explain recursion" --max-tokens 512
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Find GraalPy JVM (check multiple locations)
find_graalpy() {
  # Check for GraalPy JVM in ~/.graalpy first (preferred for native library support)
  if [[ -d "$HOME/.graalpy" ]]; then
    local graalpy_jvm
    graalpy_jvm=$(find "$HOME/.graalpy" -maxdepth 3 -path "*jvm*/bin/graalpy" -type f 2>/dev/null | sort -V | tail -1)
    if [[ -n "$graalpy_jvm" && -x "$graalpy_jvm" ]]; then
      echo "$graalpy_jvm"
      return 0
    fi
  fi

  # Check GRAALVM_HOME
  if [[ -n "${GRAALVM_HOME:-}" && -x "$GRAALVM_HOME/bin/graalpy" ]]; then
    echo "$GRAALVM_HOME/bin/graalpy"
    return 0
  fi

  # Check pyenv versions (Native version - may have ctypes limitations)
  if [[ -d "$HOME/.pyenv/versions" ]]; then
    local pyenv_graalpy
    pyenv_graalpy=$(find "$HOME/.pyenv/versions" -maxdepth 3 -path "*/bin/graalpy" -type f 2>/dev/null | sort -V | tail -1)
    if [[ -n "$pyenv_graalpy" && -x "$pyenv_graalpy" ]]; then
      echo "$pyenv_graalpy"
      return 0
    fi
  fi

  # Check if graalpy is directly in PATH (not a shim)
  local graalpy_path
  graalpy_path=$(which graalpy 2>/dev/null)
  if [[ -n "$graalpy_path" && -x "$graalpy_path" && ! "$graalpy_path" =~ "shims" ]]; then
    echo "$graalpy_path"
    return 0
  fi

  return 1
}

GRAALPY=$(find_graalpy) || {
  echo "Error: GraalPy not found." >&2
  echo "Install via pyenv: pyenv install graalpy-community-<version>" >&2
  echo "  List available: pyenv install --list | grep graalpy" >&2
  echo "Or download from: https://github.com/oracle/graalpython/releases" >&2
  exit 1
}

echo "Using GraalPy: $GRAALPY"
"$GRAALPY" --version

# Create virtual environment if it doesn't exist
if [[ ! -d "$VENV_DIR" ]]; then
  echo ""
  echo "Creating virtual environment at $VENV_DIR..."
  "$GRAALPY" -m venv "$VENV_DIR"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Install llama-cpp-python if not present
if ! python -c "import llama_cpp" 2>/dev/null; then
  echo ""
  echo "Installing dependencies (this may take a few minutes)..."
  pip install --upgrade pip
  pip install llama-cpp-python
fi

echo ""

# Run the inference script
exec python "$DEMO_DIR/llama_inference.py" "$@"

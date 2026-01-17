#!/usr/bin/env bash
#
# Run Llama3.java - Pure Java LLM inference
# https://github.com/mukel/llama3.java
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"
LLAMA3_JAVA="$PROJECT_DIR/Llama3.java"

# Default values
MODEL_PATH="$ROOT_DIR/models/Llama-3.2-1B-Instruct-f16.gguf"
PROMPT="Tell me a short joke about programming."
MAX_TOKENS=256
MODE="--instruct"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --model)
      MODEL_PATH="$2"
      shift 2
      ;;
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --max-tokens)
      MAX_TOKENS="$2"
      shift 2
      ;;
    --chat)
      MODE="--chat"
      shift
      ;;
    --instruct)
      MODE="--instruct"
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --model PATH      Path to GGUF model (default: <project>/models/Llama-3.2-1B-Instruct-f16.gguf)"
      echo "  --prompt TEXT     Prompt for the model"
      echo "  --max-tokens N    Maximum tokens to generate (default: 256)"
      echo "  --chat            Run in chat mode"
      echo "  --instruct        Run in instruct mode (default)"
      echo "  --help            Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Find Java
if [[ -n "$JAVA_HOME" ]]; then
  JAVA="$JAVA_HOME/bin/java"
elif command -v java &> /dev/null; then
  JAVA="java"
else
  echo "Error: Java not found. Please set JAVA_HOME or add java to PATH."
  exit 1
fi

# Check Java version
JAVA_VERSION=$("$JAVA" -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)
if [[ "$JAVA_VERSION" -lt 21 ]]; then
  echo "Error: Java 21+ required (found: $JAVA_VERSION)"
  exit 1
fi

# Check if Llama3.java exists
if [[ ! -f "$LLAMA3_JAVA" ]]; then
  echo "Downloading Llama3.java..."
  curl -L -o "$LLAMA3_JAVA" "https://raw.githubusercontent.com/mukel/llama3.java/main/Llama3.java"
fi

# Check if model exists
if [[ ! -f "$MODEL_PATH" ]]; then
  echo "Model not found: $MODEL_PATH"
  echo ""
  echo "Download models with:"
  echo "  ./scripts/download-models.sh --all"
  exit 1
fi

echo "============================================================"
echo "Llama3.java - Pure Java LLM Inference"
echo "============================================================"
echo "Java: $("$JAVA" -version 2>&1 | head -1)"
echo "Model: $MODEL_PATH"
echo "Mode: $MODE"
echo "============================================================"
echo ""

# Run Llama3.java
# Using source mode for simplicity (no compilation needed)
exec "$JAVA" \
  --enable-preview \
  --source 21 \
  --add-modules jdk.incubator.vector \
  -Xmx8g \
  "$LLAMA3_JAVA" \
  $MODE \
  --model "$MODEL_PATH" \
  --max-tokens "$MAX_TOKENS" \
  --prompt "$PROMPT"

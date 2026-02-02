#!/usr/bin/env bash
#
# Download Llama models for the JVM AI demos
#
# Usage:
#   ./scripts/download-models.sh           # Download all models
#   ./scripts/download-models.sh --fp16    # Download only FP16 model
#   ./scripts/download-models.sh --q4      # Download only Q4_0 model
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

MODEL_DIR="${LLAMA_MODEL_DIR:-$HOME/.llama/models}"

# Model URLs
FP16_URL="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"
FP16_FILE="Llama-3.2-1B-Instruct-f16.gguf"
FP16_SIZE="2.5 GB"

Q4_0_URL="https://huggingface.co/hugging-quants/Llama-3.2-1B-Instruct-Q4_0-GGUF/resolve/main/llama-3.2-1b-instruct-q4_0.gguf"
Q4_0_FILE="Llama-3.2-1B-Instruct-Q4_0.gguf"
Q4_0_SIZE="0.8 GB"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo -e "${BLUE}============================================================${NC}"
  echo -e "${BLUE}  Llama Model Downloader${NC}"
  echo -e "${BLUE}============================================================${NC}"
  echo -e "  Model directory: ${GREEN}$MODEL_DIR${NC}"
  echo -e "${BLUE}============================================================${NC}"
  echo ""
}

print_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Download Llama 3.2 1B Instruct models for the JVM AI demos.

Options:
  --all       Download all models (default)
  --fp16      Download FP16 model only (~$FP16_SIZE)
  --q4        Download Q4_0 quantized model only (~$Q4_0_SIZE)
  --list      List available models and their status
  --help      Show this help message

Environment:
  LLAMA_MODEL_DIR   Override model directory (default: ~/.llama/models)

Models:
  FP16  - Full precision, best quality (~$FP16_SIZE)
          Used by: java-llama.cpp, TornadoVM GPULlama3, cpython-llama

  Q4_0  - 4-bit quantized, smaller & faster (~$Q4_0_SIZE)
          Used by: Llama3.java (recommended)

EOF
}

download_model() {
  local url="$1"
  local filename="$2"
  local size="$3"
  local filepath="$MODEL_DIR/$filename"

  if [[ -f "$filepath" ]]; then
    local existing_size=$(du -h "$filepath" | cut -f1)
    echo -e "${GREEN}✓${NC} $filename already exists ($existing_size)"
    return 0
  fi

  echo -e "${YELLOW}↓${NC} Downloading $filename (~$size)..."
  echo "  URL: $url"
  echo ""

  # Create temp file for download
  local tmpfile="$filepath.tmp"

  # Download with progress
  if command -v curl &> /dev/null; then
    curl -L --progress-bar -o "$tmpfile" "$url"
  elif command -v wget &> /dev/null; then
    wget --progress=bar:force -O "$tmpfile" "$url"
  else
    echo -e "${RED}Error: Neither curl nor wget found${NC}"
    return 1
  fi

  # Move to final location
  mv "$tmpfile" "$filepath"

  local final_size=$(du -h "$filepath" | cut -f1)
  echo -e "${GREEN}✓${NC} Downloaded $filename ($final_size)"
  echo ""
}

list_models() {
  echo "Available models:"
  echo ""

  printf "  %-40s %8s  %s\n" "Model" "Size" "Status"
  printf "  %-40s %8s  %s\n" "-----" "----" "------"

  # FP16
  if [[ -f "$MODEL_DIR/$FP16_FILE" ]]; then
    local size=$(du -h "$MODEL_DIR/$FP16_FILE" | cut -f1)
    printf "  %-40s %8s  ${GREEN}Downloaded${NC}\n" "$FP16_FILE" "$size"
  else
    printf "  %-40s %8s  ${YELLOW}Not downloaded${NC}\n" "$FP16_FILE" "~$FP16_SIZE"
  fi

  # Q4_0
  if [[ -f "$MODEL_DIR/$Q4_0_FILE" ]]; then
    local size=$(du -h "$MODEL_DIR/$Q4_0_FILE" | cut -f1)
    printf "  %-40s %8s  ${GREEN}Downloaded${NC}\n" "$Q4_0_FILE" "$size"
  else
    printf "  %-40s %8s  ${YELLOW}Not downloaded${NC}\n" "$Q4_0_FILE" "~$Q4_0_SIZE"
  fi

  echo ""
  echo "Model directory: $MODEL_DIR"
}

# Parse arguments
DOWNLOAD_FP16=false
DOWNLOAD_Q4=false

if [[ $# -eq 0 ]]; then
  DOWNLOAD_FP16=true
  DOWNLOAD_Q4=true
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      DOWNLOAD_FP16=true
      DOWNLOAD_Q4=true
      shift
      ;;
    --fp16)
      DOWNLOAD_FP16=true
      shift
      ;;
    --q4|--q4_0)
      DOWNLOAD_Q4=true
      shift
      ;;
    --list)
      print_header
      list_models
      exit 0
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Main
print_header

# Create model directory
mkdir -p "$MODEL_DIR"

# Download requested models
if [[ "$DOWNLOAD_FP16" == true ]]; then
  download_model "$FP16_URL" "$FP16_FILE" "$FP16_SIZE"
fi

if [[ "$DOWNLOAD_Q4" == true ]]; then
  download_model "$Q4_0_URL" "$Q4_0_FILE" "$Q4_0_SIZE"
fi

echo -e "${GREEN}Done!${NC}"
echo ""
list_models

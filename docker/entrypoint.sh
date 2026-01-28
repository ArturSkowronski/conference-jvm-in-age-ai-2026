#!/usr/bin/env bash
#
# Docker Entrypoint — JVM in the Age of AI Benchmark Suite
#
# Runs all demos on NVIDIA GPU (GCP T4/L4/A100) and generates a report.
#
# Volumes:
#   /models  — GGUF model files (downloaded automatically if missing)
#   /results — benchmark output (markdown + JSON)
#

set -euo pipefail

PROJECT_DIR="/workspace"
cd "$PROJECT_DIR"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"; }
error()   { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"; }

# ── Report setup ────────────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="/results"
mkdir -p "$OUTPUT_DIR"
RESULTS_FILE="$OUTPUT_DIR/benchmark_${TIMESTAMP}.md"
JSON_FILE="$OUTPUT_DIR/benchmark_${TIMESTAMP}.json"
RESULTS_TMP="$OUTPUT_DIR/.results_tmp"
: > "$RESULTS_TMP"

set_result() {
  echo "${1}|${2}" >> "$RESULTS_TMP"
}

# ── Environment detection ──────────────────────────────────────────────────
detect_environment() {
  log "Detecting environment..."

  OS_NAME=$(uname -s)
  OS_ARCH=$(uname -m)

  HAS_NVIDIA_GPU=false
  NVIDIA_GPU_NAME="N/A"
  CUDA_DRIVER="N/A"
  CUDA_TOOLKIT="N/A"

  if command -v nvidia-smi &>/dev/null; then
    HAS_NVIDIA_GPU=true
    NVIDIA_GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "Unknown")
    CUDA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "Unknown")
  fi
  if command -v nvcc &>/dev/null; then
    CUDA_TOOLKIT=$(nvcc --version 2>/dev/null | grep "release" | awk '{print $5}' | cut -d',' -f1 || echo "Unknown")
  fi

  TOTAL_RAM=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "Unknown")
  SYS_JAVA_VERSION=$("$JAVA_HOME/bin/java" -version 2>&1 | head -1 | cut -d'"' -f2 || echo "Unknown")
  JDK21_VERSION=$("$JDK_21/bin/java" -version 2>&1 | head -1 | cut -d'"' -f2 || echo "N/A")

  echo ""
  echo "============================================================"
  echo "  JVM in the Age of AI — Docker Benchmark"
  echo "============================================================"
  echo "  OS:             $OS_NAME $OS_ARCH"
  echo "  RAM:            ${TOTAL_RAM} GB"
  echo "  NVIDIA GPU:     $NVIDIA_GPU_NAME"
  echo "  CUDA Driver:    $CUDA_DRIVER"
  echo "  CUDA Toolkit:   $CUDA_TOOLKIT"
  echo "  JDK 25:         $SYS_JAVA_VERSION"
  echo "  JDK 21:         $JDK21_VERSION"
  echo "  TornadoVM:      ${TORNADOVM_HOME:-not set}"
  echo "  Models:         ${MODEL_PATH}"
  echo "============================================================"
  echo ""

  if [[ "$HAS_NVIDIA_GPU" == "true" ]]; then
    nvidia-smi
    echo ""
    # Enable GPU offload for java-llama.cpp
    export LLAMA_GPU_LAYERS=99
  else
    warn "No NVIDIA GPU detected. GPU demos will be skipped."
  fi
}

# ── Download models if needed ───────────────────────────────────────────────
download_models() {
  mkdir -p "$LLAMA_MODEL_DIR"

  # Create symlink so scripts using $HOME/.llama/models also find the model
  if [[ "$LLAMA_MODEL_DIR" != "$HOME/.llama/models" ]]; then
    mkdir -p "$HOME/.llama"
    ln -sfn "$LLAMA_MODEL_DIR" "$HOME/.llama/models"
  fi

  FP16_FILE="Llama-3.2-1B-Instruct-f16.gguf"
  FP16_URL="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"

  if [[ -f "$LLAMA_MODEL_DIR/$FP16_FILE" ]]; then
    success "Model already present: $FP16_FILE"
  else
    log "Downloading FP16 model (~2.5 GB)..."
    curl -fL --progress-bar -o "$LLAMA_MODEL_DIR/$FP16_FILE.tmp" "$FP16_URL"
    mv "$LLAMA_MODEL_DIR/$FP16_FILE.tmp" "$LLAMA_MODEL_DIR/$FP16_FILE"
    success "Downloaded $FP16_FILE"
  fi
}

# ── Run a single demo with timeout and result capture ───────────────────────
run_demo() {
  local name="$1"
  local command="$2"
  local requires_gpu="${3:-false}"
  local timeout_sec="${4:-300}"

  if [[ "$requires_gpu" == "true" && "$HAS_NVIDIA_GPU" != "true" ]]; then
    warn "Skipping $name (requires NVIDIA GPU)"
    set_result "$name" "SKIPPED (no GPU)"
    return 0
  fi

  echo ""
  echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC} Running: ${BOLD}$name${NC}"
  echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"

  local start_time=$(date +%s)
  local log_file="$OUTPUT_DIR/${name// /_}_${TIMESTAMP}.log"

  set +e
  timeout "$timeout_sec" bash -c "$command" </dev/null 2>&1 | tee "$log_file"
  local exit_code=${PIPESTATUS[0]}
  set -e

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  if [[ $exit_code -eq 0 ]]; then
    # Extract tokens/sec if present
    local toks
    toks=$(grep -oE "([0-9]+\.?[0-9]*) (tokens?/s|tok/s)|Tokens/sec: ([0-9]+\.?[0-9]*)|generation: ([0-9]+\.?[0-9]*) tokens" "$log_file" | tail -1 | grep -oE "[0-9]+\.[0-9]+" || echo "")
    if [[ -n "$toks" ]]; then
      success "$name completed in ${duration}s — ${toks} tok/s"
      set_result "$name" "OK: ${toks} tok/s (${duration}s)"
    else
      success "$name completed in ${duration}s"
      set_result "$name" "OK (${duration}s)"
    fi
  elif [[ $exit_code -eq 124 ]]; then
    error "$name TIMED OUT after ${timeout_sec}s"
    set_result "$name" "TIMEOUT (${timeout_sec}s)"
  else
    error "$name FAILED (exit $exit_code)"
    set_result "$name" "FAILED (exit $exit_code)"
    echo "  Last 10 lines:"
    tail -10 "$log_file" | sed 's/^/    /'
  fi
}

# ── Run all benchmarks ──────────────────────────────────────────────────────
run_benchmarks() {
  log "Starting benchmarks..."

  # ── LLM Inference ──

  # Llama3.java with JDK 21
  if [[ -d "$JDK_21" ]]; then
    run_demo "Llama3.java (JDK 21)" \
      "JAVA_HOME=$JDK_21 $PROJECT_DIR/demos/llama3-java/scripts/run-llama3.sh --max-tokens 32" \
      false 300
  fi

  # Llama3.java with JDK 25
  if [[ -d "$JDK_25_TEM" ]]; then
    run_demo "Llama3.java (JDK 25 Temurin)" \
      "JAVA_HOME=$JDK_25_TEM $PROJECT_DIR/demos/llama3-java/scripts/run-llama3.sh --max-tokens 32" \
      false 300
  fi

  # java-llama.cpp (CPU mode — prebuilt Maven native)
  run_demo "java-llama.cpp" \
    "$PROJECT_DIR/gradlew :demos:java-llama-cpp:run --no-daemon --console=plain" \
    false 300

  # ── GPU Demos ──

  # JCuda device info
  run_demo "JCuda" \
    "$PROJECT_DIR/gradlew :demos:jcuda:run --no-daemon --console=plain" \
    true 120

  # TornadoVM VectorAdd
  if [[ -d "${TORNADOVM_HOME:-}" ]]; then
    run_demo "TornadoVM VectorAdd" \
      "JAVA_HOME=$JDK_21 $PROJECT_DIR/tornadovm-demo/scripts/run-tornado.sh --size 10000000 --iters 5 --warmup 2" \
      true 300
  fi

  # TornadoVM GPULlama3
  if [[ -d "${TORNADOVM_HOME:-}" ]]; then
    run_demo "TornadoVM GPULlama3" \
      "JAVA_HOME=$JDK_21 $PROJECT_DIR/tornadovm-demo/scripts/run-gpullama3.sh --model $MODEL_PATH --prompt 'Hello'" \
      true 600
  fi

  # ── Non-LLM Demos ──

  # TensorFlow FFM
  run_demo "TensorFlow FFM" \
    "$PROJECT_DIR/gradlew :demos:tensorflow-ffm:runTensorFlow --no-daemon --console=plain" \
    false 600

  # GraalPy Java Host
  run_demo "GraalPy Java Host" \
    "$PROJECT_DIR/gradlew :demos:graalpy-java-host:run --no-daemon --console=plain" \
    false 300
}

# ── Generate report ─────────────────────────────────────────────────────────
generate_report() {
  log "Generating report..."

  cat > "$RESULTS_FILE" <<EOF
# JVM in the Age of AI — Docker Benchmark Results

**Generated**: $(date)
**Host**: $(hostname)
**Image**: jvm-ai-benchmark

## Environment

| Property | Value |
|----------|-------|
| OS | $OS_NAME $OS_ARCH |
| RAM | ${TOTAL_RAM} GB |
| NVIDIA GPU | $NVIDIA_GPU_NAME |
| CUDA Driver | $CUDA_DRIVER |
| CUDA Toolkit | $CUDA_TOOLKIT |
| JDK 25 | $SYS_JAVA_VERSION |
| JDK 21 | $JDK21_VERSION |
| TornadoVM | ${TORNADOVM_HOME:-N/A} (backend: ${TORNADOVM_BACKEND:-N/A}) |

## Results

| Demo | Result |
|------|--------|
EOF

  while IFS='|' read -r demo status; do
    echo "| $demo | $status |" >> "$RESULTS_FILE"
  done < "$RESULTS_TMP"

  cat >> "$RESULTS_FILE" <<EOF

## Notes

- Model: Llama-3.2-1B-Instruct-f16.gguf (FP16, ~2.5GB)
- TornadoVM uses OpenCL backend (NVIDIA GPU)
- java-llama.cpp uses CUDA-built native with GPU offload (all layers)
- Individual demo logs saved alongside this report
EOF

  # JSON report
  {
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"hostname\": \"$(hostname)\","
    echo "  \"environment\": {"
    echo "    \"os\": \"$OS_NAME $OS_ARCH\","
    echo "    \"ram_gb\": \"$TOTAL_RAM\","
    echo "    \"nvidia_gpu\": \"$NVIDIA_GPU_NAME\","
    echo "    \"cuda_driver\": \"$CUDA_DRIVER\","
    echo "    \"cuda_toolkit\": \"$CUDA_TOOLKIT\","
    echo "    \"jdk_25\": \"$SYS_JAVA_VERSION\","
    echo "    \"jdk_21\": \"$JDK21_VERSION\","
    echo "    \"tornadovm_backend\": \"${TORNADOVM_BACKEND:-N/A}\""
    echo "  },"
    echo "  \"results\": {"
    local first=true
    while IFS='|' read -r demo status; do
      if [[ "$first" == "true" ]]; then first=false; else echo ","; fi
      echo -n "    \"$demo\": \"$status\""
    done < "$RESULTS_TMP"
    echo ""
    echo "  }"
    echo "}"
  } > "$JSON_FILE"

  rm -f "$RESULTS_TMP"

  success "Report: $RESULTS_FILE"
  success "JSON:   $JSON_FILE"

  echo ""
  echo "============================================================"
  echo "  Benchmark Summary"
  echo "============================================================"
  cat "$RESULTS_FILE"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  detect_environment
  download_models
  run_benchmarks
  generate_report

  echo ""
  success "All benchmarks complete!"
  echo ""
}

main "$@"

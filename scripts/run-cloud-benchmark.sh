#!/usr/bin/env bash
#
# Cloud Benchmark Runner for JVM AI Demos
#
# This script runs all demos on a cloud instance and generates a benchmark report.
# Designed for: AWS EC2 g4dn, RunPod, Lambda Labs, or any Linux with NVIDIA GPU
#
# Usage:
#   ./scripts/run-cloud-benchmark.sh [OPTIONS]
#
# Options:
#   --skip-setup      Skip environment setup (JDK, Python, etc.)
#   --skip-download   Skip model download (if already present)
#   --gpu-only        Only run GPU-requiring demos
#   --cpu-only        Only run CPU demos (skip JCuda, TornadoVM GPU)
#   --output DIR      Output directory for results (default: ./benchmark-results)
#   --help            Show this help
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default options
SKIP_SETUP=false
SKIP_DOWNLOAD=false
GPU_ONLY=false
CPU_ONLY=false
OUTPUT_DIR="$PROJECT_DIR/benchmark-results"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-setup)
      SKIP_SETUP=true
      shift
      ;;
    --skip-download)
      SKIP_DOWNLOAD=true
      shift
      ;;
    --gpu-only)
      GPU_ONLY=true
      shift
      ;;
    --cpu-only)
      CPU_ONLY=true
      shift
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --help)
      echo "Cloud Benchmark Runner for JVM AI Demos"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --skip-setup      Skip environment setup (JDK, Python, etc.)"
      echo "  --skip-download   Skip model download (if already present)"
      echo "  --gpu-only        Only run GPU-requiring demos"
      echo "  --cpu-only        Only run CPU demos (skip JCuda, TornadoVM GPU)"
      echo "  --output DIR      Output directory for results (default: ./benchmark-results)"
      echo "  --help            Show this help"
      echo ""
      echo "Designed for: AWS EC2 g4dn, RunPod, Lambda Labs, or any Linux with NVIDIA GPU"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$OUTPUT_DIR/benchmark_${TIMESTAMP}.md"
JSON_FILE="$OUTPUT_DIR/benchmark_${TIMESTAMP}.json"

log() {
  echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"
}

success() {
  echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"
}

warn() {
  echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"
}

error() {
  echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"
}

# ============================================================
# Environment Detection
# ============================================================

detect_environment() {
  log "Detecting environment..."

  # OS and Architecture
  OS_NAME=$(uname -s)
  OS_ARCH=$(uname -m)

  # GPU Detection
  HAS_NVIDIA_GPU=false
  NVIDIA_GPU_NAME="N/A"
  CUDA_VERSION="N/A"

  if command -v nvidia-smi &> /dev/null; then
    HAS_NVIDIA_GPU=true
    NVIDIA_GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "Unknown")
    CUDA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "Unknown")

    # Get CUDA toolkit version if nvcc available
    if command -v nvcc &> /dev/null; then
      CUDA_TOOLKIT=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
    else
      CUDA_TOOLKIT="Not installed"
    fi
  fi

  # OpenCL Detection
  HAS_OPENCL=false
  if command -v clinfo &> /dev/null; then
    if clinfo 2>/dev/null | grep -q "Device Type"; then
      HAS_OPENCL=true
    fi
  fi

  # Memory
  if [[ "$OS_NAME" == "Linux" ]]; then
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
  elif [[ "$OS_NAME" == "Darwin" ]]; then
    TOTAL_RAM=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))
  else
    TOTAL_RAM="Unknown"
  fi

  # Java
  JAVA_VERSION="Not installed"
  if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -1 | cut -d'"' -f2)
  fi

  # Python
  PYTHON_VERSION="Not installed"
  if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
  fi

  echo ""
  echo "============================================================"
  echo "Environment Detected"
  echo "============================================================"
  echo "OS:              $OS_NAME $OS_ARCH"
  echo "RAM:             ${TOTAL_RAM} GB"
  echo "NVIDIA GPU:      $HAS_NVIDIA_GPU ($NVIDIA_GPU_NAME)"
  echo "CUDA Driver:     $CUDA_VERSION"
  echo "CUDA Toolkit:    ${CUDA_TOOLKIT:-N/A}"
  echo "OpenCL:          $HAS_OPENCL"
  echo "Java:            $JAVA_VERSION"
  echo "Python:          $PYTHON_VERSION"
  echo "============================================================"
  echo ""

  # Export for later use
  export OS_NAME OS_ARCH HAS_NVIDIA_GPU NVIDIA_GPU_NAME CUDA_VERSION HAS_OPENCL TOTAL_RAM JAVA_VERSION PYTHON_VERSION
}

# ============================================================
# Setup Functions
# ============================================================

setup_java() {
  log "Setting up Java..."

  # Check if SDKMAN is installed
  if [[ ! -d "$HOME/.sdkman" ]]; then
    log "Installing SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
  else
    source "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null || true
  fi

  # Install GraalVM CE 21 if not present
  if ! sdk list java 2>/dev/null | grep -q "21.*-graalce.*installed"; then
    log "Installing GraalVM CE 21..."
    sdk install java 21.0.5-graalce < /dev/null || true
  fi

  # Use GraalVM
  sdk use java 21.0.5-graalce < /dev/null 2>/dev/null || true

  # Verify
  java -version
  success "Java setup complete"
}

setup_python() {
  log "Setting up Python..."

  # Check Python version
  if ! command -v python3 &> /dev/null; then
    error "Python 3 not found. Please install Python 3.10+"
    return 1
  fi

  # Create virtual environment
  VENV_DIR="$PROJECT_DIR/.venv"
  if [[ ! -d "$VENV_DIR" ]]; then
    python3 -m venv "$VENV_DIR"
  fi

  source "$VENV_DIR/bin/activate"

  # Install llama-cpp-python
  log "Installing llama-cpp-python..."
  if [[ "$HAS_NVIDIA_GPU" == "true" ]]; then
    # With CUDA support
    CMAKE_ARGS="-DGGML_CUDA=on" pip install llama-cpp-python --upgrade --force-reinstall --no-cache-dir 2>/dev/null || \
    pip install llama-cpp-python --upgrade
  else
    pip install llama-cpp-python --upgrade
  fi

  success "Python setup complete"
}

check_tornadovm() {
  log "Checking TornadoVM availability..."

  # TornadoVM is auto-downloaded by run-tornado.sh when needed
  # Just check if the scripts exist
  if [[ -f "$PROJECT_DIR/tornadovm-demo/scripts/run-tornado.sh" ]]; then
    success "TornadoVM scripts available (SDK will be downloaded on first run)"
    export TORNADOVM_AVAILABLE=true
  else
    warn "TornadoVM scripts not found"
    export TORNADOVM_AVAILABLE=false
  fi
}

download_models() {
  log "Downloading models..."

  "$SCRIPT_DIR/download-models.sh" --all

  success "Models downloaded"
}

# ============================================================
# Benchmark Functions
# ============================================================

declare -A RESULTS

run_demo() {
  local name="$1"
  local command="$2"
  local requires_gpu="${3:-false}"
  local timeout="${4:-300}"

  # Skip based on mode
  if [[ "$CPU_ONLY" == "true" ]] && [[ "$requires_gpu" == "true" ]]; then
    warn "Skipping $name (CPU-only mode)"
    RESULTS["$name"]="SKIPPED (CPU-only mode)"
    return 0
  fi

  if [[ "$GPU_ONLY" == "true" ]] && [[ "$requires_gpu" != "true" ]]; then
    warn "Skipping $name (GPU-only mode)"
    RESULTS["$name"]="SKIPPED (GPU-only mode)"
    return 0
  fi

  # Check GPU requirement
  if [[ "$requires_gpu" == "true" ]] && [[ "$HAS_NVIDIA_GPU" != "true" ]]; then
    warn "Skipping $name (requires NVIDIA GPU)"
    RESULTS["$name"]="SKIPPED (no GPU)"
    return 0
  fi

  echo ""
  echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC} Running: ${YELLOW}$name${NC}"
  echo -e "${CYAN}│${NC} Command: $command"
  echo -e "${CYAN}│${NC} Timeout: ${timeout}s"
  echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"

  local start_time=$(date +%s.%N)
  local output_file="$OUTPUT_DIR/${name// /_}_${TIMESTAMP}.log"

  # Run command with timeout - use tee to show output AND save to file
  set +e
  timeout "$timeout" bash -c "$command" 2>&1 | tee "$output_file"
  local exit_code=${PIPESTATUS[0]}
  set -e

  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc)

  echo ""
  if [[ $exit_code -eq 0 ]]; then
    success "$name completed in ${duration}s"

    # Extract tokens/sec if present
    local toks=$(grep -oE "[0-9]+\.?[0-9]* (tokens?/s|tok/s)" "$output_file" | tail -1 || echo "")
    if [[ -n "$toks" ]]; then
      RESULTS["$name"]="SUCCESS: ${duration}s, $toks"
    else
      RESULTS["$name"]="SUCCESS: ${duration}s"
    fi
  elif [[ $exit_code -eq 124 ]]; then
    error "$name TIMED OUT after ${timeout}s"
    RESULTS["$name"]="TIMEOUT"
    echo -e "${RED}Last 20 lines of output:${NC}"
    tail -20 "$output_file"
  else
    error "$name FAILED with exit code $exit_code"
    RESULTS["$name"]="FAILED (exit $exit_code)"
    echo -e "${RED}Last 20 lines of output:${NC}"
    tail -20 "$output_file"
  fi
  echo ""
}

# ============================================================
# Main Benchmark Execution
# ============================================================

run_benchmarks() {
  log "Starting benchmarks..."

  cd "$PROJECT_DIR"

  # Ensure Gradle wrapper is available
  if [[ ! -f "./gradlew" ]]; then
    error "Gradle wrapper not found. Please run from project root."
    exit 1
  fi

  chmod +x ./gradlew 2>/dev/null || true

  echo ""
  echo "============================================================"
  echo "Running Demos"
  echo "============================================================"
  echo ""

  # 1. TensorFlow FFM
  run_demo "TensorFlow FFM" \
    "./gradlew :demos:tensorflow-ffm:runTensorFlow --no-daemon" \
    false 600

  # 2. JCuda
  run_demo "JCuda" \
    "./gradlew :demos:jcuda:run --no-daemon" \
    true 600

  # 3. GraalPy Java Host
  run_demo "GraalPy Java Host" \
    "./gradlew :demos:graalpy-java-host:run --no-daemon" \
    false 600

  # 4. java-llama.cpp
  run_demo "java-llama.cpp" \
    "./gradlew :demos:java-llama-cpp:run --no-daemon" \
    false 600

  # 5. Llama3.java
  run_demo "Llama3.java" \
    "./demos/llama3-java/scripts/run-llama3.sh --prompt 'Tell me a short joke about programming'" \
    false 600

  # 6. llama-cpp-python (CPython)
  if [[ -f "$PROJECT_DIR/.venv/bin/activate" ]]; then
    source "$PROJECT_DIR/.venv/bin/activate"
    run_demo "llama-cpp-python" \
      "python3 $PROJECT_DIR/demos/graalpy-llama/llama_inference.py --prompt 'Tell me a short joke about programming'" \
      false 600
    deactivate 2>/dev/null || true
  else
    warn "Skipping llama-cpp-python (venv not set up)"
    RESULTS["llama-cpp-python"]="SKIPPED (no venv)"
  fi

  # 7. TornadoVM Baseline (CPU)
  if [[ "${TORNADOVM_AVAILABLE:-false}" == "true" ]]; then
    run_demo "TornadoVM Baseline (CPU)" \
      "$PROJECT_DIR/tornadovm-demo/scripts/run-baseline.sh --size 10000000 --iters 3" \
      false 600
  else
    RESULTS["TornadoVM Baseline (CPU)"]="SKIPPED (no TornadoVM)"
  fi

  # 8. TornadoVM VectorAdd (GPU)
  if [[ "${TORNADOVM_AVAILABLE:-false}" == "true" ]]; then
    run_demo "TornadoVM VectorAdd (GPU)" \
      "$PROJECT_DIR/tornadovm-demo/scripts/run-tornado.sh --size 10000000 --iters 3" \
      true 600

    # 9. TornadoVM GPULlama3
    run_demo "TornadoVM GPULlama3" \
      "$PROJECT_DIR/tornadovm-demo/scripts/run-gpullama3.sh --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf --prompt 'Tell me a joke'" \
      true 600
  else
    warn "Skipping TornadoVM demos (scripts not available)"
    RESULTS["TornadoVM VectorAdd (GPU)"]="SKIPPED (no TornadoVM)"
    RESULTS["TornadoVM GPULlama3"]="SKIPPED (no TornadoVM)"
  fi
}

# ============================================================
# Report Generation
# ============================================================

generate_report() {
  log "Generating report..."

  cat > "$RESULTS_FILE" << EOF
# Cloud Benchmark Results

**Generated**: $(date)
**Host**: $(hostname)

## Environment

| Property | Value |
|----------|-------|
| OS | $OS_NAME $OS_ARCH |
| RAM | ${TOTAL_RAM} GB |
| NVIDIA GPU | $HAS_NVIDIA_GPU ($NVIDIA_GPU_NAME) |
| CUDA Driver | $CUDA_VERSION |
| OpenCL | $HAS_OPENCL |
| Java | $JAVA_VERSION |
| Python | $PYTHON_VERSION |

## Results

| Demo | Status |
|------|--------|
EOF

  for demo in "${!RESULTS[@]}"; do
    echo "| $demo | ${RESULTS[$demo]} |" >> "$RESULTS_FILE"
  done

  cat >> "$RESULTS_FILE" << EOF

## Logs

Individual demo logs are saved in: \`$OUTPUT_DIR/\`

## Notes

- Benchmarks run with default settings
- Model: Llama-3.2-1B-Instruct-f16.gguf (FP16, ~2.5GB)
- GPU demos use NVIDIA CUDA/OpenCL where available
EOF

  # Generate JSON
  echo "{" > "$JSON_FILE"
  echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$JSON_FILE"
  echo "  \"hostname\": \"$(hostname)\"," >> "$JSON_FILE"
  echo "  \"environment\": {" >> "$JSON_FILE"
  echo "    \"os\": \"$OS_NAME $OS_ARCH\"," >> "$JSON_FILE"
  echo "    \"ram_gb\": \"$TOTAL_RAM\"," >> "$JSON_FILE"
  echo "    \"nvidia_gpu\": \"$NVIDIA_GPU_NAME\"," >> "$JSON_FILE"
  echo "    \"cuda_version\": \"$CUDA_VERSION\"," >> "$JSON_FILE"
  echo "    \"java_version\": \"$JAVA_VERSION\"," >> "$JSON_FILE"
  echo "    \"python_version\": \"$PYTHON_VERSION\"" >> "$JSON_FILE"
  echo "  }," >> "$JSON_FILE"
  echo "  \"results\": {" >> "$JSON_FILE"

  local first=true
  for demo in "${!RESULTS[@]}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo "," >> "$JSON_FILE"
    fi
    echo -n "    \"$demo\": \"${RESULTS[$demo]}\"" >> "$JSON_FILE"
  done
  echo "" >> "$JSON_FILE"
  echo "  }" >> "$JSON_FILE"
  echo "}" >> "$JSON_FILE"

  success "Report saved to: $RESULTS_FILE"
  success "JSON saved to: $JSON_FILE"

  echo ""
  echo "============================================================"
  echo "Benchmark Summary"
  echo "============================================================"
  cat "$RESULTS_FILE"
}

# ============================================================
# Main
# ============================================================

main() {
  echo ""
  echo "============================================================"
  echo "JVM AI Demos - Cloud Benchmark Runner"
  echo "============================================================"
  echo ""

  detect_environment

  if [[ "$SKIP_SETUP" != "true" ]]; then
    setup_java
    setup_python

    check_tornadovm
  else
    log "Skipping setup (--skip-setup)"
    # Still source SDKMAN if available
    [[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null || true
    # Check TornadoVM even when skipping setup
    check_tornadovm
  fi

  if [[ "$SKIP_DOWNLOAD" != "true" ]]; then
    download_models
  else
    log "Skipping model download (--skip-download)"
  fi

  run_benchmarks
  generate_report

  echo ""
  success "Benchmark complete!"
  echo ""
}

# Create output directory if not exists and set up logging
mkdir -p "$OUTPUT_DIR"
RUN_LOG="$OUTPUT_DIR/run_$(date +%Y%m%d_%H%M%S).log"

echo "=== Benchmark run started at $(date) ===" | tee "$RUN_LOG"
echo "=== Full output will be saved to: $RUN_LOG ===" | tee -a "$RUN_LOG"
echo "" | tee -a "$RUN_LOG"

# Run main and tee all output to log file
main "$@" 2>&1 | tee -a "$RUN_LOG"

echo "" | tee -a "$RUN_LOG"
echo "=== Benchmark run completed at $(date) ===" | tee -a "$RUN_LOG"
echo "=== Full log saved to: $RUN_LOG ===" | tee -a "$RUN_LOG"

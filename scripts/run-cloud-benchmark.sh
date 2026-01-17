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
#   --run-py-baseline Run llama-cpp-python baseline (disabled by default)
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
RUN_PY_BASELINE=false
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
    --run-py-baseline)
      RUN_PY_BASELINE=true
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
      echo "  --run-py-baseline Run llama-cpp-python baseline (disabled by default)"
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
    success "TornadoVM scripts available"
    export TORNADOVM_AVAILABLE=true

    # Try to find and set TORNADOVM_HOME if not already set
    if [[ -z "${TORNADOVM_HOME:-}" ]]; then
      local found_sdk
      if found_sdk=$(find_tornadovm_home); then
        export TORNADOVM_HOME="$found_sdk"
        log "Auto-detected TORNADOVM_HOME: $TORNADOVM_HOME"
      else
        # If not found, download it
        download_tornadovm
      fi
    else
      # Verify existing TORNADOVM_HOME is valid
      if [[ ! -f "$TORNADOVM_HOME/etc/tornado.backend" ]]; then
        warn "Invalid TORNADOVM_HOME: $TORNADOVM_HOME (missing etc/tornado.backend)"
        unset TORNADOVM_HOME
        download_tornadovm
      else
        log "Using existing TORNADOVM_HOME: $TORNADOVM_HOME"
      fi
    fi
  else
    warn "TornadoVM scripts not found"
    export TORNADOVM_AVAILABLE=false
  fi
}

download_tornadovm() {
  log "Downloading TornadoVM SDK..."

  local tornadovm_version="${TORNADOVM_VERSION:-2.2.0}"
  local tornadovm_backend="${TORNADOVM_BACKEND:-opencl}"

  # Detect platform
  local os arch platform
  case "$(uname -s)" in
    Linux*)  os="linux" ;;
    Darwin*) os="mac" ;;
    *)       warn "Unsupported OS for TornadoVM: $(uname -s)"; return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *)            warn "Unsupported architecture for TornadoVM: $(uname -m)"; return 1 ;;
  esac
  platform="${os}-${arch}"

  local sdk_dir="$PROJECT_DIR/tornadovm-demo/build/tornadovm-sdk"
  local sdk_path="$sdk_dir/tornadovm-${tornadovm_version}-${tornadovm_backend}"
  local filename="tornadovm-${tornadovm_version}-${tornadovm_backend}-${platform}.tar.gz"
  local url="https://github.com/beehive-lab/TornadoVM/releases/download/v${tornadovm_version}/${filename}"

  # Check if already downloaded
  if [[ -d "$sdk_path" && -f "$sdk_path/etc/tornado.backend" ]]; then
    export TORNADOVM_HOME="$sdk_path"
    log "Using cached TornadoVM SDK: $TORNADOVM_HOME"
    return 0
  fi

  log "Downloading from: $url"
  mkdir -p "$sdk_dir"

  if curl -fL "$url" -o "$sdk_dir/$filename"; then
    tar -xzf "$sdk_dir/$filename" -C "$sdk_dir"
    rm -f "$sdk_dir/$filename"
    export TORNADOVM_HOME="$sdk_path"
    success "TornadoVM SDK installed: $TORNADOVM_HOME"
  else
    warn "Failed to download TornadoVM SDK"
    return 1
  fi
}

# Helper to find TornadoVM SDK path
find_tornadovm_home() {
  local sdk_dir="$PROJECT_DIR/tornadovm-demo/build/tornadovm-sdk"
  local tornadovm_version="${TORNADOVM_VERSION:-2.2.0}"
  local tornadovm_backend="${TORNADOVM_BACKEND:-opencl}"

  # First try exact version path
  local sdk_path="$sdk_dir/tornadovm-${tornadovm_version}-${tornadovm_backend}"
  if [[ -d "$sdk_path" && -f "$sdk_path/etc/tornado.backend" ]]; then
    echo "$sdk_path"
    return 0
  fi

  # Fallback: find any tornadovm directory with etc/tornado.backend
  if [[ -d "$sdk_dir" ]]; then
    local found
    for dir in "$sdk_dir"/tornadovm-*; do
      if [[ -d "$dir" && -f "$dir/etc/tornado.backend" ]]; then
        echo "$dir"
        return 0
      fi
    done
  fi

  return 1
}

download_models() {
  log "Downloading models..."

  "$SCRIPT_DIR/download-models.sh" --all

  success "Models downloaded"
}

# ============================================================
# Benchmark Functions
# ============================================================

# Results stored in a temp file (Bash 3 compatible, no associative arrays)
RESULTS_TMP=""

init_results() {
  RESULTS_TMP="$OUTPUT_DIR/.results_tmp_${TIMESTAMP}"
  : > "$RESULTS_TMP"
}

set_result() {
  local name="$1"
  local status="$2"
  echo "${name}|${status}" >> "$RESULTS_TMP"
}

run_demo() {
  local name="$1"
  local command="$2"
  local requires_gpu="${3:-false}"
  local timeout="${4:-300}"

  # Skip based on mode
  if [[ "$CPU_ONLY" == "true" ]] && [[ "$requires_gpu" == "true" ]]; then
    warn "Skipping $name (CPU-only mode)"
    set_result "$name" "SKIPPED (CPU-only mode)"
    return 0
  fi

  if [[ "$GPU_ONLY" == "true" ]] && [[ "$requires_gpu" != "true" ]]; then
    warn "Skipping $name (GPU-only mode)"
    set_result "$name" "SKIPPED (GPU-only mode)"
    return 0
  fi

  # Check GPU requirement
  if [[ "$requires_gpu" == "true" ]] && [[ "$HAS_NVIDIA_GPU" != "true" ]]; then
    warn "Skipping $name (requires NVIDIA GPU)"
    set_result "$name" "SKIPPED (no GPU)"
    return 0
  fi

  echo ""
  echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC} Running: ${YELLOW}$name${NC}"
  echo -e "${CYAN}│${NC} Command: $command"
  echo -e "${CYAN}│${NC} Timeout: ${timeout}s"
  echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"

  local start_time=$(date +%s)
  local output_file="$OUTPUT_DIR/${name// /_}_${TIMESTAMP}.log"

  # Run command with timeout - use tee to show output AND save to file
  # Use gtimeout on macOS, timeout on Linux
  local timeout_cmd="timeout"
  if [[ "$OS_NAME" == "Darwin" ]]; then
    timeout_cmd="gtimeout"
  fi

  set +e
  # Use </dev/null to prevent Gradle daemon from waiting on stdin
  $timeout_cmd "$timeout" bash -c "$command" </dev/null 2>&1 | tee "$output_file"
  local exit_code=${PIPESTATUS[0]}
  set -e

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  echo ""
  if [[ $exit_code -eq 0 ]]; then
    success "$name completed in ${duration}s"

    # Extract tokens/sec if present (handles "Tokens/sec: X" and "X tokens/s" formats)
    local toks=$(grep -oE "([0-9]+\.?[0-9]*) (tokens?/s|tok/s)|Tokens/sec: ([0-9]+\.?[0-9]*)" "$output_file" | tail -1 | grep -oE "[0-9]+\.?[0-9]+" || echo "")
    if [[ -n "$toks" ]]; then
      set_result "$name" "SUCCESS: ${duration}s, ${toks} tok/s"
    else
      set_result "$name" "SUCCESS: ${duration}s"
    fi
  elif [[ $exit_code -eq 124 ]]; then
    error "$name TIMED OUT after ${timeout}s"
    set_result "$name" "TIMEOUT"
    echo -e "${RED}Last 20 lines of output:${NC}"
    tail -20 "$output_file"
  else
    error "$name FAILED with exit code $exit_code"
    set_result "$name" "FAILED (exit $exit_code)"
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

  # Initialize results storage
  init_results

  # 1. TensorFlow FFM - DISABLED (hangs on Gradle dependency resolution)
  # run_demo "TensorFlow FFM" \
  #   "./gradlew :demos:tensorflow-ffm:runTensorFlow --no-daemon --console=plain --info" \
  #   false 600
  warn "Skipping TensorFlow FFM (disabled - dependency issues)"
  set_result "TensorFlow FFM" "SKIPPED (disabled)"

  # 2. JCuda - DISABLED (requires NVIDIA GPU with CUDA)
  # run_demo "JCuda" \
  #   "./gradlew :demos:jcuda:run --no-daemon --console=plain --info" \
  #   true 600
  warn "Skipping JCuda (disabled - requires NVIDIA CUDA)"
  set_result "JCuda" "SKIPPED (disabled)"

  # 3. GraalPy Java Host
  run_demo "GraalPy Java Host" \
    "./gradlew :demos:graalpy-java-host:run --no-daemon --console=plain --info" \
    false 600

  # 4. java-llama.cpp
  run_demo "java-llama.cpp" \
    "./gradlew :demos:java-llama-cpp:run --no-daemon --console=plain --info" \
    false 600

  # 5. Llama3.java
  run_demo "Llama3.java" \
    "./demos/llama3-java/scripts/run-llama3.sh --prompt 'Tell me a short joke about programming'" \
    false 600

  # 6. llama-cpp-python (CPython) - disabled by default, use --run-py-baseline to enable
  if [[ "$RUN_PY_BASELINE" == "true" ]]; then
    # Try venv first, then system Python, or install on-demand
    local python_cmd=""
    if [[ -f "$PROJECT_DIR/.venv/bin/activate" ]]; then
      source "$PROJECT_DIR/.venv/bin/activate"
      python_cmd="python3"
    elif python3 -c "import llama_cpp" 2>/dev/null; then
      # System Python has llama-cpp-python
      python_cmd="python3"
    else
      # Try to install llama-cpp-python
      log "Installing llama-cpp-python..."
      if pip3 install llama-cpp-python --quiet 2>/dev/null; then
        python_cmd="python3"
      fi
    fi

    if [[ -n "$python_cmd" ]]; then
      run_demo "llama-cpp-python" \
        "$python_cmd $PROJECT_DIR/demos/graalpy-llama/llama_inference.py --prompt 'Tell me a short joke about programming'" \
        false 600
      deactivate 2>/dev/null || true
    else
      warn "Skipping llama-cpp-python (not installed)"
      set_result "llama-cpp-python" "SKIPPED (not installed)"
    fi
  else
    warn "Skipping llama-cpp-python (use --run-py-baseline to enable)"
    set_result "llama-cpp-python" "SKIPPED (use --run-py-baseline)"
  fi

  # 7. TornadoVM Baseline (CPU) - DISABLED (requires GCC 13+ / Ubuntu 24.04+)
  # run_demo "TornadoVM Baseline (CPU)" \
  #   "$PROJECT_DIR/tornadovm-demo/scripts/run-baseline.sh --size 10000000 --iters 3" \
  #   false 600
  warn "Skipping TornadoVM Baseline (disabled - requires GCC 13+)"
  set_result "TornadoVM Baseline (CPU)" "SKIPPED (disabled)"

  # 8. TornadoVM VectorAdd (GPU) - DISABLED (requires GCC 13+ / Ubuntu 24.04+)
  # run_demo "TornadoVM VectorAdd (GPU)" \
  #   "$PROJECT_DIR/tornadovm-demo/scripts/run-tornado.sh --size 10000000 --iters 3" \
  #   true 600
  warn "Skipping TornadoVM VectorAdd (disabled - requires GCC 13+)"
  set_result "TornadoVM VectorAdd (GPU)" "SKIPPED (disabled)"

  # 9. TornadoVM GPULlama3 - DISABLED (requires GCC 13+ / Ubuntu 24.04+)
  # run_demo "TornadoVM GPULlama3" \
  #   "$PROJECT_DIR/tornadovm-demo/scripts/run-gpullama3.sh --model $PROJECT_DIR/models/Llama-3.2-1B-Instruct-f16.gguf --prompt 'Tell me a joke'" \
  #   true 600
  warn "Skipping TornadoVM GPULlama3 (disabled - requires GCC 13+)"
  set_result "TornadoVM GPULlama3" "SKIPPED (disabled)"
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

  # Read results from temp file
  while IFS='|' read -r demo status; do
    echo "| $demo | $status |" >> "$RESULTS_FILE"
  done < "$RESULTS_TMP"

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
  while IFS='|' read -r demo status; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo "," >> "$JSON_FILE"
    fi
    echo -n "    \"$demo\": \"$status\"" >> "$JSON_FILE"
  done < "$RESULTS_TMP"
  echo "" >> "$JSON_FILE"
  echo "  }" >> "$JSON_FILE"
  echo "}" >> "$JSON_FILE"

  # Cleanup temp file
  rm -f "$RESULTS_TMP"

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

# Create output directory and set up logging to BOTH terminal and file
mkdir -p "$OUTPUT_DIR"
RUN_LOG="$OUTPUT_DIR/run_$(date +%Y%m%d_%H%M%S).log"

# Use exec to redirect all output to both terminal and log file
exec > >(tee -a "$RUN_LOG") 2>&1

echo "=== Benchmark run started at $(date) ==="
echo "=== Full output will be saved to: $RUN_LOG ==="
echo ""

main "$@"

echo ""
echo "=== Benchmark run completed at $(date) ==="
echo "=== Full log saved to: $RUN_LOG ==="

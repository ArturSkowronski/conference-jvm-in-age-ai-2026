#!/usr/bin/env bash
#
# Run benchmarks on provisioned AWS EC2 instance
#
# Usage:
#   ./scripts/cloud/aws-run.sh [OPTIONS]
#
# Options:
#   --ip IP           Override instance IP (default: from state file)
#   --key KEY         SSH key file (default: from state file)
#   --skip-clone      Don't clone/update repo
#   --skip-download   Skip model download
#   --cpu-only        Only run CPU demos
#   --help            Show this help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
STATE_FILE="$PROJECT_DIR/.cloud-instance-state"
RESULTS_DIR="$PROJECT_DIR/benchmark-results"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }

# Defaults
SKIP_CLONE=false
SKIP_DOWNLOAD=false
CPU_ONLY=false

# Load state
if [[ -f "$STATE_FILE" ]]; then
  source "$STATE_FILE"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --ip) PUBLIC_IP="$2"; shift 2 ;;
    --key) KEY_FILE="$2"; shift 2 ;;
    --skip-clone) SKIP_CLONE=true; shift ;;
    --skip-download) SKIP_DOWNLOAD=true; shift ;;
    --cpu-only) CPU_ONLY=true; shift ;;
    --help)
      echo "Run benchmarks on AWS EC2 instance"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --ip IP           Instance IP address"
      echo "  --key KEY         SSH key file path"
      echo "  --skip-clone      Don't clone/update repo"
      echo "  --skip-download   Skip model download"
      echo "  --cpu-only        Only run CPU demos"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [[ -z "${PUBLIC_IP:-}" ]]; then
  echo "Error: No instance IP. Run aws-provision.sh first or use --ip"
  exit 1
fi

if [[ -z "${KEY_FILE:-}" ]]; then
  KEY_FILE="$HOME/.ssh/jvm-ai-benchmark.pem"
fi

SSH_CMD="ssh -o StrictHostKeyChecking=no -i $KEY_FILE ubuntu@$PUBLIC_IP"

log "Connecting to $PUBLIC_IP..."

# Create remote benchmark script
REMOTE_SCRIPT=$(cat << 'REMOTE_EOF'
#!/bin/bash
set -e

echo "============================================================"
echo "JVM AI Benchmark - Remote Execution"
echo "============================================================"
echo ""

# Source SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# Check NVIDIA
echo "GPU Status:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "No NVIDIA GPU detected"
echo ""

# Navigate to project
cd ~/jvm-ai-benchmark

# Run the benchmark
./scripts/run-cloud-benchmark.sh $BENCHMARK_ARGS

echo ""
echo "============================================================"
echo "Benchmark Complete!"
echo "============================================================"
REMOTE_EOF
)

# Build benchmark args
BENCHMARK_ARGS=""
[[ "$SKIP_DOWNLOAD" == "true" ]] && BENCHMARK_ARGS="$BENCHMARK_ARGS --skip-download"
[[ "$CPU_ONLY" == "true" ]] && BENCHMARK_ARGS="$BENCHMARK_ARGS --cpu-only"

# Clone or update repo
if [[ "$SKIP_CLONE" != "true" ]]; then
  log "Setting up repository on remote..."
  $SSH_CMD << EOF
    if [[ -d ~/jvm-ai-benchmark ]]; then
      cd ~/jvm-ai-benchmark && git pull
    else
      git clone https://github.com/YOUR_USERNAME/conference-jvm-in-age-ai-2026.git ~/jvm-ai-benchmark
    fi
EOF
fi

# Run benchmark
log "Running benchmarks..."
$SSH_CMD "BENCHMARK_ARGS='$BENCHMARK_ARGS' bash -s" << EOF
$REMOTE_SCRIPT
EOF

# Download results
log "Downloading results..."
mkdir -p "$RESULTS_DIR"
scp -o StrictHostKeyChecking=no -i "$KEY_FILE" \
  "ubuntu@$PUBLIC_IP:~/jvm-ai-benchmark/benchmark-results/*" \
  "$RESULTS_DIR/" 2>/dev/null || warn "No results to download"

success "Results saved to: $RESULTS_DIR"

echo ""
echo "============================================================"
echo "Benchmark Run Complete"
echo "============================================================"
echo ""
echo "Results: $RESULTS_DIR"
echo ""
echo "Don't forget to terminate the instance:"
echo "  ./scripts/cloud/aws-terminate.sh"
echo ""

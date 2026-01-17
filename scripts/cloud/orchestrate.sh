#!/usr/bin/env bash
#
# Full Cloud Benchmark Orchestration
#
# This script handles the complete benchmark workflow:
#   1. Provision cloud instance (AWS EC2 Spot)
#   2. Clone repository and download models
#   3. Run all benchmarks
#   4. Collect results
#   5. Terminate instance
#
# Usage:
#   ./scripts/cloud/orchestrate.sh [OPTIONS]
#
# Options:
#   --provider PROVIDER   Cloud provider: aws, runpod (default: aws)
#   --instance-type TYPE  Instance type (default: g4dn.xlarge)
#   --region REGION       AWS region (default: us-east-1)
#   --keep-instance       Don't terminate after benchmarks
#   --cpu-only            Only run CPU demos (no GPU required)
#   --dry-run             Show what would be done
#   --help                Show this help
#
# Examples:
#   # Full benchmark on AWS (recommended)
#   ./scripts/cloud/orchestrate.sh
#
#   # CPU-only on cheaper instance
#   ./scripts/cloud/orchestrate.sh --cpu-only --instance-type t3.xlarge
#
#   # Keep instance for debugging
#   ./scripts/cloud/orchestrate.sh --keep-instance
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Defaults
PROVIDER="aws"
INSTANCE_TYPE="g4dn.xlarge"
AWS_REGION="${AWS_REGION:-us-east-1}"
KEEP_INSTANCE=false
CPU_ONLY=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --provider) PROVIDER="$2"; shift 2 ;;
    --instance-type) INSTANCE_TYPE="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    --keep-instance) KEEP_INSTANCE=true; shift ;;
    --cpu-only) CPU_ONLY=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help)
      echo "Full Cloud Benchmark Orchestration"
      echo ""
      echo "This script handles the complete benchmark workflow:"
      echo "  1. Provision cloud instance (AWS EC2 Spot)"
      echo "  2. Clone repository and download models"
      echo "  3. Run all benchmarks"
      echo "  4. Collect results"
      echo "  5. Terminate instance"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --provider PROVIDER   Cloud provider: aws, runpod (default: aws)"
      echo "  --instance-type TYPE  Instance type (default: g4dn.xlarge)"
      echo "  --region REGION       AWS region (default: us-east-1)"
      echo "  --keep-instance       Don't terminate after benchmarks"
      echo "  --cpu-only            Only run CPU demos (no GPU required)"
      echo "  --dry-run             Show what would be done"
      echo ""
      echo "Examples:"
      echo "  ./scripts/cloud/orchestrate.sh                     # Full benchmark"
      echo "  ./scripts/cloud/orchestrate.sh --cpu-only          # CPU demos only"
      echo "  ./scripts/cloud/orchestrate.sh --keep-instance     # Debug mode"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"; exit 1; }
step() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

# Cleanup on exit
cleanup() {
  if [[ "$KEEP_INSTANCE" != "true" && -f "$PROJECT_DIR/.cloud-instance-state" ]]; then
    warn "Cleaning up instance..."
    "$SCRIPT_DIR/aws-terminate.sh" --force 2>/dev/null || true
  fi
}

# Estimate costs
estimate_cost() {
  local hours="${1:-1}"
  local spot_price

  case "$INSTANCE_TYPE" in
    g4dn.xlarge)  spot_price="0.16" ;;
    g4dn.2xlarge) spot_price="0.23" ;;
    g5.xlarge)    spot_price="0.40" ;;
    t3.xlarge)    spot_price="0.05" ;;
    t3.2xlarge)   spot_price="0.10" ;;
    *)            spot_price="0.50" ;;
  esac

  echo "$spot_price"
}

print_header() {
  echo ""
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}     JVM AI Benchmark - Cloud Orchestration                 ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Provider:      $PROVIDER"
  echo "Instance:      $INSTANCE_TYPE"
  echo "Region:        $AWS_REGION"
  echo "Mode:          $([ "$CPU_ONLY" == "true" ] && echo "CPU only" || echo "Full (GPU + CPU)")"
  echo "Keep instance: $KEEP_INSTANCE"
  echo "Est. cost:     ~\$$(estimate_cost)/hr (spot)"
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN MODE - No changes will be made]${NC}"
    echo ""
  fi
}

run_aws() {
  step "Step 1/5: Provisioning AWS EC2 Instance"

  local provision_args="--instance-type $INSTANCE_TYPE --region $AWS_REGION"
  [[ "$DRY_RUN" == "true" ]] && provision_args="$provision_args --dry-run"

  "$SCRIPT_DIR/aws-provision.sh" $provision_args

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY RUN] Would wait for instance..."
    return
  fi

  # Load state
  source "$PROJECT_DIR/.cloud-instance-state"

  step "Step 2/5: Waiting for Instance Initialization"

  log "Waiting for instance to be fully ready (CUDA, Java, etc.)..."
  local max_wait=300
  local waited=0

  while [[ $waited -lt $max_wait ]]; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
         -i "$KEY_FILE" "ubuntu@$PUBLIC_IP" \
         "command -v nvidia-smi && command -v java" &>/dev/null; then
      success "Instance is ready!"
      break
    fi
    sleep 10
    waited=$((waited + 10))
    echo -n "."
  done
  echo ""

  step "Step 3/5: Cloning Repository"

  ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" "ubuntu@$PUBLIC_IP" << 'EOF'
    set -e
    if [[ -d ~/jvm-ai-benchmark ]]; then
      cd ~/jvm-ai-benchmark && git pull
    else
      git clone https://github.com/YOUR_USERNAME/conference-jvm-in-age-ai-2026.git ~/jvm-ai-benchmark
    fi
EOF

  # Or upload current project
  log "Uploading current project..."
  rsync -avz --progress \
    -e "ssh -o StrictHostKeyChecking=no -i $KEY_FILE" \
    --exclude '.git' \
    --exclude 'build' \
    --exclude '.gradle' \
    --exclude 'benchmark-results' \
    --exclude '.venv' \
    --exclude '*.gguf' \
    "$PROJECT_DIR/" "ubuntu@$PUBLIC_IP:~/jvm-ai-benchmark/"

  step "Step 4/5: Running Benchmarks"

  local benchmark_args="--skip-setup"
  [[ "$CPU_ONLY" == "true" ]] && benchmark_args="$benchmark_args --cpu-only"

  ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" "ubuntu@$PUBLIC_IP" << EOF
    set -e
    cd ~/jvm-ai-benchmark

    # Source SDKMAN
    export SDKMAN_DIR="\$HOME/.sdkman"
    [[ -s "\$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "\$SDKMAN_DIR/bin/sdkman-init.sh"

    # Ensure Java is available
    sdk use java 21.0.5-graalce 2>/dev/null || sdk install java 21.0.5-graalce

    # Run benchmarks
    chmod +x ./scripts/run-cloud-benchmark.sh
    ./scripts/run-cloud-benchmark.sh $benchmark_args
EOF

  step "Step 5/5: Collecting Results"

  mkdir -p "$PROJECT_DIR/benchmark-results"
  scp -o StrictHostKeyChecking=no -i "$KEY_FILE" \
    "ubuntu@$PUBLIC_IP:~/jvm-ai-benchmark/benchmark-results/*" \
    "$PROJECT_DIR/benchmark-results/" 2>/dev/null || warn "No results to download"

  success "Results saved to: $PROJECT_DIR/benchmark-results/"

  # Terminate if not keeping
  if [[ "$KEEP_INSTANCE" != "true" ]]; then
    step "Terminating Instance"
    "$SCRIPT_DIR/aws-terminate.sh" --force
  else
    echo ""
    echo -e "${YELLOW}Instance kept running. Don't forget to terminate:${NC}"
    echo "  ./scripts/cloud/aws-terminate.sh"
    echo ""
    echo "SSH access:"
    echo "  ssh -i $KEY_FILE ubuntu@$PUBLIC_IP"
    echo ""
  fi
}

run_runpod() {
  echo ""
  echo "RunPod Manual Setup Instructions"
  echo "================================="
  echo ""
  echo "1. Go to https://runpod.io and sign in"
  echo ""
  echo "2. Click 'Deploy' and select:"
  echo "   - GPU: RTX A5000 (\$0.29/hr) or RTX 4090 (\$0.44/hr)"
  echo "   - Template: PyTorch 2.1 (has CUDA pre-installed)"
  echo "   - Disk: 50 GB"
  echo ""
  echo "3. Once running, click 'Connect' and open SSH terminal (or use SSH command)"
  echo ""
  echo "4. In the terminal, run:"
  echo "   # Install prerequisites"
  echo "   apt-get update && apt-get install -y git curl unzip bc"
  echo ""
  echo "   # Install GraalVM CE 21"
  echo "   cd /workspace"
  echo "   curl -sLO https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-21.0.2/graalvm-community-jdk-21.0.2_linux-x64_bin.tar.gz"
  echo "   tar -xzf graalvm-community-jdk-21.0.2_linux-x64_bin.tar.gz"
  echo "   export JAVA_HOME=/workspace/graalvm-community-openjdk-21.0.2+13.1"
  echo "   export PATH=\$JAVA_HOME/bin:\$PATH"
  echo ""
  echo "   # Clone and run"
  echo "   git clone https://github.com/YOUR_USERNAME/conference-jvm-in-age-ai-2026.git"
  echo "   cd conference-jvm-in-age-ai-2026"
  echo "   chmod +x ./scripts/run-cloud-benchmark.sh"
  echo "   ./scripts/run-cloud-benchmark.sh --skip-setup"
  echo ""
  echo "5. Download results and STOP the pod when done to avoid charges"
  echo ""
}

print_summary() {
  echo ""
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}     Benchmark Complete!                                     ${GREEN}║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  if [[ -d "$PROJECT_DIR/benchmark-results" ]]; then
    echo "Results:"
    ls -la "$PROJECT_DIR/benchmark-results/"*.md 2>/dev/null | head -5
    echo ""
    echo "View latest results:"
    local latest=$(ls -t "$PROJECT_DIR/benchmark-results/"*.md 2>/dev/null | head -1)
    if [[ -n "$latest" ]]; then
      echo "  cat $latest"
    fi
  fi
  echo ""
}

main() {
  print_header

  # Set up cleanup trap
  trap cleanup EXIT

  case "$PROVIDER" in
    aws)
      run_aws
      ;;
    runpod)
      run_runpod
      exit 0
      ;;
    *)
      error "Unknown provider: $PROVIDER. Use 'aws' or 'runpod'"
      ;;
  esac

  print_summary
}

main "$@"

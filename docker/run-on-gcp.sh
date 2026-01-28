#!/usr/bin/env bash
#
# Deploy and run JVM AI benchmarks on a GCP VM with NVIDIA GPU.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - GPU quota granted in your GCP project (request at:
#     https://console.cloud.google.com/iam-admin/quotas)
#   - A git remote URL for this repo (or we push the Docker image)
#
# Usage:
#   ./docker/run-on-gcp.sh                    # Create VM, run benchmarks, fetch results
#   ./docker/run-on-gcp.sh --delete            # Delete the VM when done
#   ./docker/run-on-gcp.sh --zone us-west1-b   # Use a different zone
#   GCP_PROJECT=my-project ./docker/run-on-gcp.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Configuration (override via env vars) ───────────────────────────────────
VM_NAME="${VM_NAME:-jvm-ai-benchmark}"
ZONE="${ZONE:-us-central1-a}"
MACHINE_TYPE="${MACHINE_TYPE:-n1-standard-4}"
GPU_TYPE="${GPU_TYPE:-nvidia-tesla-t4}"
GPU_COUNT="${GPU_COUNT:-1}"
BOOT_DISK_SIZE="${BOOT_DISK_SIZE:-100GB}"
GCP_PROJECT="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null || echo "")}"
DELETE_AFTER="${DELETE_AFTER:-false}"
REPO_URL="${REPO_URL:-}"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --delete)       DELETE_AFTER=true; shift ;;
    --zone)         ZONE="$2"; shift 2 ;;
    --machine-type) MACHINE_TYPE="$2"; shift 2 ;;
    --gpu)          GPU_TYPE="$2"; shift 2 ;;
    --project)      GCP_PROJECT="$2"; shift 2 ;;
    --repo)         REPO_URL="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--delete] [--zone ZONE] [--gpu GPU_TYPE] [--project PROJECT] [--repo REPO_URL]"
      echo ""
      echo "Defaults: $MACHINE_TYPE + $GPU_TYPE in $ZONE (spot/preemptible)"
      echo ""
      echo "GPU types: nvidia-tesla-t4 (~\$0.17/hr spot), nvidia-l4 (~\$0.25/hr spot)"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$GCP_PROJECT" ]]; then
  echo "Error: No GCP project set. Run: gcloud config set project YOUR_PROJECT"
  exit 1
fi

echo "============================================================"
echo "  JVM AI Benchmark — GCP Deployment"
echo "============================================================"
echo "  Project:  $GCP_PROJECT"
echo "  VM:       $VM_NAME"
echo "  Zone:     $ZONE"
echo "  Machine:  $MACHINE_TYPE + $GPU_TYPE x${GPU_COUNT}"
echo "  Disk:     $BOOT_DISK_SIZE"
echo "  Spot:     yes"
echo "============================================================"
echo ""

# ── Step 1: Create VM ──────────────────────────────────────────────────────
echo ">>> Creating GCP VM..."

# Use Deep Learning VM image (CUDA + Docker pre-installed)
gcloud compute instances create "$VM_NAME" \
  --project="$GCP_PROJECT" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --accelerator="type=$GPU_TYPE,count=$GPU_COUNT" \
  --maintenance-policy=TERMINATE \
  --boot-disk-size="$BOOT_DISK_SIZE" \
  --boot-disk-type=pd-ssd \
  --image-family=common-cu128-ubuntu-2204-nvidia-570 \
  --image-project=deeplearning-platform-release \
  --provisioning-model=SPOT \
  --scopes=default,storage-ro \
  --metadata=install-nvidia-driver=True

echo ""
echo ">>> Waiting for VM to be ready..."
sleep 30

# Wait for SSH to become available
for i in $(seq 1 20); do
  if gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT" \
       --command="echo ready" 2>/dev/null; then
    break
  fi
  echo "  Waiting for SSH... (attempt $i/20)"
  sleep 15
done

# ── Step 2: Setup and run on VM ────────────────────────────────────────────
echo ""
echo ">>> Setting up benchmark on VM..."

# Determine how to get the code onto the VM
if [[ -n "$REPO_URL" ]]; then
  CLONE_CMD="git clone --depth 1 '$REPO_URL' ~/benchmark"
else
  # Try to detect git remote
  DETECTED_REMOTE=$(cd "$PROJECT_DIR" && git remote get-url origin 2>/dev/null || echo "")
  if [[ -n "$DETECTED_REMOTE" ]]; then
    CLONE_CMD="git clone --depth 1 '$DETECTED_REMOTE' ~/benchmark"
  else
    echo "Error: No --repo URL provided and no git remote detected."
    echo "Either push your code to a remote or provide --repo URL."
    exit 1
  fi
fi

gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT" --command="$(cat <<REMOTE_SCRIPT
set -euo pipefail

echo '>>> Verifying GPU...'
nvidia-smi || { echo 'GPU not ready yet'; exit 1; }

echo '>>> Installing Docker...'
if ! command -v docker &>/dev/null; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || true
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io
  sudo systemctl start docker
  sudo systemctl enable docker
fi

echo '>>> Installing nvidia-container-toolkit...'
if ! command -v nvidia-ctk &>/dev/null; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null || true
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
fi

echo '>>> Cloning project...'
$CLONE_CMD

echo '>>> Building Docker image (this will take a while on first run)...'
cd ~/benchmark
sudo docker build -t jvm-ai-benchmark -f docker/Dockerfile .

echo '>>> Running benchmarks...'
mkdir -p ~/models ~/results
sudo docker run --rm --gpus all \
  -v ~/models:/models \
  -v ~/results:/results \
  jvm-ai-benchmark

echo '>>> Benchmarks complete!'
REMOTE_SCRIPT
)"

# ── Step 3: Fetch results ──────────────────────────────────────────────────
echo ""
echo ">>> Downloading results..."

mkdir -p "$PROJECT_DIR/benchmark-results/gcp"
gcloud compute scp --recurse --zone="$ZONE" --project="$GCP_PROJECT" \
  "$VM_NAME":~/results/* \
  "$PROJECT_DIR/benchmark-results/gcp/"

echo ""
echo ">>> Results saved to: benchmark-results/gcp/"
ls -la "$PROJECT_DIR/benchmark-results/gcp/"

# ── Step 4: Optionally delete VM ───────────────────────────────────────────
if [[ "$DELETE_AFTER" == "true" ]]; then
  echo ""
  echo ">>> Deleting VM..."
  gcloud compute instances delete "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT" --quiet
  echo ">>> VM deleted."
else
  echo ""
  echo ">>> VM is still running: $VM_NAME"
  echo "    SSH:    gcloud compute ssh $VM_NAME --zone=$ZONE"
  echo "    Delete: gcloud compute instances delete $VM_NAME --zone=$ZONE"
  echo ""
  HOURLY_COST="~\$0.35/hr"
  echo "    Estimated cost: $HOURLY_COST (spot). Remember to delete when done!"
fi

echo ""
echo "Done!"

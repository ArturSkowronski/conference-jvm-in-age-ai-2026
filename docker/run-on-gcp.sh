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

echo '>>> Installing JDK and build tools for non-Docker benchmarks...'
sudo apt-get install -y -qq software-properties-common cmake maven ocl-icd-libopencl1 clinfo
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get update -qq
sudo apt-get install -y -qq gcc-13 g++-13 libstdc++6

# Download JDK 25 and GraalVM 21
mkdir -p ~/jdks
if [ ! -d ~/jdks/jdk-25 ]; then
  curl -fL -o /tmp/jdk-25.tar.gz "https://api.adoptium.net/v3/binary/latest/25/ea/linux/x64/jdk/hotspot/normal/eclipse"
  mkdir -p ~/jdks/jdk-25 && tar -xzf /tmp/jdk-25.tar.gz --strip-components=1 -C ~/jdks/jdk-25
  rm /tmp/jdk-25.tar.gz
fi
if [ ! -d ~/jdks/graalvm-21 ]; then
  curl -fL -o /tmp/graalvm-21.tar.gz "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_linux-x64_bin.tar.gz"
  mkdir -p ~/jdks/graalvm-21 && tar -xzf /tmp/graalvm-21.tar.gz --strip-components=1 -C ~/jdks/graalvm-21
  rm /tmp/graalvm-21.tar.gz
fi

export JAVA_HOME=~/jdks/jdk-25
export JDK_21=~/jdks/graalvm-21
export PATH="\$JAVA_HOME/bin:\$PATH"

# Download TornadoVM OpenCL SDK
if [ ! -d ~/tornadovm ]; then
  curl -fL -o /tmp/tornadovm.tar.gz "https://github.com/beehive-lab/TornadoVM/releases/download/v2.2.0/tornadovm-2.2.0-opencl-linux-amd64.tar.gz"
  mkdir -p ~/tornadovm && tar -xzf /tmp/tornadovm.tar.gz -C ~/tornadovm
  rm /tmp/tornadovm.tar.gz
fi
export TORNADOVM_HOME=~/tornadovm/tornadovm-2.2.0-opencl
export TORNADOVM_BACKEND=opencl
export JVMCI_CONFIG_CHECK=ignore

# Set up OpenCL ICD for NVIDIA
sudo mkdir -p /etc/OpenCL/vendors
echo "libnvidia-opencl.so.1" | sudo tee /etc/OpenCL/vendors/nvidia.icd >/dev/null

# Build java-llama.cpp with CUDA
echo '>>> Building java-llama.cpp with CUDA support...'
if [ ! -f ~/jllama-cuda/libjllama.so ]; then
  # Ensure CUDA compiler is on PATH for cmake detection
  export PATH="/usr/local/cuda/bin:\$PATH"
  export CUDACXX=/usr/local/cuda/bin/nvcc
  git clone --depth 1 https://github.com/kherud/java-llama.cpp.git /tmp/java-llama-cpp
  cd /tmp/java-llama-cpp
  mvn compile -q
  cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
  cmake --build build --config Release -j\$(nproc)
  mkdir -p ~/jllama-cuda
  find /tmp/java-llama-cpp -name "libjllama.so" -exec cp {} ~/jllama-cuda/ \;
  cd ~/benchmark
  rm -rf /tmp/java-llama-cpp
fi
export JLLAMA_CUDA_LIB=~/jllama-cuda
export LLAMA_GPU_LAYERS=99

# Download model
echo '>>> Downloading model...'
mkdir -p ~/models ~/.llama
ln -sfn ~/models ~/.llama/models
export MODEL_PATH=~/models/Llama-3.2-1B-Instruct-f16.gguf
export LLAMA_MODEL_DIR=~/models
if [ ! -f ~/models/Llama-3.2-1B-Instruct-f16.gguf ]; then
  curl -fL --progress-bar -o ~/models/Llama-3.2-1B-Instruct-f16.gguf \
    "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"
fi

# ── Run non-Docker benchmarks ──
echo ''
echo '============================================================'
echo '  NON-DOCKER BENCHMARKS (bare metal)'
echo '============================================================'
mkdir -p ~/results/bare-metal

cd ~/benchmark
chmod +x gradlew scripts/*.sh demos/*/scripts/*.sh tornadovm-demo/scripts/*.sh 2>/dev/null || true

# Llama3.java JDK 21
echo '>>> [Bare] Llama3.java (JDK 21)...'
JAVA_HOME=\$JDK_21 ./demos/llama3-java/scripts/run-llama3.sh --max-tokens 32 2>&1 | tee ~/results/bare-metal/llama3java_jdk21.log || true

# Llama3.java JDK 25
echo '>>> [Bare] Llama3.java (JDK 25)...'
JAVA_HOME=~/jdks/jdk-25 ./demos/llama3-java/scripts/run-llama3.sh --max-tokens 32 2>&1 | tee ~/results/bare-metal/llama3java_jdk25.log || true

# java-llama.cpp with CUDA
echo '>>> [Bare] java-llama.cpp (CUDA)...'
./gradlew :demos:java-llama-cpp:run --no-daemon --console=plain 2>&1 | tee ~/results/bare-metal/java_llama_cpp_cuda.log || true

# JCuda
echo '>>> [Bare] JCuda...'
./gradlew :demos:jcuda:run --no-daemon --console=plain 2>&1 | tee ~/results/bare-metal/jcuda.log || true

# TornadoVM VectorAdd
echo '>>> [Bare] TornadoVM VectorAdd...'
JAVA_HOME=\$JDK_21 ./tornadovm-demo/scripts/run-tornado.sh --size 10000000 --iters 5 --warmup 2 2>&1 | tee ~/results/bare-metal/tornado_vectoradd.log || true

# TornadoVM GPULlama3
echo '>>> [Bare] TornadoVM GPULlama3...'
JAVA_HOME=\$JDK_21 ./tornadovm-demo/scripts/run-gpullama3.sh --model \$MODEL_PATH --prompt 'Hello' 2>&1 | tee ~/results/bare-metal/tornado_gpullama3.log || true

echo ''
echo '============================================================'
echo '  NON-DOCKER BENCHMARKS COMPLETE'
echo '============================================================'

# ── Run Docker benchmarks ──
echo ''
echo '============================================================'
echo '  DOCKER BENCHMARKS'
echo '============================================================'

echo '>>> Building Docker image (this will take a while on first run)...'
sudo docker build -t jvm-ai-benchmark -f docker/Dockerfile .

echo '>>> Running Docker benchmarks...'
mkdir -p ~/results/docker
sudo docker run --rm --gpus all \
  -v ~/models:/models \
  -v ~/results/docker:/results \
  jvm-ai-benchmark

echo '>>> All benchmarks complete!'
REMOTE_SCRIPT
)"

# ── Step 3: Fetch results ──────────────────────────────────────────────────
echo ""
echo ">>> Downloading results..."

mkdir -p "$PROJECT_DIR/benchmark-results/gcp/bare-metal" "$PROJECT_DIR/benchmark-results/gcp/docker"
gcloud compute scp --recurse --zone="$ZONE" --project="$GCP_PROJECT" \
  "$VM_NAME":~/results/bare-metal/* \
  "$PROJECT_DIR/benchmark-results/gcp/bare-metal/" 2>/dev/null || true
gcloud compute scp --recurse --zone="$ZONE" --project="$GCP_PROJECT" \
  "$VM_NAME":~/results/docker/* \
  "$PROJECT_DIR/benchmark-results/gcp/docker/" 2>/dev/null || true

echo ""
echo ">>> Results saved to: benchmark-results/gcp/"
echo "--- Bare metal results ---"
ls -la "$PROJECT_DIR/benchmark-results/gcp/bare-metal/" 2>/dev/null || echo "  (none)"
echo "--- Docker results ---"
ls -la "$PROJECT_DIR/benchmark-results/gcp/docker/" 2>/dev/null || echo "  (none)"

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

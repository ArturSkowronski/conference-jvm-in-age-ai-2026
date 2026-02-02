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

# ── Step 2: Upload and run benchmark script on VM ─────────────────────────
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

# Create the benchmark script locally
BENCHMARK_SCRIPT=$(mktemp)
cat > "$BENCHMARK_SCRIPT" <<'REMOTE_SCRIPT'
#!/bin/bash
set -euo pipefail

# Mark script as running
touch ~/benchmark_running
trap 'rm -f ~/benchmark_running' EXIT

exec > >(tee ~/benchmark.log) 2>&1

echo '>>> Verifying GPU...'
nvidia-smi || { echo 'GPU not ready yet'; exit 1; }

echo '>>> Cloning project...'
REMOTE_SCRIPT

# Append the clone command (needs variable expansion)
echo "$CLONE_CMD" >> "$BENCHMARK_SCRIPT"

cat >> "$BENCHMARK_SCRIPT" <<'REMOTE_SCRIPT'

echo '>>> Installing JDK and build tools for non-Docker benchmarks...'
sudo apt-get update -qq
sudo apt-get install -y -qq software-properties-common cmake maven \
  ocl-icd-libopencl1 ocl-icd-opencl-dev clinfo \
  libvulkan1 libvulkan-dev vulkan-tools

# Install proprietary NVIDIA driver for Vulkan support (GCP uses open kernel modules by default)
echo '>>> Installing proprietary NVIDIA driver for Vulkan support...'
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nvidia-driver-570-server 2>&1 | tail -5

# Verify Vulkan sees the NVIDIA GPU
echo '>>> Verifying Vulkan GPU detection...'
if vulkaninfo --summary 2>&1 | grep -q "PHYSICAL_DEVICE_TYPE_DISCRETE_GPU"; then
  echo '>>> SUCCESS: Vulkan sees Tesla T4 GPU - Cyfra will work!'
else
  echo '>>> WARNING: Vulkan GPU not detected - may need reboot'
fi

# Install sbt (for Cyfra)
echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list >/dev/null
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sbt.gpg 2>/dev/null || true
sudo apt-get update -qq
sudo apt-get install -y -qq sbt
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get update -qq
sudo apt-get install -y -qq gcc-13 g++-13 libstdc++6 python3-pip
pip3 install --user rich

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
export PATH="$JAVA_HOME/bin:$PATH"

# Build TornadoVM from source with OpenCL + PTX backends
if [ ! -d ~/tornadovm-src ]; then
  echo '>>> Building TornadoVM with OpenCL + PTX backends (this takes a while)...'
  git clone --depth 1 https://github.com/beehive-lab/TornadoVM.git ~/tornadovm-src
  cd ~/tornadovm-src
  export JAVA_HOME=$JDK_21
  # Build with both OpenCL and PTX backends
  # Pipe 'y' to auto-download cmake if needed
  yes y | ./bin/tornadovm-installer --jdk jdk21 --backend opencl,ptx
  cd ~/benchmark
fi
# TornadoVM installer creates output in dist/ with version/backend in path
export TORNADOVM_HOME=~/tornadovm-src/dist/tornadovm-2.2.1-dev-opencl-ptx-linux-amd64/tornadovm-2.2.1-dev-opencl-ptx
export JVMCI_CONFIG_CHECK=ignore

# Set up OpenCL ICD for NVIDIA
sudo mkdir -p /etc/OpenCL/vendors
echo "libnvidia-opencl.so.1" | sudo tee /etc/OpenCL/vendors/nvidia.icd >/dev/null

# Build java-llama.cpp with CUDA
echo '>>> Building java-llama.cpp with CUDA support...'
if [ ! -f ~/jllama-cuda/libjllama.so ]; then
  # Ensure CUDA compiler is on PATH for cmake detection
  export PATH="/usr/local/cuda/bin:$PATH"
  export CUDACXX=/usr/local/cuda/bin/nvcc
  git clone --depth 1 https://github.com/kherud/java-llama.cpp.git /tmp/java-llama-cpp
  cd /tmp/java-llama-cpp
  mvn compile -q
  cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
  cmake --build build --config Release -j$(nproc)
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
chmod +x gradlew scripts/*.sh demos/*/scripts/*.sh tornadovm-demo/scripts/*.sh cyfra-demo/scripts/*.sh 2>/dev/null || true

# Llama3.java JDK 21
echo '>>> [Bare] Llama3.java (JDK 21)...'
JAVA_HOME=$JDK_21 ./demos/llama3-java/scripts/run-llama3.sh --max-tokens 32 2>&1 | tee ~/results/bare-metal/llama3java_jdk21.log || true

# Llama3.java JDK 25
echo '>>> [Bare] Llama3.java (JDK 25)...'
JAVA_HOME=~/jdks/jdk-25 ./demos/llama3-java/scripts/run-llama3.sh --max-tokens 32 2>&1 | tee ~/results/bare-metal/llama3java_jdk25.log || true

# java-llama.cpp with CUDA
echo '>>> [Bare] java-llama.cpp (CUDA)...'
./gradlew :demos:java-llama-cpp:run --no-daemon --console=plain 2>&1 | tee ~/results/bare-metal/java_llama_cpp_cuda.log || true

# JCuda
echo '>>> [Bare] JCuda...'
./gradlew :demos:jcuda:run --no-daemon --console=plain 2>&1 | tee ~/results/bare-metal/jcuda.log || true

# TornadoVM VectorAdd (OpenCL) - device 0:0 = first backend (OpenCL)
echo '>>> [Bare] TornadoVM VectorAdd (OpenCL)...'
JAVA_HOME=$JDK_21 TORNADO_DEVICE=0:0 ./tornadovm-demo/scripts/run-tornado.sh --size 10000000 --iters 5 --warmup 2 2>&1 | tee ~/results/bare-metal/tornado_vectoradd_opencl.log || true

# TornadoVM VectorAdd (PTX/CUDA) - device 1:0 = second backend (PTX)
echo '>>> [Bare] TornadoVM VectorAdd (PTX/CUDA)...'
JAVA_HOME=$JDK_21 TORNADO_DEVICE=1:0 ./tornadovm-demo/scripts/run-tornado.sh --size 10000000 --iters 5 --warmup 2 2>&1 | tee ~/results/bare-metal/tornado_vectoradd_ptx.log || true

# TornadoVM GPULlama3 (OpenCL) - device 0:0 = first backend (OpenCL)
echo '>>> [Bare] TornadoVM GPULlama3 (OpenCL)...'
JAVA_HOME=$JDK_21 TORNADO_DEVICE=0:0 ./tornadovm-demo/scripts/run-gpullama3.sh --model $MODEL_PATH --prompt 'Hello' 2>&1 | tee ~/results/bare-metal/tornado_gpullama3_opencl.log || true

# TornadoVM GPULlama3 (PTX/CUDA) - device 1:0 = second backend (PTX)
echo '>>> [Bare] TornadoVM GPULlama3 (PTX/CUDA)...'
JAVA_HOME=$JDK_21 TORNADO_DEVICE=1:0 ./tornadovm-demo/scripts/run-gpullama3.sh --model $MODEL_PATH --prompt 'Hello' 2>&1 | tee ~/results/bare-metal/tornado_gpullama3_ptx.log || true

# Cyfra (Scala/Vulkan GPU) - requires proprietary NVIDIA driver for Vulkan
echo '>>> [Bare] Cyfra LLM (Scala/Vulkan)...'
./cyfra-demo/scripts/run-cyfra-llama.sh --model $MODEL_PATH --prompt 'Hello' --measure 2>&1 | tee ~/results/bare-metal/cyfra_llm.log || true

echo ''
echo '============================================================'
echo '  ALL BARE-METAL BENCHMARKS COMPLETE'
echo '============================================================'
echo '>>> All benchmarks complete!'
REMOTE_SCRIPT

# Upload the script to the VM
echo ">>> Uploading benchmark script to VM..."
gcloud compute scp "$BENCHMARK_SCRIPT" "$VM_NAME":~/run_benchmarks.sh \
  --zone="$ZONE" --project="$GCP_PROJECT"
rm "$BENCHMARK_SCRIPT"

# Start the benchmark script in the background using nohup
echo ">>> Starting benchmarks in background on VM..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT" \
  --command="chmod +x ~/run_benchmarks.sh && nohup ~/run_benchmarks.sh &"

# Poll for completion
echo ""
echo ">>> Waiting for benchmarks to complete (checking every 60s)..."
echo "    You can monitor progress with: gcloud compute ssh $VM_NAME --zone=$ZONE --command='tail -f ~/benchmark.log'"
echo ""

while true; do
  # Check if script is still running
  if gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT" \
       --command="test -f ~/benchmark_running" 2>/dev/null; then
    # Show last few lines of progress
    LAST_LINE=$(gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT" \
      --command="tail -1 ~/benchmark.log 2>/dev/null || echo 'Starting...'" 2>/dev/null || echo "...")
    echo "  [$(date +%H:%M:%S)] Running... Last: $LAST_LINE"
    sleep 60
  else
    echo "  [$(date +%H:%M:%S)] Benchmarks complete!"
    break
  fi
done

# Show final log output
echo ""
echo ">>> Final benchmark log:"
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT" \
  --command="tail -50 ~/benchmark.log" 2>/dev/null || true

# ── Step 3: Fetch results ──────────────────────────────────────────────────
echo ""
echo ">>> Downloading results..."

mkdir -p "$PROJECT_DIR/benchmark-results/gcp/bare-metal"
gcloud compute scp --recurse --zone="$ZONE" --project="$GCP_PROJECT" \
  "$VM_NAME":~/results/bare-metal/* \
  "$PROJECT_DIR/benchmark-results/gcp/bare-metal/" 2>/dev/null || true

echo ""
echo ">>> Results saved to: benchmark-results/gcp/bare-metal/"
ls -la "$PROJECT_DIR/benchmark-results/gcp/bare-metal/" 2>/dev/null || echo "  (none)"

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

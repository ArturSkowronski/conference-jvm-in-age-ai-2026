# Cloud Environment Analysis for JVM AI Demos

*Evaluating cloud platforms for reproducible benchmarking*

---

## Demo Requirements Summary

| Demo | JDK | GPU Required | GPU Type | Memory | Architecture |
|------|-----|--------------|----------|--------|--------------|
| TensorFlow FFM | 22+ | No | - | 4 GB | x86_64, ARM64 |
| JCuda | 21+ | **Yes** | NVIDIA + CUDA | 4 GB | x86_64 |
| GraalPy (Java Host) | 21+ (GraalVM) | No | - | 4 GB | Any |
| TornadoVM VectorAdd | 21+ | **Yes** | OpenCL/CUDA | 8 GB | x86_64 |
| TornadoVM GPULlama3 | 21+ | **Yes** | OpenCL/CUDA | 16 GB | x86_64 |
| java-llama.cpp | 21+ | Recommended | CUDA/Metal | 8 GB | x86_64, ARM64 |
| Llama3.java | 21+ | No | - | 8 GB | Any |
| llama-cpp-python | Python 3.10+ | Recommended | CUDA/Metal | 8 GB | x86_64, ARM64 |

### Critical Constraints

1. **JCuda** - NVIDIA GPU mandatory (no AMD/Intel/Apple Silicon)
2. **TornadoVM** - OpenCL or CUDA required; best with NVIDIA
3. **java-llama.cpp** - CPU works but GPU gives 4-5x speedup
4. **Model files** - Need ~3 GB disk for FP16 + Q4_0 models

---

## Cloud Platform Comparison

### Tier 1: GPU Cloud (Best for Full Demo Suite)

#### AWS EC2

| Instance | GPU | vCPU | RAM | GPU RAM | On-Demand $/hr | Spot $/hr |
|----------|-----|------|-----|---------|----------------|-----------|
| g4dn.xlarge | T4 (16GB) | 4 | 16 GB | 16 GB | $0.526 | ~$0.16 |
| g4dn.2xlarge | T4 (16GB) | 8 | 32 GB | 16 GB | $0.752 | ~$0.23 |
| g5.xlarge | A10G (24GB) | 4 | 16 GB | 24 GB | $1.006 | ~$0.40 |
| p3.2xlarge | V100 (16GB) | 8 | 61 GB | 16 GB | $3.06 | ~$0.92 |

**Pros**:
- Spot instances reduce cost by 70%
- Excellent CUDA support
- AMIs with CUDA pre-installed (Deep Learning AMI)
- ARM instances available (Graviton) for CPU-only demos

**Cons**:
- Complex IAM/VPC setup
- Spot instances can be interrupted
- GPU instances not available in all regions
- **New accounts may be blocked** - requires account verification (can take days)

**Best choice**: `g4dn.xlarge` with Spot ($0.16/hr) - if account is verified

#### Google Cloud Platform (GCE)

| Machine + GPU | GPU | vCPU | RAM | On-Demand $/hr | Spot $/hr |
|---------------|-----|------|-----|----------------|-----------|
| n1-standard-4 + T4 | T4 | 4 | 15 GB | $0.55 | ~$0.17 |
| n1-standard-8 + T4 | T4 | 8 | 30 GB | $0.73 | ~$0.22 |
| a2-highgpu-1g | A100 (40GB) | 12 | 85 GB | $3.67 | ~$1.10 |

**Pros**:
- Preemptible VMs (Spot equivalent) very cheap
- Good availability in many regions
- Deep Learning VM images with CUDA
- gcloud CLI easy to use

**Cons**:
- GPU quota needs to be requested (can take days)
- Preemptible VMs limited to 24 hours

**Best choice**: `n1-standard-4 + T4` Preemptible (~$0.17/hr)

#### Lambda Labs

| Instance | GPU | vCPU | RAM | $/hr |
|----------|-----|------|-----|------|
| gpu_1x_a10 | A10 (24GB) | 30 | 200 GB | $0.60 |
| gpu_1x_a100 | A100 (40GB) | 30 | 200 GB | $1.10 |
| gpu_1x_h100 | H100 (80GB) | 26 | 200 GB | $1.99 |

**Pros**:
- Simple pricing, no hidden costs
- Pre-installed CUDA, cuDNN, PyTorch
- SSH ready in minutes
- No complex IAM setup

**Cons**:
- Limited regions
- Often sold out
- No spot/preemptible pricing

**Best choice**: `gpu_1x_a10` ($0.60/hr) - great balance

#### RunPod

| Instance | GPU | vCPU | RAM | $/hr |
|----------|-----|------|-----|------|
| RTX 4090 | RTX 4090 (24GB) | 16 | 62 GB | $0.44 |
| RTX A5000 | A5000 (24GB) | 16 | 62 GB | $0.29 |
| A100 PCIe | A100 (40GB) | 16 | 125 GB | $0.79 |

**Pros**:
- Cheapest GPU cloud
- Pay by the minute
- Community Cloud even cheaper
- **Full CUDA support** - PyTorch template includes CUDA, cuDNN pre-installed
- No account verification delays (unlike AWS)
- Simple web UI, no IAM/VPC complexity

**Cons**:
- Availability varies
- Less enterprise features
- Community instances may be less reliable

**Best choice**: `RTX A5000` ($0.29/hr) - cheapest reliable option with full CUDA support

#### Vast.ai

| Typical Offer | GPU | RAM | $/hr |
|---------------|-----|-----|------|
| RTX 3090 | RTX 3090 (24GB) | 32-64 GB | $0.15-0.30 |
| RTX 4090 | RTX 4090 (24GB) | 64 GB | $0.30-0.50 |
| A100 | A100 (40-80GB) | 128 GB | $0.50-1.00 |

**Pros**:
- Marketplace model = lowest prices
- Good for one-off benchmarks
- Docker-based, easy templates

**Cons**:
- Variable quality/reliability
- Hosts are individuals/small providers
- Less predictable availability

**Best choice**: RTX 3090 listing (~$0.20/hr) - cheapest option

---

### Tier 2: CPU-Only Cloud (Partial Demo Suite)

These can run: TensorFlow FFM, GraalPy, Llama3.java, java-llama.cpp (CPU mode)

Cannot run: JCuda, TornadoVM GPU demos

#### GitHub Codespaces

| Machine | vCPU | RAM | $/hr (included free) |
|---------|------|-----|----------------------|
| 4-core | 4 | 16 GB | $0.36 (60 hrs/month free) |
| 8-core | 8 | 32 GB | $0.72 |
| 16-core | 16 | 64 GB | $1.44 |

**Pros**:
- Zero setup - click and go
- Pre-configured dev containers
- Git integration built-in
- 60 free hours/month

**Cons**:
- No GPU
- Limited to container environment
- Can't run all demos

**Best for**: Quick CPU-only testing, development

#### Hetzner Cloud

| Instance | vCPU | RAM | $/hr |
|----------|------|-----|------|
| CPX31 | 4 | 8 GB | $0.02 |
| CPX41 | 8 | 16 GB | $0.03 |
| CPX51 | 16 | 32 GB | $0.06 |
| CAX41 (ARM) | 16 | 32 GB | $0.04 |

**Pros**:
- Extremely cheap
- ARM instances (Ampere) available
- Fast provisioning
- European data centers

**Cons**:
- No GPU options in cloud
- Limited US presence

**Best for**: ARM testing, cheap CPU benchmarks

#### Oracle Cloud (Always Free Tier)

| Instance | Shape | vCPU | RAM | Cost |
|----------|-------|------|-----|------|
| ARM | VM.Standard.A1.Flex | Up to 4 | Up to 24 GB | **FREE** |
| x86 | VM.Standard.E2.1.Micro | 1 | 1 GB | **FREE** |

**Pros**:
- Actually free forever (not trial)
- ARM Ampere instances
- Good for Llama3.java testing

**Cons**:
- No GPU
- Limited resources
- Can be hard to get ARM allocation

**Best for**: Free ARM testing

---

## Recommendation Matrix

| Use Case | Recommended Platform | Instance | Est. Cost |
|----------|---------------------|----------|-----------|
| **Full benchmark (all demos)** | AWS EC2 Spot | g4dn.xlarge | $0.16/hr |
| **AWS blocked/new account** | RunPod | RTX A5000 | $0.29/hr |
| **Cheapest GPU** | Vast.ai | RTX 3090 | ~$0.20/hr |
| **Easiest setup** | Lambda Labs | gpu_1x_a10 | $0.60/hr |
| **CPU-only testing** | Hetzner | CPX41 | $0.03/hr |
| **Free ARM testing** | Oracle Cloud | A1.Flex | Free |
| **Quick development** | GitHub Codespaces | 4-core | Free tier |

> **Note**: New AWS accounts often require verification before launching GPU instances. If you encounter "account blocked" errors, use RunPod as the immediate alternative.

---

## Winner: AWS EC2 g4dn.xlarge Spot

For ad-hoc benchmarking with full demo coverage, **AWS EC2 g4dn.xlarge with Spot pricing** offers the best balance:

### Why AWS EC2 g4dn.xlarge?

1. **Complete coverage** - NVIDIA T4 runs all demos including JCuda and TornadoVM
2. **Cost effective** - $0.16/hr with Spot (run all demos in ~1 hour = $0.16 total)
3. **Reliable** - AWS infrastructure, low Spot interruption rate for g4dn
4. **Pre-configured** - Deep Learning AMI has CUDA, cuDNN, Docker ready
5. **Scriptable** - AWS CLI enables full automation
6. **Reproducible** - Same instance type globally available

### Runner-up: RunPod RTX A5000

**Best alternative when AWS account verification is pending or blocked:**
- $0.29/hr, pay by minute
- Web UI - no CLI/IAM setup required
- **Full CUDA support** - PyTorch template includes CUDA, cuDNN
- No account verification delays
- All GPU demos work (JCuda, TornadoVM, java-llama.cpp with GPU acceleration)
- Estimated ~$0.15-0.20 for full benchmark run

---

## Quick Start - Automated Scripts

We provide orchestration scripts that handle everything automatically.

### One-Command Full Benchmark (Recommended)

```bash
# Full automated workflow: provision → run → collect → terminate
./scripts/cloud/orchestrate.sh

# With options
./scripts/cloud/orchestrate.sh --instance-type g4dn.2xlarge  # More RAM
./scripts/cloud/orchestrate.sh --cpu-only                    # CPU demos only
./scripts/cloud/orchestrate.sh --keep-instance               # Don't terminate after
./scripts/cloud/orchestrate.sh --dry-run                     # Preview without executing
```

**What it does:**
1. Provisions AWS EC2 g4dn.xlarge Spot instance (~$0.16/hr)
2. Installs Java 21 (GraalVM), Python, CUDA drivers
3. Clones repository and downloads models
4. Runs all benchmarks
5. Collects results to `./benchmark-results/`
6. Terminates instance

**Total time:** ~30-40 minutes
**Total cost:** ~$0.10-0.15

### Step-by-Step AWS (More Control)

```bash
# Step 1: Provision instance
./scripts/cloud/aws-provision.sh
# Creates key pair, security group, launches spot instance
# Saves state to .cloud-instance-state

# Step 2: Run benchmarks
./scripts/cloud/aws-run.sh
# SSHs in, clones repo, runs benchmarks, downloads results

# Step 3: Terminate when done
./scripts/cloud/aws-terminate.sh
```

### RunPod (Simpler, No AWS Setup Required)

RunPod is the recommended alternative when AWS is unavailable. All GPU instances include **CUDA pre-installed** with the PyTorch template, supporting all GPU demos (JCuda, TornadoVM, java-llama.cpp with CUDA acceleration).

**Estimated cost**: ~$0.15-0.20 for full benchmark (~30-40 min on RTX A5000)

#### Step 1: Create Account
Go to [runpod.io](https://runpod.io) and sign up/sign in

#### Step 2: Deploy a Pod
1. Click **"Deploy"** or **"+ GPU Pod"**
2. Select GPU: **RTX A5000** ($0.29/hr) or **RTX 4090** ($0.44/hr)
3. Choose template: **PyTorch 2.0** (includes CUDA, cuDNN)
4. Set disk size: **50 GB** (needed for LLM models)
5. Click **Deploy**

#### Step 3: Connect via SSH
Once the pod is running, click **"Connect"** → **"Start Web Terminal"** or use SSH

#### Step 4: Run Benchmarks
```bash
# Install prerequisites
apt-get update && apt-get install -y git curl unzip bc

# Install GraalVM CE 21
cd /workspace
curl -sLO https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-21.0.2/graalvm-community-jdk-21.0.2_linux-x64_bin.tar.gz
tar -xzf graalvm-community-jdk-21.0.2_linux-x64_bin.tar.gz
export JAVA_HOME=/workspace/graalvm-community-openjdk-21.0.2+13.1
export PATH=$JAVA_HOME/bin:$PATH
java -version

# Clone repository
git clone https://github.com/YOUR_USERNAME/conference-jvm-in-age-ai-2026.git
cd conference-jvm-in-age-ai-2026

# Run all benchmarks (includes model download)
chmod +x ./scripts/run-cloud-benchmark.sh
./scripts/run-cloud-benchmark.sh --skip-setup
```

> **Note**: Using `--skip-setup` skips SDKMAN installation since GraalVM is already configured.

#### Step 5: Download Results & Stop Pod
- Results are saved to `./benchmark-results/`
- Download via web terminal file browser or `scp`
- **Stop the pod** when done to avoid ongoing charges

### Lambda Labs

1. Go to [lambdalabs.com](https://lambdalabs.com)
2. Launch gpu_1x_a10 ($0.60/hr)
3. SSH in and run:
```bash
git clone https://github.com/YOUR_USERNAME/conference-jvm-in-age-ai-2026.git
cd conference-jvm-in-age-ai-2026
./scripts/run-cloud-benchmark.sh
```

---

## Prerequisites for AWS Scripts

```bash
# Install AWS CLI
brew install awscli  # macOS
# or: pip install awscli

# Configure credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output (json)

# Verify
aws sts get-caller-identity
```

### Required AWS Permissions

Your IAM user/role needs:
- `ec2:RunInstances`
- `ec2:TerminateInstances`
- `ec2:DescribeInstances`
- `ec2:CreateKeyPair`
- `ec2:CreateSecurityGroup`
- `ec2:AuthorizeSecurityGroupIngress`

Or attach the `AmazonEC2FullAccess` managed policy.

---

## Estimated Benchmark Duration

| Demo | Setup | Run | Total |
|------|-------|-----|-------|
| Download models | - | 5 min | 5 min |
| TensorFlow FFM | 1 min | 1 min | 2 min |
| JCuda | 0 min | 1 min | 1 min |
| GraalPy Java Host | 1 min | 1 min | 2 min |
| TornadoVM VectorAdd | 2 min | 2 min | 4 min |
| TornadoVM GPULlama3 | 0 min | 5 min | 5 min |
| java-llama.cpp | 1 min | 3 min | 4 min |
| Llama3.java | 1 min | 3 min | 4 min |
| llama-cpp-python | 2 min | 3 min | 5 min |
| **Total** | | | **~32 min** |

**Estimated cost on g4dn.xlarge Spot: ~$0.10**

---

## Script Requirements

The `scripts/run-cloud-benchmark.sh` script should:

1. Detect environment (GPU type, CUDA version, available memory)
2. Install prerequisites (JDK 21+, SDKMAN, Python)
3. Clone/update repository
4. Download models
5. Run each demo with timing
6. Collect results to JSON/Markdown
7. Handle failures gracefully (continue on error)
8. Output summary report

See `scripts/run-cloud-benchmark.sh` for implementation.

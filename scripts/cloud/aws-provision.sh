#!/usr/bin/env bash
#
# AWS EC2 Spot Instance Provisioner for JVM AI Benchmarks
#
# Prerequisites:
#   - AWS CLI installed and configured (aws configure)
#   - SSH key pair created in AWS (or will create one)
#   - Sufficient EC2 quota for g4dn instances
#
# Usage:
#   ./scripts/cloud/aws-provision.sh [OPTIONS]
#
# Options:
#   --region REGION       AWS region (default: us-east-1)
#   --instance-type TYPE  Instance type (default: g4dn.xlarge)
#   --key-name NAME       SSH key pair name (default: jvm-ai-benchmark)
#   --spot                Use spot instance (default, ~70% cheaper)
#   --on-demand           Use on-demand instance (more reliable)
#   --dry-run             Show what would be done without executing
#   --help                Show this help
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="g4dn.xlarge"
KEY_NAME="jvm-ai-benchmark"
USE_SPOT=true
DRY_RUN=false

# Deep Learning AMI (Ubuntu 22.04) - fallback AMIs for each region
# Using function instead of associative array for bash 3.2 compatibility
get_fallback_ami() {
  local region="$1"
  case "$region" in
    us-east-1)    echo "ami-0c7217cdde317cfec" ;;
    us-east-2)    echo "ami-05fb0b8c1424f266b" ;;
    us-west-1)    echo "ami-0ce2cb35386fc22e9" ;;
    us-west-2)    echo "ami-008fe2fc65df48dac" ;;
    eu-west-1)    echo "ami-0905a3c97561e0b69" ;;
    eu-central-1) echo "ami-0faab6bdbac9486fb" ;;
    *)            echo "" ;;
  esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
STATE_FILE="$PROJECT_DIR/.cloud-instance-state"

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --region) AWS_REGION="$2"; shift 2 ;;
    --instance-type) INSTANCE_TYPE="$2"; shift 2 ;;
    --key-name) KEY_NAME="$2"; shift 2 ;;
    --spot) USE_SPOT=true; shift ;;
    --on-demand) USE_SPOT=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help)
      echo "AWS EC2 Spot Instance Provisioner"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --region REGION       AWS region (default: us-east-1)"
      echo "  --instance-type TYPE  Instance type (default: g4dn.xlarge)"
      echo "  --key-name NAME       SSH key pair name (default: jvm-ai-benchmark)"
      echo "  --spot                Use spot instance (default)"
      echo "  --on-demand           Use on-demand instance"
      echo "  --dry-run             Show what would be done"
      echo ""
      echo "Instance Recommendations:"
      echo "  g4dn.xlarge   - T4 GPU, 4 vCPU, 16GB RAM - \$0.16/hr spot"
      echo "  g4dn.2xlarge  - T4 GPU, 8 vCPU, 32GB RAM - \$0.23/hr spot"
      echo "  g5.xlarge     - A10G GPU, 4 vCPU, 16GB RAM - \$0.40/hr spot"
      exit 0
      ;;
    *) error "Unknown option: $1" ;;
  esac
done

# Check AWS CLI
check_aws_cli() {
  if ! command -v aws &> /dev/null; then
    error "AWS CLI not found. Install with: brew install awscli (macOS) or pip install awscli"
  fi

  if ! aws sts get-caller-identity &> /dev/null; then
    error "AWS CLI not configured. Run: aws configure"
  fi

  success "AWS CLI configured for account: $(aws sts get-caller-identity --query Account --output text)"
}

# Get or create SSH key pair
setup_key_pair() {
  log "Checking SSH key pair: $KEY_NAME"

  local key_file="$HOME/.ssh/${KEY_NAME}.pem"

  if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" &> /dev/null; then
    if [[ -f "$key_file" ]]; then
      success "Key pair exists: $key_file"
    else
      warn "Key pair exists in AWS but local key not found at $key_file"
      warn "You may need to delete and recreate the key pair, or use existing key"
    fi
  else
    log "Creating new key pair: $KEY_NAME"
    if [[ "$DRY_RUN" == "true" ]]; then
      log "[DRY RUN] Would create key pair: $KEY_NAME"
    else
      aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "$key_file"
      chmod 600 "$key_file"
      success "Created key pair: $key_file"
    fi
  fi

  export KEY_FILE="$key_file"
}

# Get or create security group
setup_security_group() {
  local sg_name="jvm-ai-benchmark-sg"

  log "Checking security group: $sg_name"

  local sg_id
  sg_id=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$sg_name" \
    --region "$AWS_REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "None")

  if [[ "$sg_id" != "None" && "$sg_id" != "null" && -n "$sg_id" ]]; then
    success "Security group exists: $sg_id"
  else
    log "Creating security group: $sg_name"
    if [[ "$DRY_RUN" == "true" ]]; then
      log "[DRY RUN] Would create security group: $sg_name"
      sg_id="sg-dryrun"
    else
      sg_id=$(aws ec2 create-security-group \
        --group-name "$sg_name" \
        --description "Security group for JVM AI benchmark instances" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)

      # Allow SSH
      aws ec2 authorize-security-group-ingress \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"

      success "Created security group: $sg_id"
    fi
  fi

  export SECURITY_GROUP_ID="$sg_id"
}

# Get AMI ID
get_ami_id() {
  log "Finding Ubuntu AMI for region: $AWS_REGION"

  # Use latest Ubuntu 22.04 LTS
  local ami_id
  ami_id=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --region "$AWS_REGION" \
    --output text 2>/dev/null || echo "")

  if [[ -z "$ami_id" || "$ami_id" == "None" ]]; then
    # Fallback to hardcoded AMI
    ami_id=$(get_fallback_ami "$AWS_REGION")
    if [[ -z "$ami_id" ]]; then
      error "No AMI found for region $AWS_REGION"
    fi
  fi

  success "Using AMI: $ami_id"
  export AMI_ID="$ami_id"
}

# Create user data script for instance initialization
create_user_data() {
  cat << 'USERDATA'
#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting instance initialization ==="

# Update and install basics
apt-get update
apt-get install -y git curl unzip build-essential

# Install NVIDIA drivers and CUDA (if not already present)
if ! command -v nvidia-smi &> /dev/null; then
  echo "Installing NVIDIA drivers..."
  apt-get install -y nvidia-driver-535 nvidia-cuda-toolkit
fi

# Install SDKMAN and Java
if [[ ! -d /home/ubuntu/.sdkman ]]; then
  sudo -u ubuntu bash -c 'curl -s "https://get.sdkman.io" | bash'
  sudo -u ubuntu bash -c 'source /home/ubuntu/.sdkman/bin/sdkman-init.sh && sdk install java 21.0.5-graalce'
fi

# Install Python packages
apt-get install -y python3-pip python3-venv
pip3 install llama-cpp-python

# Create ready marker
touch /home/ubuntu/.instance-ready
echo "=== Instance initialization complete ==="
USERDATA
}

# Launch instance
launch_instance() {
  log "Launching $INSTANCE_TYPE instance..."

  local user_data
  user_data=$(create_user_data | base64)

  local instance_id

  if [[ "$USE_SPOT" == "true" ]]; then
    log "Requesting Spot instance..."

    if [[ "$DRY_RUN" == "true" ]]; then
      log "[DRY RUN] Would launch spot instance: $INSTANCE_TYPE"
      instance_id="i-dryrun123"
    else
      # Launch spot instance
      instance_id=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SECURITY_GROUP_ID" \
        --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
        --user-data "$user_data" \
        --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp3"}}]' \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=jvm-ai-benchmark}]" \
        --region "$AWS_REGION" \
        --query 'Instances[0].InstanceId' \
        --output text)
    fi
  else
    log "Launching On-Demand instance..."

    if [[ "$DRY_RUN" == "true" ]]; then
      log "[DRY RUN] Would launch on-demand instance: $INSTANCE_TYPE"
      instance_id="i-dryrun123"
    else
      instance_id=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SECURITY_GROUP_ID" \
        --user-data "$user_data" \
        --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp3"}}]' \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=jvm-ai-benchmark}]" \
        --region "$AWS_REGION" \
        --query 'Instances[0].InstanceId' \
        --output text)
    fi
  fi

  success "Instance launched: $instance_id"
  export INSTANCE_ID="$instance_id"

  if [[ "$DRY_RUN" != "true" ]]; then
    # Wait for instance to be running
    log "Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids "$instance_id" --region "$AWS_REGION"
    success "Instance is running"

    # Get public IP
    local public_ip
    public_ip=$(aws ec2 describe-instances \
      --instance-ids "$instance_id" \
      --region "$AWS_REGION" \
      --query 'Reservations[0].Instances[0].PublicIpAddress' \
      --output text)

    success "Public IP: $public_ip"
    export PUBLIC_IP="$public_ip"

    # Save state
    cat > "$STATE_FILE" << EOF
INSTANCE_ID=$instance_id
PUBLIC_IP=$public_ip
AWS_REGION=$AWS_REGION
KEY_FILE=$KEY_FILE
INSTANCE_TYPE=$INSTANCE_TYPE
LAUNCHED_AT=$(date -Iseconds)
EOF

    success "State saved to: $STATE_FILE"
  fi
}

# Wait for instance to be ready
wait_for_ready() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY RUN] Would wait for instance to be ready"
    return
  fi

  log "Waiting for instance to be ready (this may take 2-5 minutes)..."

  local max_attempts=60
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY_FILE" "ubuntu@$PUBLIC_IP" \
       "test -f /home/ubuntu/.instance-ready" 2>/dev/null; then
      success "Instance is ready!"
      return 0
    fi

    attempt=$((attempt + 1))
    echo -n "."
    sleep 10
  done

  warn "Instance may not be fully ready yet. SSH should still work."
}

# Print connection info
print_info() {
  local public_ip="${PUBLIC_IP:-N/A}"

  echo ""
  echo "============================================================"
  echo "Instance Provisioned Successfully!"
  echo "============================================================"
  echo ""
  echo "Instance ID:   ${INSTANCE_ID:-N/A}"
  echo "Instance Type: $INSTANCE_TYPE"
  echo "Region:        $AWS_REGION"
  echo "Public IP:     $public_ip"
  echo "Pricing:       $([ "$USE_SPOT" == "true" ] && echo "Spot (~\$0.16/hr)" || echo "On-Demand (~\$0.53/hr)")"
  echo ""
  if [[ "$public_ip" != "N/A" ]]; then
    echo "Connect with:"
    echo "  ssh -i $KEY_FILE ubuntu@$public_ip"
    echo ""
  fi
  echo "Run benchmarks:"
  echo "  ./scripts/cloud/aws-run.sh"
  echo ""
  echo "Terminate when done:"
  echo "  ./scripts/cloud/aws-terminate.sh"
  echo ""
  echo "============================================================"
}

# Main
main() {
  echo ""
  echo "============================================================"
  echo "AWS EC2 Provisioner for JVM AI Benchmarks"
  echo "============================================================"
  echo ""

  check_aws_cli
  setup_key_pair
  setup_security_group
  get_ami_id
  launch_instance
  wait_for_ready
  print_info
}

main "$@"

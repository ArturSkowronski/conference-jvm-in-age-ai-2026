#!/usr/bin/env bash
#
# Terminate AWS EC2 benchmark instance
#
# Usage:
#   ./scripts/cloud/aws-terminate.sh [OPTIONS]
#
# Options:
#   --instance-id ID   Instance ID to terminate
#   --force            Skip confirmation
#   --help             Show this help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
STATE_FILE="$PROJECT_DIR/.cloud-instance-state"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FORCE=false

# Load state
if [[ -f "$STATE_FILE" ]]; then
  source "$STATE_FILE"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --instance-id) INSTANCE_ID="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --help)
      echo "Terminate AWS EC2 benchmark instance"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --instance-id ID   Instance ID to terminate"
      echo "  --force            Skip confirmation"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [[ -z "${INSTANCE_ID:-}" ]]; then
  echo "Error: No instance ID. Nothing to terminate."
  exit 1
fi

echo ""
echo "============================================================"
echo "Terminate AWS EC2 Instance"
echo "============================================================"
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Region:      ${AWS_REGION:-us-east-1}"
echo ""

# Confirm
if [[ "$FORCE" != "true" ]]; then
  echo -e "${YELLOW}Are you sure you want to terminate this instance?${NC}"
  read -p "Type 'yes' to confirm: " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

# Terminate
echo ""
echo "Terminating instance..."
aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "${AWS_REGION:-us-east-1}" \
  --query 'TerminatingInstances[0].CurrentState.Name' \
  --output text

# Clean up state file
rm -f "$STATE_FILE"

echo ""
echo -e "${GREEN}✓ Instance terminated${NC}"
echo ""
echo "Note: You may still be charged for a few minutes after termination."
echo "Check your AWS console to confirm: https://console.aws.amazon.com/ec2/"
echo ""

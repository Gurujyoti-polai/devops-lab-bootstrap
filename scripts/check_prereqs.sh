#!/usr/bin/env bash
set -e

# Colours
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

FAILED=0

check() {
  local name=$1
  local cmd=$2

  if eval "$cmd" &>/dev/null; then
    echo -e "${GREEN}✓${NC} $name"
  else
    echo -e "${RED}✗${NC} $name — not found or not working"
    FAILED=1
  fi
}

echo ""
echo "Checking prerequisites..."
echo "─────────────────────────"

check "OpenTofu"        "tofu version"
check "Ansible"         "ansible --version"
check "amazon.aws"      "ansible-galaxy collection list | grep amazon.aws"
check "boto3"           "python3 -c 'import boto3'"
check "Infracost"       "infracost --version"
check "Checkov"         "checkov --version"
check "jq"              "jq --version"
check "AWS CLI"         "aws --version"
check "AWS credentials" "aws sts get-caller-identity"
check "SSH key"         "test -f ~/.ssh/devops-lab.pub"

echo "─────────────────────────"

if [ $FAILED -ne 0 ]; then
  echo -e "${RED}✗ Some prerequisites are missing. Fix them before running make up.${NC}"
  exit 1
else
  echo -e "${GREEN}✓ All prerequisites satisfied.${NC}"
fi
echo ""

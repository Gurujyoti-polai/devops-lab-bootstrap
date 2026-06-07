#!/usr/bin/env bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}Estimating cost before apply...${NC}"
echo "─────────────────────────────────────────────────"

cd "$(dirname "$0")/../tofu"

infracost breakdown \
  --path . \
  --format table \
  --terraform-var "phase_name=phase-0" 2>/dev/null || \
  echo "Infracost estimate unavailable — continuing anyway."

echo "─────────────────────────────────────────────────"
echo -e "${YELLOW}⚠  NAT Gateway bills ~\$0.045/hr (~₹3.50/hr) from the moment it exists.${NC}"
echo -e "${YELLOW}   Always run 'make down' at the end of your session.${NC}"
echo ""

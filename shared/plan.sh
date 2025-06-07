#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
PLAN_FILE="tfplan-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log "Creating Terraform plan for $ENVIRONMENT environment..."

# Change to environment directory
cd "$(dirname "$0")/../environments/$ENVIRONMENT"

# Check if terraform.tfvars exists
if [[ ! -f "terraform.tfvars" ]]; then
    error "terraform.tfvars not found. Please create it with your configuration."
fi

# Run terraform plan
log "Running terraform plan..."
terraform plan -out="$PLAN_FILE" -var-file="terraform.tfvars"

success "Terraform plan created: $PLAN_FILE"
echo -e "${YELLOW}To apply this plan, run: terraform apply $PLAN_FILE${NC}"
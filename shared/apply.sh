#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
PLAN_FILE=${2:-}
AUTO_APPROVE=${3:-false}

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

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log "Applying Terraform changes for $ENVIRONMENT environment..."

# Change to environment directory
cd "$(dirname "$0")/../environments/$ENVIRONMENT"

# Apply terraform changes
if [[ -n "$PLAN_FILE" && -f "$PLAN_FILE" ]]; then
    log "Applying plan file: $PLAN_FILE"
    terraform apply "$PLAN_FILE"
    rm -f "$PLAN_FILE"
else
    log "Running terraform apply..."
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        terraform apply -auto-approve -var-file="terraform.tfvars"
    else
        terraform apply -var-file="terraform.tfvars"
    fi
fi

success "Terraform apply completed for $ENVIRONMENT"

# Show outputs
log "Terraform outputs:"
terraform output
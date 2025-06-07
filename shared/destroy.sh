#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
FORCE=${2:-false}

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

warn "This will DESTROY ALL infrastructure in the $ENVIRONMENT environment!"

if [[ "$FORCE" != "true" ]]; then
    echo -e "${RED}Are you absolutely sure? Type 'destroy-$ENVIRONMENT' to confirm:${NC}"
    read -r confirmation
    if [[ "$confirmation" != "destroy-$ENVIRONMENT" ]]; then
        error "Destruction cancelled"
    fi
fi

log "Destroying Terraform infrastructure for $ENVIRONMENT environment..."

# Change to environment directory
cd "$(dirname "$0")/../environments/$ENVIRONMENT"

# Destroy infrastructure
terraform destroy -auto-approve -var-file="terraform.tfvars"

success "Infrastructure destroyed for $ENVIRONMENT"
#!/bin/bash

set -e

ENVIRONMENT=${1:-development}
ACTION=${2:-deploy}

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

# Change to ansible directory
cd "$(dirname "$0")/../ansible"

case $ACTION in
    "infrastructure")
        log "🏗️ Setting up infrastructure for $ENVIRONMENT..."
        ansible-playbook -i inventory/$ENVIRONMENT.yml playbooks/infrastructure-setup.yml \
            --extra-vars "env=$ENVIRONMENT"
        ;;
    "security")
        log "🛡️ Applying security hardening for $ENVIRONMENT..."
        ansible-playbook -i inventory/$ENVIRONMENT.yml playbooks/security-hardening.yml \
            --extra-vars "env=$ENVIRONMENT"
        ;;
    "deploy")
        log "🚀 Deploying application to $ENVIRONMENT..."
        ansible-playbook -i inventory/$ENVIRONMENT.yml playbooks/application-deployment.yml \
            --extra-vars "env=$ENVIRONMENT"
        ;;
    "full")
        log "🎯 Full deployment to $ENVIRONMENT..."
        ansible-playbook -i inventory/$ENVIRONMENT.yml playbooks/site.yml \
            --extra-vars "env=$ENVIRONMENT setup_infrastructure=true setup_security=true deploy_application=true"
        ;;
    *)
        echo "Usage: $0 <environment> <action>"
        echo "Environments: development, staging, production"
        echo "Actions: infrastructure, security, deploy, full"
        exit 1
        ;;
esac

success "✅ $ACTION completed for $ENVIRONMENT environment"

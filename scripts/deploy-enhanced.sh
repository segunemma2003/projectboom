#!/bin/bash

# scripts/deploy-enhanced.sh - Complete deployment script for 20M+ user infrastructure

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENTS=("dev" "staging" "prod")
REGIONS=("eu-west-1" "us-east-1" "ap-southeast-1")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

progress() {
    echo -e "${PURPLE}[PROGRESS]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Enhanced Social Media Platform Deployment Script

Usage: $0 [OPTIONS] COMMAND [ENVIRONMENT]

COMMANDS:
    bootstrap           Bootstrap Terraform backend infrastructure
    plan               Plan infrastructure changes
    deploy             Deploy infrastructure
    destroy            Destroy infrastructure
    multi-region       Deploy multi-region setup
    chat-enhanced      Deploy enhanced chat infrastructure
    compliance         Deploy GDPR compliance infrastructure
    cost-optimization  Deploy cost optimization tools
    full-deploy        Complete deployment with all enhancements
    validate           Validate deployment
    rollback           Rollback to previous version

ENVIRONMENTS:
    dev, staging, prod, global

OPTIONS:
    -h, --help         Show this help message
    -v, --verbose      Enable verbose output
    -f, --force        Force deployment without confirmation
    -r, --region       Specify AWS region (default: eu-west-1)
    --skip-validation  Skip post-deployment validation
    --auto-approve     Auto-approve Terraform plans

EXAMPLES:
    $0 bootstrap                           # Bootstrap backend infrastructure
    $0 deploy dev                          # Deploy development environment
    $0 multi-region prod                   # Deploy production multi-region
    $0 full-deploy prod --auto-approve     # Complete production deployment
    $0 validate staging                    # Validate staging deployment

EOF
}

# Parse command line arguments
ENVIRONMENT=""
COMMAND=""
REGION="eu-west-1"
VERBOSE=false
FORCE=false
SKIP_VALIDATION=false
AUTO_APPROVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        bootstrap|plan|deploy|destroy|multi-region|chat-enhanced|compliance|cost-optimization|full-deploy|validate|rollback)
            COMMAND="$1"
            shift
            ;;
        dev|staging|prod|global)
            ENVIRONMENT="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validation
if [[ -z "$COMMAND" ]]; then
    error "No command specified. Use -h for help."
fi

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required tools
    local tools=("terraform" "aws" "ansible" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed or not in PATH"
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid"
    fi
    
    # Check Terraform version
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    local required_version="1.0.0"
    if ! printf '%s\n%s\n' "$required_version" "$tf_version" | sort -V -C; then
        error "Terraform version $tf_version is less than required $required_version"
    fi
    
    success "Prerequisites check passed"
}

# Bootstrap backend infrastructure
bootstrap_backend() {
    log "Bootstrapping Terraform backend infrastructure..."
    
    cd "$PROJECT_ROOT/bootstrap"
    
    terraform init
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        terraform apply -auto-approve
    else
        terraform apply
    fi
    
    # Update backend configurations
    local bucket_info=$(terraform output -json backend_info)
    
    for env in "${ENVIRONMENTS[@]}"; do
        local bucket=$(echo "$bucket_info" | jq -r ".buckets.$env")
        local table=$(echo "$bucket_info" | jq -r ".tables.$env")
        
        # Update backend.tf files
        cat > "$PROJECT_ROOT/environments/$env/backend.tf" << EOF
terraform {
  backend "s3" {
    bucket         = "$bucket"
    key            = "$env/terraform.tfstate"
    region         = "$REGION"
    encrypt        = true
    dynamodb_table = "$table"
  }
}
EOF
        success "Updated backend configuration for $env environment"
    done
    
    success "Backend infrastructure bootstrapped successfully"
}

# Deploy enhanced chat infrastructure
deploy_chat_enhanced() {
    local env="$1"
    
    log "Deploying enhanced chat infrastructure for $env..."
    
    cd "$PROJECT_ROOT/environments/$env"
    
    # Add chat module to main.tf if not present
    if ! grep -q "module \"chat\"" main.tf; then
        cat >> main.tf << 'EOF'

# Enhanced Chat Infrastructure
module "chat" {
  source = "../../modules/chat"
  
  name_prefix                = local.name_prefix
  environment               = var.environment
  aws_region               = var.aws_region
  vpc_id                   = module.networking.vpc_id
  subnet_ids               = module.networking.private_subnet_ids
  redis_realtime_endpoint  = module.redis.realtime_cluster_configuration_endpoint
  
  enable_message_ttl       = true
  lambda_reserved_concurrency = 100
  alarm_actions           = [module.alerts.topic_arn]
  
  tags = local.common_tags
}
EOF
        success "Added chat module to $env environment"
    fi
    
    terraform init
    terraform plan
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        terraform apply -auto-approve
    else
        terraform apply
    fi
    
    success "Enhanced chat infrastructure deployed for $env"
}

# Deploy multi-region setup
deploy_multi_region() {
    log "Deploying multi-region infrastructure..."
    
    cd "$PROJECT_ROOT/environments/global"
    
    terraform init
    terraform plan
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        terraform apply -auto-approve
    else
        terraform apply
    fi
    
    success "Multi-region infrastructure deployed"
}

# Deploy GDPR compliance infrastructure
deploy_compliance() {
    local env="$1"
    
    log "Deploying GDPR compliance infrastructure for $env..."
    
    cd "$PROJECT_ROOT/environments/$env"
    
    # Add compliance module if not present
    if ! grep -q "module \"compliance\"" main.tf; then
        cat >> main.tf << 'EOF'

# GDPR Compliance Infrastructure
module "compliance" {
  source = "../../modules/compliance"
  
  name_prefix                    = local.name_prefix
  environment                   = var.environment
  vpc_id                        = module.networking.vpc_id
  subnet_ids                    = module.networking.private_subnet_ids
  domain_name                   = var.domain_name
  
  s3_buckets_for_scanning       = [module.storage.media_bucket_name]
  user_data_s3_buckets         = [module.storage.media_bucket_name]
  chat_messages_table_name     = module.chat.chat_messages_table_name
  user_profiles_table_name     = "${local.name_prefix}-user-profiles"
  
  compliance_notification_emails = var.critical_alert_emails
  
  data_retention_policies = {
    chat_messages = "2years"
    user_profiles = "inactive_3years"
    audit_logs    = "7years"
    media_files   = "user_controlled"
  }
  
  tags = local.common_tags
}
EOF
        success "Added compliance module to $env environment"
    fi
    
    terraform init
    terraform plan
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        terraform apply -auto-approve
    else
        terraform apply
    fi
    
    success "GDPR compliance infrastructure deployed for $env"
}

# Deploy cost optimization
deploy_cost_optimization() {
    local env="$1"
    
    log "Deploying cost optimization infrastructure for $env..."
    
    cd "$PROJECT_ROOT/environments/$env"
    
    # Add cost optimization module if not present
    if ! grep -q "module \"cost_optimization\"" main.tf; then
        cat >> main.tf << 'EOF'

# Cost Optimization Infrastructure
module "cost_optimization" {
  source = "../../modules/cost_optimization"
  
  name_prefix               = local.name_prefix
  environment              = var.environment
  project_name             = var.project_name
  
  monthly_budget_limit     = var.environment == "production" ? 80000 : 20000
  compute_budget_limit     = var.environment == "production" ? 35000 : 8000
  database_budget_limit    = var.environment == "production" ? 25000 : 5000
  
  budget_alert_emails      = var.critical_alert_emails
  cost_alert_emails        = var.critical_alert_emails
  critical_alert_emails    = var.critical_alert_emails
  cost_anomaly_email       = var.alert_email
  
  slack_webhook_url        = var.slack_webhook_url
  autoscaling_group_name   = "" # Will be populated by ECS auto-scaling
  
  tags = local.common_tags
}
EOF
        success "Added cost optimization module to $env environment"
    fi
    
    terraform init
    terraform plan
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        terraform apply -auto-approve
    else
        terraform apply
    fi
    
    success "Cost optimization infrastructure deployed for $env"
}

# Standard deployment
deploy_environment() {
    local env="$1"
    
    if [[ -z "$env" ]]; then
        error "Environment not specified"
    fi
    
    log "Deploying $env environment..."
    
    cd "$PROJECT_ROOT/environments/$env"
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Validate configuration
    terraform validate
    
    # Plan deployment
    terraform plan -out="tfplan-$env"
    
    # Confirm deployment unless auto-approve is set
    if [[ "$AUTO_APPROVE" != "true" && "$FORCE" != "true" ]]; then
        echo -e "${YELLOW}Do you want to apply these changes to $env? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            warn "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Apply changes
    terraform apply "tfplan-$env"
    
    # Clean up plan file
    rm -f "tfplan-$env"
    
    success "$env environment deployed successfully"
}

# Full deployment with all enhancements
full_deploy() {
    local env="$1"
    
    if [[ -z "$env" ]]; then
        error "Environment not specified for full deployment"
    fi
    
    log "Starting full deployment for $env environment..."
    
    # Step 1: Deploy base infrastructure
    progress "Step 1/5: Deploying base infrastructure"
    deploy_environment "$env"
    
    # Step 2: Deploy enhanced chat
    progress "Step 2/5: Deploying enhanced chat infrastructure"
    deploy_chat_enhanced "$env"
    
    # Step 3: Deploy compliance (for staging and prod)
    if [[ "$env" != "dev" ]]; then
        progress "Step 3/5: Deploying GDPR compliance infrastructure"
        deploy_compliance "$env"
    else
        progress "Step 3/5: Skipping compliance for dev environment"
    fi
    
    # Step 4: Deploy cost optimization
    progress "Step 4/5: Deploying cost optimization"
    deploy_cost_optimization "$env"
    
    # Step 5: Deploy multi-region (for prod only)
    if [[ "$env" == "prod" ]]; then
        progress "Step 5/5: Deploying multi-region infrastructure"
        deploy_multi_region
    else
        progress "Step 5/5: Skipping multi-region for non-prod environment"
    fi
    
    success "Full deployment completed for $env environment"
    
    # Run validation unless skipped
    if [[ "$SKIP_VALIDATION" != "true" ]]; then
        validate_deployment "$env"
    fi
}

# Validate deployment
validate_deployment() {
    local env="$1"
    
    log "Validating $env deployment..."
    
    cd "$PROJECT_ROOT/environments/$env"
    
    # Get outputs
    local outputs=$(terraform output -json)
    
    # Check if outputs exist
    if [[ -z "$outputs" || "$outputs" == "{}" ]]; then
        error "No Terraform outputs found. Deployment may have failed."
    fi
    
    # Validate key infrastructure components
    local vpc_id=$(echo "$outputs" | jq -r '.vpc_id.value // empty')
    local lb_dns=$(echo "$outputs" | jq -r '.load_balancer_dns.value // empty')
    local cluster_name=$(echo "$outputs" | jq -r '.ecs_cluster_name.value // empty')
    
    if [[ -z "$vpc_id" ]]; then
        error "VPC not found in outputs"
    fi
    
    if [[ -z "$lb_dns" ]]; then
        error "Load balancer DNS not found in outputs"
    fi
    
    if [[ -z "$cluster_name" ]]; then
        error "ECS cluster name not found in outputs"
    fi
    
    # Test load balancer health
    log "Testing load balancer health..."
    if curl -f -s "https://$lb_dns/health/" > /dev/null; then
        success "Load balancer health check passed"
    else
        warn "Load balancer health check failed - this may be normal during initial deployment"
    fi
    
    # Check ECS service status
    log "Checking ECS service status..."
    local region=$(terraform output -raw aws_region 2>/dev/null || echo "$REGION")
    local services=$(aws ecs list-services --cluster "$cluster_name" --region "$region" --output json)
    local service_count=$(echo "$services" | jq '.serviceArns | length')
    
    if [[ "$service_count" -gt 0 ]]; then
        success "Found $service_count ECS services"
    else
        warn "No ECS services found"
    fi
    
    success "Validation completed for $env environment"
}

# Destroy infrastructure
destroy_environment() {
    local env="$1"
    
    if [[ -z "$env" ]]; then
        error "Environment not specified"
    fi
    
    warn "This will destroy ALL infrastructure in the $env environment!"
    
    if [[ "$FORCE" != "true" ]]; then
        echo -e "${RED}Are you ABSOLUTELY sure you want to destroy $env? Type 'yes' to confirm:${NC}"
        read -r response
        if [[ "$response" != "yes" ]]; then
            warn "Destruction cancelled"
            exit 0
        fi
    fi
    
    log "Destroying $env environment..."
    
    cd "$PROJECT_ROOT/environments/$env"
    
    terraform destroy -auto-approve
    
    success "$env environment destroyed"
}

# Rollback functionality
rollback_environment() {
    local env="$1"
    
    if [[ -z "$env" ]]; then
        error "Environment not specified"
    fi
    
    log "Rolling back $env environment..."
    
    cd "$PROJECT_ROOT/environments/$env"
    
    # Check for previous state backup
    if [[ -f "terraform.tfstate.backup" ]]; then
        log "Found previous state backup, rolling back..."
        cp terraform.tfstate.backup terraform.tfstate
        terraform apply -auto-approve
        success "Rollback completed for $env"
    else
        error "No previous state backup found. Cannot rollback."
    fi
}

# Enhanced Ansible deployment
deploy_with_ansible() {
    local env="$1"
    local action="$2"
    
    log "Running Ansible deployment for $env..."
    
    cd "$PROJECT_ROOT/ansible"
    
    # Install Ansible requirements
    ansible-galaxy collection install -r requirements.yml
    
    # Run the appropriate playbook
    case "$action" in
        "infrastructure")
            ansible-playbook -i inventory/${env}.yml playbooks/infrastructure-setup.yml \
                --extra-vars "env=$env"
            ;;
        "security")
            ansible-playbook -i inventory/${env}.yml playbooks/security-hardening.yml \
                --extra-vars "env=$env"
            ;;
        "application")
            ansible-playbook -i inventory/${env}.yml playbooks/application-deployment.yml \
                --extra-vars "env=$env"
            ;;
        "full")
            ansible-playbook -i inventory/${env}.yml playbooks/site.yml \
                --extra-vars "env=$env setup_infrastructure=true setup_security=true deploy_application=true"
            ;;
    esac
    
    success "Ansible deployment completed for $env"
}

# Generate deployment report
generate_report() {
    local env="$1"
    
    log "Generating deployment report for $env..."
    
    cd "$PROJECT_ROOT/environments/$env"
    
    local report_file="deployment-report-$env-$(date +%Y%m%d-%H%M%S).json"
    
    # Gather deployment information
    local terraform_outputs=$(terraform output -json)
    local terraform_state=$(terraform show -json)
    
    # Create report
    cat > "$report_file" << EOF
{
  "deployment_info": {
    "environment": "$env",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "region": "$REGION",
    "deployed_by": "$(whoami)",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
  },
  "terraform_outputs": $terraform_outputs,
  "resource_summary": {
    "total_resources": $(echo "$terraform_state" | jq '.values.root_module.resources | length'),
    "modules": $(echo "$terraform_state" | jq '[.values.root_module.child_modules[]?.address] | length')
  }
}
EOF
    
    success "Deployment report generated: $report_file"
}

# Main execution logic
main() {
    check_prerequisites
    
    case "$COMMAND" in
        "bootstrap")
            bootstrap_backend
            ;;
        "plan")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for plan command"
            fi
            cd "$PROJECT_ROOT/environments/$ENVIRONMENT"
            terraform init
            terraform plan
            ;;
        "deploy")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for deploy command"
            fi
            deploy_environment "$ENVIRONMENT"
            generate_report "$ENVIRONMENT"
            ;;
        "destroy")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for destroy command"
            fi
            destroy_environment "$ENVIRONMENT"
            ;;
        "multi-region")
            deploy_multi_region
            ;;
        "chat-enhanced")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for chat-enhanced command"
            fi
            deploy_chat_enhanced "$ENVIRONMENT"
            ;;
        "compliance")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for compliance command"
            fi
            deploy_compliance "$ENVIRONMENT"
            ;;
        "cost-optimization")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for cost-optimization command"
            fi
            deploy_cost_optimization "$ENVIRONMENT"
            ;;
        "full-deploy")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for full-deploy command"
            fi
            full_deploy "$ENVIRONMENT"
            generate_report "$ENVIRONMENT"
            ;;
        "validate")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for validate command"
            fi
            validate_deployment "$ENVIRONMENT"
            ;;
        "rollback")
            if [[ -z "$ENVIRONMENT" ]]; then
                error "Environment required for rollback command"
            fi
            rollback_environment "$ENVIRONMENT"
            ;;
        *)
            error "Unknown command: $COMMAND"
            ;;
    esac
}

# Run main function
main "$@"

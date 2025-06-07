# shared/init.sh
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
REGION=${2:-eu-west-1}

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

log "Initializing Terraform for $ENVIRONMENT environment..."

# Change to environment directory
cd "$(dirname "$0")/../environments/$ENVIRONMENT"

# Validate environment
if [[ ! -f "main.tf" ]]; then
    error "main.tf not found in environments/$ENVIRONMENT"
fi

# Check if backend.tf exists and is configured
if [[ ! -f "backend.tf" ]]; then
    error "backend.tf not found. Run bootstrap first."
fi

# Check for placeholder account ID
if grep -q "YOUR_ACCOUNT_ID" backend.tf; then
    error "Please replace YOUR_ACCOUNT_ID in backend.tf with your actual AWS account ID"
fi

# Initialize Terraform
log "Running terraform init..."
terraform init -upgrade

# Validate configuration
log "Validating Terraform configuration..."
terraform validate

success "Terraform initialized successfully for $ENVIRONMENT"

# ===========================================
# shared/plan.sh
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

# ===========================================
# shared/apply.sh
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

# ===========================================
# shared/destroy.sh
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

# ===========================================
# modules/cost_optimization/outputs.tf
output "monthly_budget_arn" {
  description = "Monthly budget ARN"
  value       = aws_budgets_budget.monthly_cost.arn
}

output "monthly_budget_name" {
  description = "Monthly budget name"
  value       = aws_budgets_budget.monthly_cost.name
}

output "compute_budget_arn" {
  description = "Compute budget ARN"
  value       = aws_budgets_budget.compute_budget.arn
}

output "database_budget_arn" {
  description = "Database budget ARN"
  value       = aws_budgets_budget.database_budget.arn
}

output "cost_anomaly_detector_arn" {
  description = "Cost anomaly detector ARN"
  value       = aws_ce_anomaly_detector.cost_anomaly.arn
}

output "cost_optimizer_function_name" {
  description = "Cost optimizer Lambda function name"
  value       = aws_lambda_function.cost_optimizer.function_name
}

output "cost_optimizer_function_arn" {
  description = "Cost optimizer Lambda function ARN"
  value       = aws_lambda_function.cost_optimizer.arn
}

output "cost_alerts_topic_arn" {
  description = "Cost alerts SNS topic ARN"
  value       = aws_sns_topic.cost_alerts.arn
}

output "cost_dashboard_name" {
  description = "CloudWatch cost monitoring dashboard name"
  value       = aws_cloudwatch_dashboard.cost_monitoring.dashboard_name
}

output "cost_dashboard_url" {
  description = "CloudWatch cost monitoring dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.cost_monitoring.dashboard_name}"
}

output "high_cost_alarm_arn" {
  description = "High monthly cost alarm ARN"
  value       = aws_cloudwatch_metric_alarm.high_monthly_cost.arn
}

# ===========================================
# environments/global/lambda/edge_router.py
import json

def lambda_handler(event, context):
    """
    Lambda@Edge function for geographical routing of API requests.
    Routes users to the nearest regional API gateway based on their location.
    """
    
    request = event['Records'][0]['cf']['request']
    headers = request['headers']
    
    # Get CloudFront viewer country
    country_code = headers.get('cloudfront-viewer-country', [{}])[0].get('value', 'US')
    
    # Regional endpoint mapping
    regional_endpoints = {
        # Europe
        'GB': 'api-eu.example.com',
        'DE': 'api-eu.example.com', 
        'FR': 'api-eu.example.com',
        'IT': 'api-eu.example.com',
        'ES': 'api-eu.example.com',
        'NL': 'api-eu.example.com',
        'BE': 'api-eu.example.com',
        'CH': 'api-eu.example.com',
        'AT': 'api-eu.example.com',
        'SE': 'api-eu.example.com',
        'NO': 'api-eu.example.com',
        'DK': 'api-eu.example.com',
        'FI': 'api-eu.example.com',
        'IE': 'api-eu.example.com',
        'PT': 'api-eu.example.com',
        'PL': 'api-eu.example.com',
        'CZ': 'api-eu.example.com',
        'HU': 'api-eu.example.com',
        'RO': 'api-eu.example.com',
        'BG': 'api-eu.example.com',
        'HR': 'api-eu.example.com',
        'SI': 'api-eu.example.com',
        'SK': 'api-eu.example.com',
        'LT': 'api-eu.example.com',
        'LV': 'api-eu.example.com',
        'EE': 'api-eu.example.com',
        'GR': 'api-eu.example.com',
        'CY': 'api-eu.example.com',
        'MT': 'api-eu.example.com',
        'LU': 'api-eu.example.com',
        
        # North America
        'US': 'api-us.example.com',
        'CA': 'api-us.example.com',
        'MX': 'api-us.example.com',
        
        # Asia Pacific
        'JP': 'api-ap.example.com',
        'SG': 'api-ap.example.com',
        'AU': 'api-ap.example.com',
        'NZ': 'api-ap.example.com',
        'KR': 'api-ap.example.com',
        'TH': 'api-ap.example.com',
        'MY': 'api-ap.example.com',
        'ID': 'api-ap.example.com',
        'PH': 'api-ap.example.com',
        'VN': 'api-ap.example.com',
        'IN': 'api-ap.example.com',
        'TW': 'api-ap.example.com',
        'HK': 'api-ap.example.com',
        'CN': 'api-ap.example.com',
    }
    
    # Determine target endpoint based on country
    target_endpoint = regional_endpoints.get(country_code, 'api.example.com')  # Default to primary
    
    # Add performance optimization based on time of day
    # Route to less busy regions during peak hours
    import datetime
    current_hour = datetime.datetime.utcnow().hour
    
    # Peak hours optimization (rough timezone mapping)
    if country_code in ['US', 'CA', 'MX'] and 14 <= current_hour <= 22:  # US peak hours
        # Route some traffic to other regions if available
        if current_hour % 2 == 0:  # Simple load balancing
            target_endpoint = 'api-eu.example.com'
    elif country_code in ['GB', 'DE', 'FR'] and 8 <= current_hour <= 18:  # EU peak hours
        if current_hour % 2 == 0:
            target_endpoint = 'api-us.example.com'
    
    # Modify the origin to route to selected endpoint
    request['origin'] = {
        'custom': {
            'domainName': target_endpoint,
            'port': 443,
            'protocol': 'https',
            'path': '/api'
        }
    }
    
    # Add routing headers for debugging and analytics
    request['headers']['x-routed-from'] = [{'key': 'X-Routed-From', 'value': country_code}]
    request['headers']['x-target-region'] = [{'key': 'X-Target-Region', 'value': target_endpoint}]
    request['headers']['x-routing-time'] = [{'key': 'X-Routing-Time', 'value': str(current_hour)}]
    
    return request
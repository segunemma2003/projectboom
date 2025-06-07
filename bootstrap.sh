#!/bin/bash

# Simple Terraform Backend Bootstrap Script
# This creates S3 buckets and DynamoDB tables for all environments

set -e

PROJECT_NAME="social-platform"
AWS_REGION="eu-west-1"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Setting up Terraform backend infrastructure...${NC}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${BLUE}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"

# Generate unique suffix
SUFFIX=$(date +%s | tail -c 5)

# Create S3 buckets and DynamoDB tables for each environment
for ENV in dev staging prod; do
    echo -e "${BLUE}Setting up ${ENV} environment...${NC}"
    
    # Create unique bucket name
    BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ENV}-${AWS_ACCOUNT_ID}-${SUFFIX}"
    TABLE_NAME="terraform-state-locks-${ENV}"
    
    # Create S3 bucket
    echo "Creating S3 bucket: ${BUCKET_NAME}"
    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3 mb "s3://${BUCKET_NAME}" --region "$AWS_REGION"
    else
        aws s3 mb "s3://${BUCKET_NAME}" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    # Create DynamoDB table
    echo "Creating DynamoDB table: ${TABLE_NAME}"
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Environment,Value="$ENV" Key=Project,Value="$PROJECT_NAME" Key=ManagedBy,Value=terraform
    
    # Generate backend.tf file
    cat > "environments/${ENV}/backend.tf" << EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "${ENV}/terraform.tfstate"
    region         = "$AWS_REGION"
    encrypt        = true
    dynamodb_table = "$TABLE_NAME"
  }
}
EOF
    
    echo -e "${GREEN}✅ ${ENV} environment setup complete${NC}"
    echo -e "   📦 S3 Bucket: ${BUCKET_NAME}"
    echo -e "   🗃️  DynamoDB: ${TABLE_NAME}"
    echo ""
done

# Wait for DynamoDB tables to be active
echo -e "${YELLOW}⏳ Waiting for DynamoDB tables to be active...${NC}"
for ENV in dev staging prod; do
    TABLE_NAME="terraform-state-locks-${ENV}"
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
done

echo -e "${GREEN}🎉 Backend infrastructure setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. cd environments/dev && terraform init"
echo "2. cd environments/staging && terraform init"
echo "3. cd environments/prod && terraform init"
echo ""
echo "Your Terraform state will now be stored securely in S3 with DynamoDB locking!"
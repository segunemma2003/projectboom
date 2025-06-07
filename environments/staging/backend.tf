# environments/staging/backend.tf - FIXED  
terraform {
  backend "s3" {
    bucket         = "social-platform-terraform-state-staging-YOUR_ACCOUNT_ID"
    key            = "staging/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks-staging"
  }
}

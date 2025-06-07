terraform {
  backend "s3" {
    bucket         = "social-platform-terraform-state-prod-YOUR_ACCOUNT_ID"
    key            = "production/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks-prod"
  }
}
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-prod"
    key            = "production/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-prod"
  }
}
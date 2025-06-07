terraform {
  backend "s3" {
    bucket         = "your-terraform-state-dev"
    key            = "development/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-dev"
  }
}
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-staging"
    key            = "staging/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks-staging"
  }
}

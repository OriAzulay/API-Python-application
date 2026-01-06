################################################################################
# Terraform Backend Configuration
# Stores state in S3 for CI/CD pipeline access
################################################################################

terraform {
  backend "s3" {
    bucket         = "fastapi-app-tf-state-770c5f67"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "fastapi-app-terraform-locks"
  }
}


################################################################################
# Provider Configuration
################################################################################

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "fastapi-app"
      Purpose   = "Terraform State Management"
      ManagedBy = "Terraform"
    }
  }
}


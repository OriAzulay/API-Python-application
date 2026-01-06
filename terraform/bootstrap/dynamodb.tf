################################################################################
# DynamoDB Table for Terraform State Locking
# Free Tier: 25 RCU + 25 WCU included
################################################################################

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "fastapi-app-terraform-locks"
  billing_mode = "PROVISIONED"
  hash_key     = "LockID"

  # Minimal capacity - well within Free Tier (25 RCU/WCU free)
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}


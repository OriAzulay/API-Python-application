################################################################################
# S3 Bucket for Application Files
################################################################################

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "app_files" {
  bucket = "${var.app_name}-files-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.app_name}-files"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "app_files" {
  bucket = aws_s3_bucket.app_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "app_files" {
  bucket = aws_s3_bucket.app_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# Upload Application Files
################################################################################

resource "aws_s3_object" "app_files" {
  for_each = local.app_files

  bucket = aws_s3_bucket.app_files.id
  key    = each.key
  source = each.value
  etag   = filemd5(each.value)
}


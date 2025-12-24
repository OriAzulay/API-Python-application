################################################################################
# IAM Role for EC2 to Access S3
################################################################################

resource "aws_iam_role" "ec2_s3_role" {
  name = "${var.app_name}-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-ec2-s3-role"
  }
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "${var.app_name}-ec2-s3-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.app_files.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "${var.app_name}-ec2-s3-profile"
  role = aws_iam_role.ec2_s3_role.name

  tags = {
    Name = "${var.app_name}-ec2-s3-profile"
  }
}


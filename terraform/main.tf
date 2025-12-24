terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get the public IP of the machine running Terraform
data "http" "myip" {
  url = "https://api.ipify.org?format=json"
}

locals {
  my_ip = jsondecode(data.http.myip.response_body).ip
  my_ip_cidr = "${local.my_ip}/32"
}

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# S3 Bucket for application files
resource "aws_s3_bucket" "app_files" {
  bucket = "${var.app_name}-files-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name = "${var.app_name}-files"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_public_access_block" "app_files" {
  bucket = aws_s3_bucket.app_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets  = true
}

# Upload app.py to S3
resource "aws_s3_object" "app_py" {
  bucket = aws_s3_bucket.app_files.id
  key    = "app.py"
  source = "${path.module}/../app.py"
  etag   = filemd5("${path.module}/../app.py")
}

# Upload Dockerfile to S3
resource "aws_s3_object" "dockerfile" {
  bucket = aws_s3_bucket.app_files.id
  key    = "Dockerfile"
  source = "${path.module}/../Dockerfile"
  etag   = filemd5("${path.module}/../Dockerfile")
}

# Upload requirements.txt to S3
resource "aws_s3_object" "requirements" {
  bucket = aws_s3_bucket.app_files.id
  key    = "requirements.txt"
  source = "${path.module}/../requirements.txt"
  etag   = filemd5("${path.module}/../requirements.txt")
}

# IAM role for EC2 to access S3
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
}

# Security Group for EC2 instance
resource "aws_security_group" "app_sg" {
  name        = "${var.app_name}-sg"
  description = "Security group for FastAPI application - restricted to Terraform runner IP"

  # Only allow FastAPI traffic from the machine running Terraform
  ingress {
    description = "FastAPI Application"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  # SSH access from the machine running Terraform
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-sg"
  }
}

# EC2 Instance (t2.micro - free tier eligible)
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_pair_name

  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  # User data script to install Docker, build and run the container
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    app_name        = var.app_name
    api_key         = var.api_key
    s3_bucket_name  = aws_s3_bucket.app_files.bucket
  })

  tags = {
    Name = var.app_name
  }
}

# Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.app_server.public_dns
}

output "api_url" {
  description = "URL to access the API"
  value       = "http://${aws_instance.app_server.public_ip}:5000"
}

output "status_endpoint" {
  description = "Status endpoint URL"
  value       = "http://${aws_instance.app_server.public_ip}:5000/status"
}

output "update_endpoint" {
  description = "Update endpoint URL"
  value       = "http://${aws_instance.app_server.public_ip}:5000/update"
}

output "logs_endpoint" {
  description = "Logs endpoint URL"
  value       = "http://${aws_instance.app_server.public_ip}:5000/logs"
}

output "terraform_runner_ip" {
  description = "IP address of the machine running Terraform (allowed in security group)"
  value       = local.my_ip
}

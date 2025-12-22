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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
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

# Generate a secure private key
resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the Key Pair in AWS using the generated public key
resource "aws_key_pair" "generated" {
  key_name   = "${var.app_name}-key"
  public_key = tls_private_key.generated.public_key_openssh
}

# Save the private key to a local file (for SSH access)
resource "local_file" "private_key" {
  content         = tls_private_key.generated.private_key_pem
  filename        = "${path.module}/${var.app_name}-key.pem"
  file_permission = "0400"
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
  key_name               = aws_key_pair.generated.key_name

  # User data script to install Docker, build and run the container
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    app_name      = var.app_name
    api_key       = var.api_key
    app_py_content = file("${path.module}/../app.py")
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

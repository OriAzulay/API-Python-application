################################################################################
# EC2 Instance
################################################################################

# Get the latest Amazon Linux 2 AMI (Docker available via amazon-linux-extras)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_profile.name

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    app_name       = var.app_name
    api_key        = var.api_key
    s3_bucket_name = aws_s3_bucket.app_files.bucket
  })

  tags = {
    Name = var.app_name
  }

  # Ensure S3 files are uploaded before EC2 launches
  depends_on = [aws_s3_object.app_files]
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "app_sg" {
  name        = "${var.app_name}-sg"
  description = "Security group for ${var.app_name} - restricted to Terraform runner IP"

  tags = {
    Name = "${var.app_name}-sg"
  }
}

# Ingress: FastAPI Application (port 5000) - Public access for production
resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.app_sg.id
  description       = "FastAPI Application - Public Access"

  from_port   = 5000
  to_port     = 5000
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"  # Open to all users (API key required for updates)

  tags = {
    Name = "${var.app_name}-app-ingress"
  }
}

# Ingress: SSH (port 22)
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app_sg.id
  description       = "SSH Access"

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = local.my_ip_cidr

  tags = {
    Name = "${var.app_name}-ssh-ingress"
  }
}

# Egress: All outbound traffic
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app_sg.id
  description       = "All outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "${var.app_name}-egress"
  }
}


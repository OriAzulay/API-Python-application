################################################################################
# Outputs
################################################################################

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

output "s3_bucket" {
  description = "S3 bucket name containing application files"
  value       = aws_s3_bucket.app_files.bucket
}


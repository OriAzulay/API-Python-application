################################################################################
# Local Values
################################################################################

# Get the public IP of the machine running Terraform
data "http" "myip" {
  url = "https://api.ipify.org?format=json"
}

locals {
  # IP address of the machine running Terraform
  my_ip      = jsondecode(data.http.myip.response_body).ip
  my_ip_cidr = "${local.my_ip}/32"

  # Application files to upload to S3
  app_files = {
    "app/__init__.py"     = "${path.module}/../app/__init__.py"
    "app/config.py"       = "${path.module}/../app/config.py"
    "app/database.py"     = "${path.module}/../app/database.py"
    "app/schemas.py"      = "${path.module}/../app/schemas.py"
    "app/dependencies.py" = "${path.module}/../app/dependencies.py"
    "app/routes.py"       = "${path.module}/../app/routes.py"
    "app/main.py"         = "${path.module}/../app/main.py"
    "Dockerfile"          = "${path.module}/../Dockerfile"
    "requirements.txt"    = "${path.module}/../requirements.txt"
  }
}


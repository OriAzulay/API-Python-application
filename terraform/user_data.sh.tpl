#!/bin/bash
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Wait for Docker to be ready
sleep 10

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Create Dockerfile from existing file
cat > Dockerfile << 'DOCKERFILE'
${dockerfile_content}
DOCKERFILE

# Create requirements.txt from existing file
cat > requirements.txt << 'REQUIREMENTS'
${requirements_content}
REQUIREMENTS

# Create app.py from embedded content
cat > app.py << 'APPFILE'
${app_py_content}
APPFILE

# Build Docker image
docker build -t ${app_name}:latest .

# Run the container
docker run -d \
  --name ${app_name} \
  -p 5000:5000 \
  -e API_KEY=${api_key} \
  --restart unless-stopped \
  ${app_name}:latest

# Log completion
echo "Application deployed successfully" > /var/log/app-deploy.log




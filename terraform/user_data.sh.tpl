#!/bin/bash

# Update system and install Docker
yum update -y
amazon-linux-extras install docker -y
service docker start
usermod -a -G docker ec2-user

# Create app directory
mkdir -p /app
cd /app

# Write app.py (content passed from Terraform)
cat <<EOF > app.py
${app_py_content}
EOF

# Create a simple Dockerfile on the fly
cat <<EOF > Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY app.py .
RUN pip install fastapi uvicorn
EXPOSE 5000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5000"]
EOF

# Create requirements.txt
cat > requirements.txt << 'REQUIREMENTS'
fastapi>=0.104.1
uvicorn[standard]>=0.24.0
pydantic>=2.5.0
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




#!/bin/bash
set -e

# Update and install dependencies
yum update -y
amazon-linux-extras install docker -y
yum install -y python3 python3-pip

# Start Docker
service docker start
usermod -a -G docker ec2-user

# Create app directory
mkdir -p /app
cd /app

# Create app.py from Terraform template
cat <<EOF > app.py
${app_py_content}
EOF

# Create requirements.txt
cat <<EOF > requirements.txt
fastapi>=0.104.1
uvicorn[standard]>=0.24.0
pydantic>=2.5.0
EOF

# Create Dockerfile
cat <<EOF > Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install fastapi uvicorn
EXPOSE 5000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5000"]
EOF

# Build and run Docker container
docker build -t ${app_name} .
docker run -d \
  --name ${app_name} \
  -p 5000:5000 \
  -e API_KEY="${api_key}" \
  --restart always \
  ${app_name}

# Log completion
echo "Application deployed successfully" > /var/log/app-deploy.log

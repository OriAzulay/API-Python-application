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

# Build and run the container
docker build -t ${app_name} .
docker run -d -p 5000:5000 -e API_KEY="${api_key}" --restart always --name ${app_name} ${app_name}
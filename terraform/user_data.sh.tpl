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

# Create Dockerfile
cat > Dockerfile << 'DOCKERFILE'
# Multi-stage build for optimized image size

# Stage 1: Build stage - install dependencies
FROM python:3.11-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime stage - minimal image
FROM python:3.11-slim

WORKDIR /app

# Copy only the installed packages from builder stage
COPY --from=builder /root/.local /root/.local

# Copy application code
COPY app.py .

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Expose port 5000
EXPOSE 5000

# Run the application on port 5000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5000"]
DOCKERFILE

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




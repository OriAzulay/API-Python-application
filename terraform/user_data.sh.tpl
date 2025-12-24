#!/bin/bash
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/app-deploy.log
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Network connectivity check
check_network() {
    log "Checking network connectivity..."
    if ! ping -c 3 8.8.8.8 > /dev/null 2>&1; then
        error_exit "Network connectivity check failed - cannot reach external network"
    fi
    if ! curl -s --max-time 5 https://www.google.com > /dev/null 2>&1; then
        error_exit "Network connectivity check failed - cannot reach HTTPS endpoints"
    fi
    log "Network connectivity verified"
}

log "Starting application deployment..."

# Check network connectivity first
check_network

# Update system with retry logic
log "Updating system packages..."
MAX_UPDATE_RETRIES=3
UPDATE_RETRY_COUNT=0
UPDATE_SUCCESS=false

while [ $UPDATE_RETRY_COUNT -lt $MAX_UPDATE_RETRIES ]; do
    UPDATE_RETRY_COUNT=$((UPDATE_RETRY_COUNT + 1))
    log "System update attempt $UPDATE_RETRY_COUNT/$MAX_UPDATE_RETRIES..."
    
    if yum update -y >> /var/log/app-deploy.log 2>&1; then
        UPDATE_SUCCESS=true
        log "System packages updated successfully"
        break
    else
        if [ $UPDATE_RETRY_COUNT -lt $MAX_UPDATE_RETRIES ]; then
            WAIT_TIME=$((UPDATE_RETRY_COUNT * 15))
            log "System update failed. Retrying in $${WAIT_TIME} seconds..."
            sleep $WAIT_TIME
        else
            error_exit "System update failed after $MAX_UPDATE_RETRIES attempts"
        fi
    fi
done

# Install Docker and curl with retry logic
log "Installing Docker and dependencies..."
MAX_INSTALL_RETRIES=3
INSTALL_RETRY_COUNT=0
INSTALL_SUCCESS=false

while [ $INSTALL_RETRY_COUNT -lt $MAX_INSTALL_RETRIES ]; do
    INSTALL_RETRY_COUNT=$((INSTALL_RETRY_COUNT + 1))
    log "Package installation attempt $INSTALL_RETRY_COUNT/$MAX_INSTALL_RETRIES..."
    
    if yum install -y docker curl >> /var/log/app-deploy.log 2>&1; then
        INSTALL_SUCCESS=true
        log "Docker and curl installed successfully"
        break
    else
        if [ $INSTALL_RETRY_COUNT -lt $MAX_INSTALL_RETRIES ]; then
            WAIT_TIME=$((INSTALL_RETRY_COUNT * 15))
            log "Package installation failed. Retrying in $${WAIT_TIME} seconds..."
            sleep $WAIT_TIME
        else
            error_exit "Package installation failed after $MAX_INSTALL_RETRIES attempts"
        fi
    fi
done

# Start Docker service with error handling
log "Starting Docker service..."
if ! systemctl start docker >> /var/log/app-deploy.log 2>&1; then
    error_exit "Failed to start Docker service"
fi

if ! systemctl enable docker >> /var/log/app-deploy.log 2>&1; then
    error_exit "Failed to enable Docker service"
fi

if ! usermod -a -G docker ec2-user >> /var/log/app-deploy.log 2>&1; then
    log "WARNING: Failed to add ec2-user to docker group (non-critical)"
fi

# Wait for Docker to be ready (with timeout)
log "Waiting for Docker service to be ready..."
MAX_WAIT=60
WAIT_COUNT=0
while ! docker info > /dev/null 2>&1; do
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        log "ERROR: Docker service did not start within $${MAX_WAIT} seconds"
        exit 1
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done
log "Docker service is ready"

# Create application directory
log "Creating application directory..."
if ! mkdir -p /opt/app; then
    error_exit "Failed to create application directory"
fi

if ! cd /opt/app; then
    error_exit "Failed to change to application directory"
fi

# Install AWS CLI if not available
if ! command -v aws &> /dev/null; then
    log "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

# Download files from S3
log "Downloading application files from S3..."
MAX_DOWNLOAD_RETRIES=3
DOWNLOAD_RETRY_COUNT=0
DOWNLOAD_SUCCESS=false

while [ $DOWNLOAD_RETRY_COUNT -lt $MAX_DOWNLOAD_RETRIES ]; do
    DOWNLOAD_RETRY_COUNT=$((DOWNLOAD_RETRY_COUNT + 1))
    log "Download attempt $DOWNLOAD_RETRY_COUNT/$MAX_DOWNLOAD_RETRIES..."
    
    if aws s3 cp s3://${s3_bucket_name}/Dockerfile /opt/app/Dockerfile && \
       aws s3 cp s3://${s3_bucket_name}/requirements.txt /opt/app/requirements.txt && \
       aws s3 cp s3://${s3_bucket_name}/app.py /opt/app/app.py; then
        DOWNLOAD_SUCCESS=true
        log "Files downloaded successfully"
        break
    else
        if [ $DOWNLOAD_RETRY_COUNT -lt $MAX_DOWNLOAD_RETRIES ]; then
            WAIT_TIME=$((DOWNLOAD_RETRY_COUNT * 10))
            log "Download failed. Retrying in $${WAIT_TIME} seconds..."
            sleep $WAIT_TIME
        else
            error_exit "Failed to download files from S3 after $MAX_DOWNLOAD_RETRIES attempts"
        fi
    fi
done

if [ "$DOWNLOAD_SUCCESS" = false ]; then
    error_exit "Failed to download application files from S3"
fi

# Verify files were downloaded
if [ ! -f Dockerfile ] || [ ! -s Dockerfile ]; then
    error_exit "Dockerfile is missing or empty"
fi
log "Dockerfile downloaded successfully ($(wc -l < Dockerfile) lines)"

if [ ! -f requirements.txt ] || [ ! -s requirements.txt ]; then
    error_exit "requirements.txt is missing or empty"
fi
log "requirements.txt downloaded successfully ($(wc -l < requirements.txt) lines)"

if [ ! -f app.py ] || [ ! -s app.py ]; then
    error_exit "app.py is missing or empty"
fi
log "app.py downloaded successfully ($(wc -l < app.py) lines)"

# Build Docker image with retry logic and network error detection
log "Building Docker image..."
MAX_RETRIES=3
RETRY_COUNT=0
BUILD_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log "Docker build attempt $RETRY_COUNT/$MAX_RETRIES..."
    
    # Check network before build (in case connectivity was lost)
    if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        log "WARNING: Network connectivity issue detected before build"
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            WAIT_TIME=$((RETRY_COUNT * 20))
            log "Waiting $${WAIT_TIME} seconds for network to recover..."
            sleep $WAIT_TIME
            continue
        else
            error_exit "Network connectivity lost and could not be restored"
        fi
    fi
    
    # Attempt Docker build
    BUILD_OUTPUT=$(docker build -t ${app_name}:latest . 2>&1)
    BUILD_EXIT_CODE=$?
    echo "$BUILD_OUTPUT" >> /var/log/app-deploy.log
    
    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        BUILD_SUCCESS=true
        log "Docker image built successfully"
        break
    else
        # Check for specific error types
        if echo "$BUILD_OUTPUT" | grep -qi "network\|connection\|timeout\|resolve"; then
            log "Network-related error detected in build output"
        elif echo "$BUILD_OUTPUT" | grep -qi "file not found\|no such file"; then
            error_exit "Missing file dependency detected in Docker build"
        fi
        
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            WAIT_TIME=$((RETRY_COUNT * 10))
            log "Docker build failed (exit code: $BUILD_EXIT_CODE). Retrying in $${WAIT_TIME} seconds..."
            log "Build error summary: $(echo "$BUILD_OUTPUT" | tail -5 | tr '\n' ' ')"
            sleep $WAIT_TIME
        else
            log "ERROR: Docker build failed after $MAX_RETRIES attempts"
            log "Last build output (last 50 lines):"
            tail -50 /var/log/app-deploy.log
            error_exit "Docker build failed after $MAX_RETRIES attempts. Check /var/log/app-deploy.log for details"
        fi
    fi
done

if [ "$BUILD_SUCCESS" = false ]; then
    error_exit "Failed to build Docker image"
fi

# Remove existing container if it exists
log "Cleaning up any existing containers..."
docker rm -f ${app_name} 2>/dev/null || true

# Run the container
log "Starting Docker container..."
if ! docker run -d \
  --name ${app_name} \
  -p 5000:5000 \
  -e API_KEY=${api_key} \
  --restart unless-stopped \
  ${app_name}:latest; then
    log "ERROR: Failed to start Docker container"
    exit 1
fi

log "Container started, waiting for application to be healthy..."

# Health check with retry logic
MAX_HEALTH_CHECKS=30
HEALTH_CHECK_INTERVAL=5
HEALTH_CHECK_COUNT=0
HEALTHY=false

while [ $HEALTH_CHECK_COUNT -lt $MAX_HEALTH_CHECKS ]; do
    # Check if container is running
    if ! docker ps | grep -q ${app_name}; then
        log "WARNING: Container is not running. Checking logs..."
        docker logs ${app_name} --tail 50 >> /var/log/app-deploy.log 2>&1
        HEALTH_CHECK_COUNT=$((HEALTH_CHECK_COUNT + 1))
        sleep $HEALTH_CHECK_INTERVAL
        continue
    fi
    
    # Check if application is responding
    CURL_OUTPUT=$(curl -f -s -w "\n%%{http_code}" http://localhost:5000/status 2>&1)
    CURL_EXIT_CODE=$?
    HTTP_CODE=$(echo "$CURL_OUTPUT" | tail -1)
    
    if [ $CURL_EXIT_CODE -eq 0 ] && [ "$HTTP_CODE" = "200" ]; then
        HEALTHY=true
        log "Application is healthy and responding (HTTP $HTTP_CODE)"
        break
    else
        HEALTH_CHECK_COUNT=$((HEALTH_CHECK_COUNT + 1))
        
        # Diagnose the issue
        if [ $CURL_EXIT_CODE -ne 0 ]; then
            if echo "$CURL_OUTPUT" | grep -qi "connection refused\|couldn't connect"; then
                log "Health check failed: Connection refused (application may still be starting)"
            elif echo "$CURL_OUTPUT" | grep -qi "timeout"; then
                log "Health check failed: Connection timeout"
            else
                log "Health check failed: curl error (exit code: $CURL_EXIT_CODE)"
            fi
        elif [ "$HTTP_CODE" != "200" ]; then
            log "Health check failed: HTTP $HTTP_CODE (expected 200)"
        fi
        
        if [ $HEALTH_CHECK_COUNT -lt $MAX_HEALTH_CHECKS ]; then
            log "Retrying health check (attempt $HEALTH_CHECK_COUNT/$MAX_HEALTH_CHECKS) in $${HEALTH_CHECK_INTERVAL} seconds..."
            sleep $HEALTH_CHECK_INTERVAL
        fi
    fi
done

if [ "$HEALTHY" = false ]; then
    log "ERROR: Application did not become healthy within $((MAX_HEALTH_CHECKS * HEALTH_CHECK_INTERVAL)) seconds"
    log "Container logs:"
    docker logs ${app_name} --tail 100 >> /var/log/app-deploy.log 2>&1
    exit 1
fi

# Final verification
log "Performing final verification..."
VERIFY_OUTPUT=$(curl -f -s -w "\n%%{http_code}" http://localhost:5000/status 2>&1)
VERIFY_EXIT_CODE=$?
VERIFY_HTTP_CODE=$(echo "$VERIFY_OUTPUT" | tail -1)
VERIFY_BODY=$(echo "$VERIFY_OUTPUT" | head -n -1)

if [ $VERIFY_EXIT_CODE -eq 0 ] && [ "$VERIFY_HTTP_CODE" = "200" ]; then
    if echo "$VERIFY_BODY" | grep -q "counter"; then
        log "✓ Application deployed successfully and is responding correctly"
        log "Deployment completed at $(date)"
    else
        log "WARNING: Application responded but response format may be incorrect"
        log "Response preview: $(echo "$VERIFY_BODY" | head -c 200)"
    fi
else
    if [ $VERIFY_EXIT_CODE -ne 0 ]; then
        log "WARNING: Final verification failed - curl error (exit code: $VERIFY_EXIT_CODE)"
        if echo "$VERIFY_OUTPUT" | grep -qi "connection refused"; then
            log "WARNING: Connection refused - application may have stopped"
        fi
    elif [ "$VERIFY_HTTP_CODE" != "200" ]; then
        log "WARNING: Final verification failed - HTTP $VERIFY_HTTP_CODE (expected 200)"
    fi
    log "Application container is running but health check failed"
fi




# FastAPI Shared State Application

A Python FastAPI application with shared state management, logging, and API key authentication. The application is containerized with Docker and can be deployed to AWS EC2 using Terraform.

## Features

- **GET /status**: Returns current state (counter and message) with server metadata
- **POST /update**: Updates shared state with validation and API key authentication
- **GET /logs**: Returns paginated list of all state updates
- **SQLite Database**: Persistent storage for state and logs
- **API Key Authentication**: Secure access to update endpoint
- **Docker Support**: Containerized application
- **Terraform Deployment**: Automated AWS EC2 deployment

## Project Structure

```
.
├── app.py                 # FastAPI application
├── requirements.txt       # Python dependencies
├── Dockerfile            # Docker container configuration
├── .dockerignore         # Docker ignore file
├── terraform/            # Terraform configuration
│   ├── main.tf          # Main Terraform configuration
│   ├── variables.tf     # Variable definitions
│   ├── outputs.tf       # Output definitions
│   └── terraform.tfvars.example  # Example variables file
└── README.md            # This file
```

## Local Development

### Prerequisites

- Python 3.11 or higher
- pip

### Setup

1. **Clone or navigate to the project directory**

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Set environment variable (optional)**:
   ```bash
   # Windows PowerShell
   $env:API_KEY="your-secret-api-key-12345"
   
   # Linux/Mac
   export API_KEY="your-secret-api-key-12345"
   ```
   If not set, the default API key is `your-secret-api-key-12345`

4. **Run the application**:
   ```bash
   python app.py
   ```
   Or using uvicorn directly:
   ```bash
   uvicorn app:app --host 0.0.0.0 --port 5000 --reload
   ```

5. **Access the API**:
   - API Base URL: `http://localhost:5000`
   - Interactive API Docs: `http://localhost:5000/docs`
   - Alternative Docs: `http://localhost:5000/redoc`

## API Endpoints

### GET /status

Returns the current state of shared variables with metadata.

**Response**:
```json
{
  "counter": 0,
  "message": "Hello World",
  "timestamp": "2024-01-01T12:00:00Z",
  "uptime_seconds": 123.45
}
```

### POST /update

Updates the shared state (counter or message). Requires API key authentication.

**Headers**:
```
X-API-Key: your-secret-api-key-12345
```

**Request Body**:
```json
{
  "counter": 5,
  "message": "Updated message"
}
```

**Response**:
```json
{
  "success": true,
  "message": "State updated successfully",
  "old_state": {
    "counter": 0,
    "message": ""
  },
  "new_state": {
    "counter": 5,
    "message": "Updated message"
  }
}
```

**Error Responses**:
- `400 Bad Request`: Invalid input validation
- `401 Unauthorized`: Missing or invalid API key

### GET /logs

Returns paginated list of all updates.

**Query Parameters**:
- `page` (optional, default: 1): Page number
- `limit` (optional, default: 10, max: 100): Number of logs per page

**Example**:
```
GET /logs?page=1&limit=10
```

**Response**:
```json
{
  "logs": [
    {
      "id": 1,
      "timestamp": "2024-01-01T12:00:00",
      "old_counter": 0,
      "new_counter": 5,
      "old_message": "",
      "new_message": "Updated message",
      "update_type": "counter, message"
    }
  ],
  "page": 1,
  "limit": 10,
  "total": 1,
  "total_pages": 1
}
```

## Docker Usage

### Build the Docker Image

```bash
docker build -t fastapi-app:latest .
```

### Run the Container

```bash
docker run -d \
  --name fastapi-app \
  -p 5000:5000 \
  -e API_KEY="your-secret-api-key-12345" \
  fastapi-app:latest
```

### Access the Application

- API: `http://localhost:5000`
- Docs: `http://localhost:5000/docs`

### Stop and Remove Container

```bash
docker stop fastapi-app
docker rm fastapi-app
```

## AWS EC2 Deployment with Terraform

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
   ```powershell
   aws configure
   aws sts get-caller-identity  # Verify credentials work
   ```
3. **Terraform** installed (>= 1.0)
   ```powershell
   terraform --version
   ```
4. **AWS Key Pair** created in your target region
   - Create via AWS Console: EC2 → Key Pairs → Create key pair
   - Or via CLI: `aws ec2 create-key-pair --region us-east-1 --key-name fastapi-app-key`
   - Save the `.pem` file securely for SSH access

### Key Features

- ✅ **Automatic IP Detection**: Your public IP is automatically detected and used for security group rules
- ✅ **Security**: Only allows inbound traffic from your machine's IP address
- ✅ **Free Tier**: Uses t3.micro instance (free tier eligible)
- ✅ **Docker Build**: Builds Docker image directly on EC2 (no registry needed)
- ✅ **Multi-stage Build**: Optimized Docker image size

### Step 1: Configure Terraform

1. **Navigate to terraform directory**:
   ```powershell
   cd terraform
   ```

2. **Copy the example variables file**:
   ```powershell
   # Windows PowerShell
   Copy-Item terraform.tfvars.example terraform.tfvars
   
   # Linux/Mac
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars`** with your values:
   ```hcl
   aws_region     = "us-east-1"           # Your preferred AWS region
   app_name       = "fastapi-app"           # Application name
   instance_type  = "t3.micro"              # Free tier eligible
   key_pair_name  = "fastapi-app-key"       # Your AWS key pair name
   api_key        = "your-secret-api-key-12345"  # API key for authentication
   ```

   **Note**: Your public IP is automatically detected - no need to specify it manually.

### Step 2: Verify Prerequisites

Before deploying, verify everything is set up correctly:

```powershell
# Check AWS credentials
aws sts get-caller-identity

# Verify key pair exists
aws ec2 describe-key-pairs --region us-east-1 --key-names fastapi-app-key
```

### Step 3: Deploy

1. **Initialize Terraform**:
   ```powershell
   terraform init
   ```
   This downloads the required providers (AWS, HTTP).

2. **Validate configuration**:
   ```powershell
   terraform validate
   ```
   Should return: `Success! The configuration is valid.`

3. **Review the deployment plan** (dry run):
   ```powershell
   terraform plan
   ```
   Review what will be created:
   - EC2 instance (t3.micro)
   - Security group (restricted to your IP)
   - All necessary configurations

4. **Apply the configuration**:
   ```powershell
   terraform apply
   ```
   Type `yes` when prompted.

5. **Wait for deployment** (~3-5 minutes):
   - EC2 instance launches (~1-2 minutes)
   - Docker installs (~1 minute)
   - Application builds and starts (~1-2 minutes)

### Step 4: Get Instance Information

After deployment, get the instance IP and endpoints:

```powershell
# Get instance IP
terraform output instance_public_ip

# Get all outputs
terraform output
```

**Outputs include**:
- `instance_public_ip`: Public IP address
- `api_url`: Full API URL
- `status_endpoint`: Status endpoint URL
- `update_endpoint`: Update endpoint URL
- `logs_endpoint`: Logs endpoint URL

### Step 5: Test the Application

**Wait 2-3 minutes after deployment** for the application to fully start, then test:

#### Test 1: Get Status
```powershell
$ip = terraform output -raw instance_public_ip
Invoke-RestMethod -Uri ("http://{0}:5000/status" -f $ip)
```

Or using subexpression:
```powershell
Invoke-RestMethod -Uri "http://$(terraform output -raw instance_public_ip):5000/status"
```

#### Test 2: Update State
```powershell
$ip = terraform output -raw instance_public_ip
$apiKey = "your-secret-api-key-12345"

$headers = @{
    "X-API-Key" = $apiKey
    "Content-Type" = "application/json"
}

$body = @{
    counter = 42
    message = "Hello from Terraform deployment!"
} | ConvertTo-Json

Invoke-RestMethod -Uri ("http://{0}:5000/update" -f $ip) -Method Post -Headers $headers -Body $body
```

#### Test 3: Get Logs
```powershell
$ip = terraform output -raw instance_public_ip
Invoke-RestMethod -Uri ("http://{0}:5000/logs?page=1&limit=10" -f $ip)
```

#### Test 4: Open API Documentation
Open in your browser:
```
http://<INSTANCE_IP>:5000/docs
```

### Step 6: Access the Deployed Application

After deployment, access:
- **API**: `http://<instance-ip>:5000`
- **Interactive Docs**: `http://<instance-ip>:5000/docs`
- **Alternative Docs**: `http://<instance-ip>:5000/redoc`

### Step 7: Teardown

**Always destroy resources when done to avoid AWS charges!**

```powershell
terraform destroy
```

Type `yes` when prompted. This will:
- Terminate the EC2 instance
- Delete the security group
- Clean up all resources

### Troubleshooting

**Issue: "Error: InvalidKeyPair.NotFound"**
- Verify key pair exists: `aws ec2 describe-key-pairs --region us-east-1`
- Update `key_pair_name` in `terraform.tfvars` to match your key pair name

**Issue: "Cannot connect to API"**
- Wait 3-5 minutes after deployment (application needs time to start)
- Check if your IP changed (re-run `terraform apply` to update security group)
- Verify instance is running: `aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Name,Values=fastapi-app"`

**Issue: "Error: InvalidClientTokenId"**
- Your AWS credentials are invalid or expired
- Re-configure: `aws configure`
- Test: `aws sts get-caller-identity`

For detailed step-by-step instructions, see [`terraform/MANUAL_DEPLOYMENT_GUIDE.md`](terraform/MANUAL_DEPLOYMENT_GUIDE.md).

## Testing the API

### Using curl

1. **Get status**:
   ```bash
   curl http://localhost:5000/status
   ```

2. **Update state**:
   ```bash
   curl -X POST http://localhost:5000/update \
     -H "X-API-Key: your-secret-api-key-12345" \
     -H "Content-Type: application/json" \
     -d '{"counter": 10, "message": "Hello from API"}'
   ```

3. **Get logs**:
   ```bash
   curl http://localhost:5000/logs?page=1&limit=10
   ```

### Using Python requests

```python
import requests

base_url = "http://localhost:5000"
api_key = "your-secret-api-key-12345"

# Get status
response = requests.get(f"{base_url}/status")
print(response.json())

# Update state
response = requests.post(
    f"{base_url}/update",
    headers={"X-API-Key": api_key},
    json={"counter": 5, "message": "Test message"}
)
print(response.json())

# Get logs
response = requests.get(f"{base_url}/logs?page=1&limit=10")
print(response.json())
```

## Database

The application uses SQLite for persistent storage:
- **Database file**: `app.db` (created automatically)
- **Tables**:
  - `shared_state`: Current state of counter and message
  - `update_logs`: History of all updates

The database file persists in the container's filesystem. For production, consider using a volume mount or external database.

## Security Considerations

1. **API Key**: Change the default API key in production
2. **SSH Access**: Restrict `ssh_cidr` in `terraform.tfvars` to your IP
3. **HTTPS**: Consider adding a reverse proxy (nginx) with SSL/TLS
4. **Secrets Management**: Use AWS Secrets Manager or Parameter Store for API keys
5. **Database**: For production, use managed database services (RDS)

## Troubleshooting

### Application won't start
- Check if port 5000 is available
- Verify Python version (3.11+)
- Check database file permissions

### Docker issues
- Ensure Docker is running
- Check container logs: `docker logs fastapi-app`
- Verify port mapping

### Terraform deployment issues
- Verify AWS credentials: `aws sts get-caller-identity`
- Check key pair exists in the specified region
- Review security group rules
- Check EC2 instance logs via AWS Console

## License

This project is provided as-is for educational and development purposes.


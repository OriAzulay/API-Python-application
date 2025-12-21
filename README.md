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

```One-line Command
docker run -d --name fastapi-app -p 5000:5000 -e API_KEY="your-secret-api-key-12345" fastapi-app:latest
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
3. **Terraform** installed (>= 1.0)
4. **Docker Hub account** (or other container registry)
5. **AWS Key Pair** for SSH access

### Step 1: Build and Push Docker Image

1. **Build the image**:

   ```bash
   docker build -t your-dockerhub-username/fastapi-app:latest .
   ```

2. **Login to Docker Hub**:

   ```bash
   docker login
   ```

3. **Push the image**:
   ```bash
   docker push your-dockerhub-username/fastapi-app:latest
   ```

### Step 2: Configure Terraform

1. **Navigate to terraform directory**:

   ```bash
   cd terraform
   ```

2. **Copy the example variables file**:

   ```bash
   # Windows PowerShell
   Copy-Item terraform.tfvars.example terraform.tfvars

   # Linux/Mac
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars`** with your values:
   ```hcl
   aws_region     = "us-east-1"
   app_name       = "fastapi-app"
   instance_type  = "t2.micro"
   key_pair_name  = "your-aws-key-pair-name"
   ssh_cidr       = "YOUR_IP/32"  # Restrict SSH access to your IP
   docker_image   = "your-dockerhub-username/fastapi-app:latest"
   api_key        = "your-secret-api-key-12345"
   ```

### Step 3: Deploy

1. **Initialize Terraform**:

   ```bash
   terraform init
   ```

2. **Review the deployment plan**:

   ```bash
   terraform plan
   ```

3. **Apply the configuration**:

   ```bash
   terraform apply
   ```

4. **Note the outputs** (instance IP, API URL, etc.)

### Step 4: Access the Deployed Application

After deployment, Terraform will output the API URL. Access it at:

- API: `http://<instance-ip>:5000`
- Docs: `http://<instance-ip>:5000/docs`

### Step 5: Teardown

To destroy all resources:

```bash
terraform destroy
```

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
- **Container name conflict**: Run `docker rm -f fastapi-app` to remove the existing container before starting a new one.

### Terraform deployment issues

- Verify AWS credentials: `aws sts get-caller-identity`
- Check key pair exists in the specified region
- Review security group rules
- Check EC2 instance logs via AWS Console

## License

This project is provided as-is for educational and development purposes.

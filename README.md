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

## 🚀 Local Development

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

## 🚀 Docker Usage

### Build the Docker Image

```bash
docker build -t fastapi-app:latest .
```
```bash
docker login
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

### Run the container via Docker-Hub

```bash
docker pull oriazulay/fastapi-app:latest
docker run oriazulay/fastapi-app:latest
```

 ## 🚀 AWS EC2 Deployment with Terraform

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
   ```powershell
   aws configure
   aws sts get-caller-identity  # Verify credentials work
   ```
3. **Terraform** installed (>= 1.0)
4. **Docker Hub account** (or other container registry)
5. **AWS Key Pair** for SSH access

## 📋 Prerequisites Checklist

-------------------------------------------------------
Before starting, we need to verify you have everything needed.
### Step 0.1: Check AWS CLI Installation
Open PowerShell and run:
```powershell
aws --version
```
---
### Step 0.2: Check AWS Credentials (Secret Keys)
AWS credentials are stored in a file. Let's check if they exist:
```powershell
# Check if credentials file exists
Test-Path "$env:USERPROFILE\.aws\credentials"

# If it returns True, credentials exist
# If it returns False, you need to configure AWS credentials
```
**If credentials exist, view them (optional - be careful!):**
```powershell
Get-Content "$env:USERPROFILE\.aws\credentials"
```
**What you should see:**
```
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

**If credentials DON'T exist, you need to configure them:**

#### Option A: Using AWS CLI Configure
```powershell
aws configure
```

You'll be asked for:
1. **AWS Access Key ID**: Your access key (starts with `AKIA...`) --> from IAM
2. **AWS Secret Access Key**: Your secret key (long string) --> from IAM downloaded
3. **Default region**: `us-east-1` (or your preferred region)
4. **Default output format**: `json` (just press Enter)

**Where to find your AWS credentials:**
1. Log into AWS Console: https://console.aws.amazon.com/
2. Click your username (top right) → **Security credentials**
3. Scroll to **Access keys** section
4. Click **Create access key** (if you don't have one)
--> This access key is from IAM in aws console
5. Download or copy:
   - **Access key ID** (starts with `AKIA...`)
   - **Secret access key** (long string - save this immediately, you can't see it again!)

#### Option B: Check if credentials are set as environment variables
```powershell
$env:AWS_ACCESS_KEY_ID
$env:AWS_SECRET_ACCESS_KEY
```

If these return values, your credentials are set via environment variables.

### Step 0.3: Verify AWS Credentials Work

Test if your credentials are valid:

```powershell
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

**If you see an error:**
- Your credentials are invalid or expired
- Re-run `aws configure` with correct credentials
- Or create new access keys in AWS Console


-------------------------------------------------------

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
   ```powershell
   cd terraform
   ```

2. **Verify Configuration File, Copy the example variables file**:

   Check your `terraform.tfvars` file:

   ```bash
   Get-Content terraform.tfvars
   ```

   **Expected content:**
   ```
   aws_region     = "us-east-1"
   app_name       = "fastapi-app"
   instance_type  = "t2.micro"
   key_pair_name  = "fastapi-app-key"
   api_key        = "your-secret-api-key-12345" # Your API KEY..
   ```

   **If the file doesn't exist or is missing values**
   1. Edit `terraform.tfvars` with your values
   2. **Important**: Make sure `key_pair_name` matches an existing EC2 key pair

   ### step 2.1 -Verify the key pair exists in your AWS account:

   ```powershell
   aws ec2 describe-key-pairs --region us-east-1 --key-names fastapi-app-key
   ```

   **If you see the key pair:**
   ```
   {
       "KeyPairs": [
           {
               "KeyName": "fastapi-app-key",
               ...
           }
       ]
   }
   ```
   ✅ Key pair exists - proceed to Step 3

   **If you see an error:**
   ```
   An error occurred (InvalidKeyPair.NotFound)
   ```
   ❌ Key pair doesn't exist - create it:
   
   ```powershell
   # Create the key pair
   aws ec2 create-key-pair --region us-east-1 --key-name fastapi-app-key --query 'KeyMaterial' --output text > fastapi-app-key.pem
   
   # Verify it was created
   aws ec2 describe-key-pairs --region us-east-1 --key-names fastapi-app-key
   ```

   **Note:** The `.pem` file is your private key - keep it secure! You'll need it for SSH access.

### Step 3: Deploy
----------------------------
1. **Initialize Terraform**:
   ```powershell
   terraform init
   ```
   **Expected output:**
   ```
   Initializing the backend...
   Initializing provider plugins...
   - Finding hashicorp/aws versions matching "~> 5.0"...
   - Finding hashicorp/http versions matching "~> 3.0"...
   - Installing hashicorp/aws v5.x.x...
   - Installing hashicorp/http v3.x.x...
   
   Terraform has been successfully initialized!
   ```
   
   **If you see errors:**
   - Check your internet connection
   - Verify Terraform is installed correctly
   - Check if you're in the correct directory
   
   **Time:** ~30 seconds to 1 minute

   **Validate your Terraform configuration:**

   ```powershell
   terraform validate
   ```
   **Expected output:**
   ```
   Success! The configuration is valid.
   ```
   
   **If you see errors:**
   - Read the error message carefully
   - Common issues:
     - Missing variables in `terraform.tfvars`
     - Syntax errors in `.tf` files
     - Missing required providers
   
----------------------------

2. **Review the deployment plan**:

  Preview what Terraform will create (this doesn't actually create anything):

```powershell
terraform plan
```

**What to look for:**
- Plan shows resources that will be created:
  - `+ aws_security_group.app_sg` (will be created)
  - `+ aws_instance.app_server` (will be created)
- Plan shows outputs that will be available:
  - `+ instance_public_ip`
  - `+ api_url`
  - etc.

**Expected output summary:**
```
Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + api_url             = (known after apply)
  + instance_public_ip  = (known after apply)
  ...
```

**Review the plan carefully:**
- ✅ Check that `key_name` matches your key pair
- ✅ Check that `instance_type` is `t2.micro` (free tier)
- ✅ Check that security group allows your IP only

**If everything looks good, proceed to Step 7.**

**Time:** ~10-30 seconds

----------------------------

3. **Apply the configuration**:

   ```bash
   terraform apply
   ```
**What happens:**
1. Terraform shows the plan again
2. Prompts: `Do you want to perform these actions?`
3. **Type:** `yes` and press Enter

**⚠️ IMPORTANT:**
- **Save the `instance_public_ip` value!** You'll need it for testing
- **Deployment takes 3-5 minutes** - be patient!
- The EC2 instance needs time to:
  1. Launch (~1-2 minutes)
  2. Install Docker (~1 minute)
  3. Build and start the application (~1-2 minutes)

**Time:** 3-5 minutes total


----------------------------

4. **Note the outputs** (instance IP, API URL, etc.)

### Step 4: Access the Deployed Application

**Wait 2-3 minutes after `terraform apply` completes** before testing.

The application needs time to:
- Install Docker on the EC2 instance
- Build the Docker image
- Start the container

After deployment, Terraform will output the API URL. Access it at:

- API: `http://<instance-ip>:5000`
- Docs: `http://<instance-ip>:5000/docs`

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


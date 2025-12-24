# FastAPI Shared State Application

A Python FastAPI application with shared state management, logging, and API key authentication. The application is containerized with Docker and deployed to AWS EC2 using Terraform with automated infrastructure provisioning.

## Features

- **GET /status**: Returns current state (counter and message) with server metadata (timestamp, uptime)
- **POST /update**: Updates shared state with JSON validation and API key authentication
- **GET /logs**: Returns paginated list of all state updates with query parameters
- **SQLite Database**: Persistent storage for state and logs (WAL mode for concurrency)
- **API Key Authentication**: Secure access to update endpoint via `X-API-Key` header
- **Docker Support**: Multi-stage build for optimized container images
- **Terraform Deployment**: Fully automated AWS EC2 deployment with IP-restricted security

## Project Structure

```
.
├── app/                          # Application package
│   ├── __init__.py              # Package initializer
│   ├── main.py                  # FastAPI application factory with lifespan
│   ├── routes.py                # API endpoint definitions (/status, /update, /logs)
│   ├── schemas.py               # Pydantic request/response models with validation
│   ├── database.py              # SQLite database operations (CRUD + logging)
│   ├── dependencies.py          # Authentication dependency (API key verification)
│   └── config.py                # Application configuration and settings
├── tests/                        # Comprehensive test suite
│   ├── conftest.py              # Shared pytest fixtures (client, auth, temp_db)
│   ├── unit/                    # Unit tests (isolated component testing)
│   │   ├── test_database.py     # Database function tests
│   │   └── test_schemas.py      # Pydantic model validation tests
│   ├── integration/             # Integration tests (API endpoint testing)
│   │   └── test_api.py          # Full API endpoint tests with authentication
│   └── e2e/                     # End-to-end tests (workflow testing)
│       ├── test_workflows.py    # Complete user workflow tests
│       └── test_deployed.py     # Live AWS deployment tests
├── terraform/                    # Infrastructure as Code
│   ├── ec2.tf                   # EC2 instance and security group
│   ├── s3.tf                    # S3 bucket for app files
│   ├── iam.tf                   # IAM roles and policies
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output definitions
│   ├── locals.tf                # Local values (IP detection)
│   ├── providers.tf             # AWS provider configuration
│   ├── versions.tf              # Terraform version constraints
│   ├── user_data.sh.tpl         # EC2 bootstrap script with error handling
│   └── terraform.tfvars         # Variable values (git-ignored)
├── Dockerfile                   # Multi-stage Docker build
├── requirements.txt             # Python dependencies
└── README.md                    # This file
```

---

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
   uvicorn app.main:app --host 0.0.0.0 --port 5000 --reload
   ```

5. **Access the API**:
   - API Base URL: `http://localhost:5000`
   - Interactive API Docs: `http://localhost:5000/docs`
   - Alternative Docs: `http://localhost:5000/redoc`

---

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
Content-Type: application/json
```

**Request Body**:
```json
{
  "counter": 5,
  "message": "Updated message"
}
```

**Validation Rules**:
- `counter` must be an integer (optional)
- `message` must be a string (optional)
- At least one field must be provided

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
- `400 Bad Request`: Invalid input validation (e.g., wrong types, missing fields)
- `401 Unauthorized`: Missing or invalid API key
- `422 Unprocessable Entity`: Malformed JSON payload

### GET /logs

Returns paginated list of all updates.

**Query Parameters**:
- `page` (optional, default: 1, min: 1): Page number
- `limit` (optional, default: 10, min: 1, max: 100): Number of logs per page

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

---

## 🐳 Docker Usage

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

### Run from Docker Hub

```bash
docker pull oriazulay/fastapi-app:latest
docker run -d -p 5000:5000 oriazulay/fastapi-app:latest
```

---

## ☁️ AWS EC2 Deployment with Terraform

### Prerequisites

1. **AWS Account** with appropriate permissions (EC2, S3, IAM)
2. **AWS CLI** configured with credentials:
   ```powershell
   aws configure
   aws sts get-caller-identity  # Verify credentials work
   ```
3. **Terraform** installed (>= 1.0)
4. **AWS Key Pair** for SSH access

### Prerequisites Checklist

#### Step 0.1: Check AWS CLI Installation
```powershell
aws --version
```

#### Step 0.2: Check AWS Credentials
```powershell
# Check if credentials file exists
Test-Path "$env:USERPROFILE\.aws\credentials"

# If True, verify they work:
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

**If credentials don't exist:**
```powershell
aws configure
```

You'll need:
1. **AWS Access Key ID** (from IAM console)
2. **AWS Secret Access Key** (from IAM console)
3. **Default region**: `us-east-1`
4. **Default output format**: `json`

### Step 1: Configure Terraform

1. **Navigate to terraform directory**:
   ```powershell
   cd terraform
   ```

2. **Check/create terraform.tfvars**:
   ```powershell
   Get-Content terraform.tfvars
   ```

   **Required content:**
   ```hcl
   aws_region     = "us-east-1"
   app_name       = "fastapi-app"
   instance_type  = "t2.micro"
   key_pair_name  = "fastapi-app-key"
   api_key        = "your-secret-api-key-12345"
   ```

3. **Verify key pair exists**:
   ```powershell
   aws ec2 describe-key-pairs --region us-east-1 --key-names fastapi-app-key
   ```

   **If key pair doesn't exist, create it:**
   ```powershell
   aws ec2 create-key-pair --region us-east-1 --key-name fastapi-app-key --query 'KeyMaterial' --output text > fastapi-app-key.pem
   ```

### Step 2: Deploy

1. **Initialize Terraform**:
   ```powershell
   terraform init
   ```

2. **Validate configuration**:
   ```powershell
   terraform validate
   ```

3. **Review the plan**:
   ```powershell
   terraform plan
   ```

   **What will be created:**
   - EC2 instance (t2.micro, free tier eligible)
   - Security group (restricted to your IP)
   - S3 bucket (for application files)
   - IAM role (for EC2 to access S3)

4. **Apply the configuration**:
   ```powershell
   terraform apply
   ```

   Type `yes` when prompted.

   **⚠️ Deployment takes 3-5 minutes.** The EC2 instance needs time to:
   - Launch and initialize
   - Install Docker
   - Download application files from S3
   - Build and start the container

5. **Note the outputs**:
   ```
   api_url = "http://<instance-ip>:5000"
   instance_public_ip = "<instance-ip>"
   status_endpoint = "http://<instance-ip>:5000/status"
   ```

### Step 3: Verify Deployment

Wait 2-3 minutes after `terraform apply` completes, then test:

```powershell
# Get status
curl http://<instance-ip>:5000/status

# Update state
curl -X POST http://<instance-ip>:5000/update `
  -H "X-API-Key: your-secret-api-key-12345" `
  -H "Content-Type: application/json" `
  -d '{"counter": 10, "message": "Hello from AWS"}'

# Get logs
curl http://<instance-ip>:5000/logs
```

### Step 4: Teardown

**⚠️ Always destroy resources when done to avoid AWS charges!**

```powershell
terraform destroy
```

Type `yes` when prompted. This will:
- Terminate the EC2 instance
- Delete the security group
- Delete the S3 bucket and contents
- Delete the IAM role

---

## 🗄️ Database

The application uses SQLite for persistent storage:

- **Database file**: `app.db` (created automatically)
- **Journal mode**: WAL (Write-Ahead Logging) for better concurrency
- **Tables**:
  - `shared_state`: Current state of counter and message
  - `update_logs`: History of all updates with timestamps

---

## 🎨 Design Decisions and Trade-offs

### Framework Choice: FastAPI over Flask

**Decision**: Used FastAPI instead of Flask.

**Rationale**:
- Built-in request/response validation with Pydantic
- Automatic OpenAPI documentation (`/docs`, `/redoc`)
- Native async support for better performance
- Type hints improve code quality and IDE support

**Trade-off**: Slightly higher learning curve than Flask, but better developer experience.

### Database: SQLite with WAL Mode

**Decision**: Used SQLite instead of in-memory storage.

**Rationale**:
- Persistent storage survives container restarts
- WAL mode enables concurrent reads during writes
- Zero configuration required
- Lightweight and embedded

**Trade-off**: Not suitable for high-concurrency production workloads. For production, consider PostgreSQL or managed databases (RDS).

### Deployment: S3-based File Transfer

**Decision**: Upload application files to S3, then download on EC2 during bootstrap.

**Rationale**:
- Avoids embedding large files in user_data (16KB limit)
- More reliable than git clone (no SSH keys needed)
- Application code versioned alongside infrastructure
- IAM roles provide secure access without credentials

**Trade-off**: Adds complexity with S3 bucket and IAM roles. Alternative would be Docker Hub (used for local testing).

### Security: IP-Restricted Security Group

**Decision**: Automatically detect Terraform runner's IP and restrict access.

**Rationale**:
- Only the deploying machine can access the application
- Uses ipify.org API for reliable IP detection
- Prevents unauthorized access to the API

**Trade-off**: If your IP changes, you need to re-run `terraform apply`. Not suitable for public-facing applications.

### Docker: Multi-Stage Build

**Decision**: Used multi-stage Dockerfile.

**Rationale**:
- Separates build dependencies from runtime
- Smaller final image size (~150MB vs ~400MB)
- Build tools not included in production image

**Trade-off**: Slightly more complex Dockerfile, but significant image size reduction.

### Application Structure: Modular Package

**Decision**: Organized code into `app/` package with separate modules.

**Rationale**:
- Clear separation of concerns (routes, schemas, database, config)
- Easier to test individual components
- Follows FastAPI best practices
- Scales better as application grows

**Trade-off**: More files to manage than single-file approach.

---

## 🔒 Security Considerations

1. **API Key**: Change the default API key in production
2. **IP Restriction**: Security group only allows your IP address
3. **HTTPS**: For production, add a reverse proxy (nginx/ALB) with SSL/TLS
4. **Secrets Management**: Consider AWS Secrets Manager for API keys
5. **Database**: For production, use managed database services (RDS)
6. **Sensitive Variables**: API key marked as `sensitive` in Terraform

---

## 🔧 Troubleshooting

### Application won't start
- Check if port 5000 is available: `netstat -ano | findstr 5000`
- Verify Python version: `python --version` (requires 3.11+)
- Check database file permissions

### Docker issues
- Ensure Docker is running: `docker info`
- Check container logs: `docker logs fastapi-app`
- Verify port mapping: `docker ps`

### Terraform deployment issues
- Verify AWS credentials: `aws sts get-caller-identity`
- Check key pair exists: `aws ec2 describe-key-pairs --region us-east-1`
- Check instance logs in AWS Console (Actions → Monitor and troubleshoot → Get system log)
- Review `/var/log/app-deploy.log` on the EC2 instance

### Cannot connect to deployed API
- Wait 3-5 minutes after deployment
- Check if your IP changed (re-run `terraform apply`)
- Verify instance is running: `aws ec2 describe-instances --region us-east-1`

---

## 🧪 Testing

The project includes a comprehensive test suite organized into three levels: unit tests, integration tests, and end-to-end tests.

### Running Tests

```bash
# Install test dependencies (included in requirements.txt)
pip install -r requirements.txt

# Run all tests
pytest

# Run with verbose output
pytest -v

# Run specific test levels
pytest tests/unit/           # Unit tests only
pytest tests/integration/    # Integration tests only
pytest tests/e2e/            # End-to-end tests only

# Run with coverage report
pytest --cov=app --cov-report=html

# Run a specific test file
pytest tests/unit/test_database.py -v

# Run a specific test class
pytest tests/unit/test_schemas.py::TestUpdateRequest -v
```

### Test Structure

```
tests/
├── conftest.py              # Shared fixtures for all tests
├── unit/
│   ├── test_database.py     # Database function tests
│   └── test_schemas.py      # Pydantic validation tests
├── integration/
│   └── test_api.py          # API endpoint tests
└── e2e/
    ├── test_workflows.py    # Complete workflow tests
    └── test_deployed.py     # Live deployment tests
```

---

### Shared Fixtures (`conftest.py`)

Provides reusable test fixtures for all test files:

| Fixture | Scope | Description |
|---------|-------|-------------|
| `api_key` | session | Returns the configured API key for authenticated requests |
| `client` | function | FastAPI TestClient with proper lifespan management |
| `auth_headers` | function | Pre-configured `{"X-API-Key": ...}` headers |
| `temp_db` | function | Creates isolated temporary SQLite database, cleans up after test |
| `clean_state` | function | Resets shared state to known values before test |

---

### Unit Tests

#### `tests/unit/test_database.py`

Tests the SQLite database operations in isolation using temporary databases.

| Test Class | Tests | Description |
|------------|-------|-------------|
| `TestInitDb` | 4 tests | Database initialization and table creation |
| `TestGetCurrentState` | 3 tests | State retrieval function |
| `TestUpdateState` | 6 tests | State update and logging |
| `TestGetLogs` | 6 tests | Log retrieval and pagination |

**Key tests:**
- `test_creates_shared_state_table` - Verifies `shared_state` table is created
- `test_creates_update_logs_table` - Verifies `update_logs` table is created
- `test_initial_state_has_default_values` - Counter starts at 0, message is empty
- `test_updates_counter_only` - Updates counter without affecting message
- `test_preserves_unchanged_field` - Partial updates don't overwrite other fields
- `test_creates_log_entry` - Every update creates a log entry
- `test_respects_limit` - Pagination limit is honored
- `test_total_pages_calculation` - Correct page count calculation

#### `tests/unit/test_schemas.py`

Tests Pydantic model validation rules.

| Test Class | Tests | Description |
|------------|-------|-------------|
| `TestUpdateRequest` | 10 tests | Request validation rules |
| `TestStatusResponse` | 2 tests | Response model structure |
| `TestLogEntry` | 2 tests | Log entry model |
| `TestLogsResponse` | 2 tests | Paginated logs response |

**Key tests:**
- `test_counter_must_be_integer` - Rejects non-integer counter values
- `test_message_must_be_string` - Rejects non-string message values
- `test_at_least_one_field_required` - Empty requests are rejected
- `test_zero_counter_is_valid` - Zero is a valid counter value
- `test_negative_counter_is_valid` - Negative counters are allowed
- `test_empty_message_is_valid` - Empty string is valid for message

---

### Integration Tests

#### `tests/integration/test_api.py`

Tests API endpoints with the FastAPI TestClient.

| Test Class | Tests | Description |
|------------|-------|-------------|
| `TestRootEndpoint` | 4 tests | Root endpoint (`/`) behavior |
| `TestStatusEndpoint` | 6 tests | GET `/status` endpoint |
| `TestUpdateEndpoint` | 9 tests | POST `/update` endpoint |
| `TestLogsEndpoint` | 11 tests | GET `/logs` endpoint |
| `TestAuthenticationDependency` | 2 tests | API key authentication behavior |

**Key tests:**
- `test_requires_api_key` - Update endpoint requires X-API-Key header
- `test_rejects_invalid_api_key` - Wrong API key returns 401
- `test_update_counter_only` - Can update just the counter
- `test_update_message_only` - Can update just the message
- `test_returns_old_and_new_state` - Response includes before/after values
- `test_empty_request_rejected` - Empty JSON body returns 422
- `test_default_pagination` - Default page=1, limit=10
- `test_limit_too_high` - Limit > 100 is rejected
- `test_case_sensitive_header_name` - Header names are case-insensitive

---

### End-to-End Tests

#### `tests/e2e/test_workflows.py`

Tests complete user workflows and scenarios.

| Test Class | Tests | Description |
|------------|-------|-------------|
| `TestStateUpdateWorkflow` | 3 tests | Update → Verify workflows |
| `TestLoggingWorkflow` | 4 tests | Update → Log verification |
| `TestErrorRecoveryWorkflow` | 3 tests | Error handling and recovery |
| `TestConcurrentAccessSimulation` | 2 tests | Rapid sequential operations |
| `TestApiDiscoverability` | 3 tests | API documentation availability |

**Key tests:**
- `test_update_then_verify_status` - Full update and verification cycle
- `test_multiple_updates_last_wins` - Sequential updates result in last value
- `test_partial_update_preserves_other_field` - Counter-only update keeps message
- `test_updates_create_log_entries` - Each update adds to log
- `test_log_entry_contains_update_details` - Logs have old/new values
- `test_logs_ordered_by_timestamp_desc` - Newest logs first
- `test_pagination_workflow` - Multi-page log navigation
- `test_invalid_update_does_not_change_state` - Failed requests don't modify state
- `test_consecutive_operations_after_error` - System recovers after errors
- `test_rapid_sequential_updates` - Handles rapid requests
- `test_openapi_schema_available` - `/openapi.json` is accessible

#### `tests/e2e/test_deployed.py`

Tests against the live AWS deployment (requires running EC2 instance).

| Test Class | Tests | Description |
|------------|-------|-------------|
| `TestDeployedInstance` | 7 tests | Live endpoint verification |
| `TestDeployedHealthCheck` | 2 tests | Performance and health checks |

**Key tests:**
- `test_instance_is_reachable` - EC2 instance responds
- `test_status_endpoint` - `/status` works on deployed instance
- `test_update_with_auth` - Authenticated updates work
- `test_status_reflects_update` - State persists on AWS
- `test_response_time` - Response under 2 seconds
- `test_uptime_positive` - Application uptime is tracked

**Running deployed tests:**
```bash
# After terraform apply:
pytest tests/e2e/test_deployed.py -v

# Or with explicit URL:
API_URL=http://1.2.3.4:5000 API_KEY=your-key pytest tests/e2e/test_deployed.py -v
```

---

### Manual API Testing

#### Using curl

```bash
# Get status
curl http://localhost:5000/status

# Update state
curl -X POST http://localhost:5000/update \
  -H "X-API-Key: your-secret-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{"counter": 10, "message": "Hello from API"}'

# Get logs with pagination
curl "http://localhost:5000/logs?page=1&limit=10"
```

#### Using Python

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

---

## 📄 License

This project is provided as-is for educational and development purposes.

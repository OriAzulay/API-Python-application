# Terraform Deployment Guide

This guide walks you through deploying the FastAPI application to AWS EC2 using Terraform.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
   ```bash
   aws configure
   ```
3. **Terraform** installed (>= 1.0)
   - Download from: https://www.terraform.io/downloads
4. **AWS Key Pair** created in your target region
   - Create via AWS Console: EC2 → Key Pairs → Create key pair
   - Save the `.pem` file securely

## Features

- ✅ **Automatic IP Detection**: Your public IP is automatically detected and used for security group rules
- ✅ **Security**: Only allows inbound traffic from your machine's IP address
- ✅ **Free Tier**: Uses t2.micro instance (free tier eligible)
- ✅ **Docker Build**: Builds Docker image directly on EC2 (no registry needed)
- ✅ **Multi-stage Build**: Optimized Docker image size

## Deployment Steps

### Step 1: Configure Terraform Variables

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
   aws_region     = "us-east-1"           # Your preferred AWS region
   app_name       = "fastapi-app"         # Application name
   instance_type  = "t2.micro"            # Free tier eligible
   key_pair_name  = "your-key-pair-name" # Your AWS key pair name
   api_key        = "your-secret-api-key-12345"  # API key for authentication
   ```

### Step 2: Initialize Terraform

```bash
terraform init
```

This downloads the required providers (AWS, HTTP).

### Step 3: Review Deployment Plan

```bash
terraform plan
```

Review what will be created:
- EC2 instance (t2.micro)
- Security group (restricted to your IP)
- All necessary configurations

### Step 4: Deploy

```bash
terraform apply
```

Type `yes` when prompted. This will:
1. Detect your public IP address
2. Create security group allowing only your IP
3. Launch EC2 instance
4. Install Docker on the instance
5. Build the Docker image
6. Run the containerized application

**Deployment takes approximately 3-5 minutes.**

### Step 5: Note the Outputs

After deployment, Terraform will output:
- `instance_public_ip`: Public IP address of the EC2 instance
- `api_url`: Full API URL
- `status_endpoint`: Status endpoint URL
- `terraform_runner_ip`: Your IP address (for verification)

**Save the `instance_public_ip` for verification!**

## Verification

### Option 1: Using Verification Scripts

**Linux/Mac:**
```bash
chmod +x verify.sh
./verify.sh <EC2_PUBLIC_IP> <API_KEY>
```

**Windows PowerShell:**
```powershell
.\verify.ps1 -EC2IP <EC2_PUBLIC_IP> -APIKey <API_KEY>
```

### Option 2: Manual Verification

1. **Get initial status**:
   ```bash
   curl http://<EC2_PUBLIC_IP>:5000/status
   ```

2. **Update state**:
   ```bash
   curl -X POST http://<EC2_PUBLIC_IP>:5000/update \
     -H "X-API-Key: your-secret-api-key-12345" \
     -H "Content-Type: application/json" \
     -d '{"counter": 42, "message": "Hello from Terraform!"}'
   ```

3. **Verify updated status**:
   ```bash
   curl http://<EC2_PUBLIC_IP>:5000/status
   ```

4. **Check logs**:
   ```bash
   curl http://<EC2_PUBLIC_IP>:5000/logs?page=1&limit=10
   ```

## Teardown

To destroy all resources and avoid AWS charges:

### Option 1: Using Teardown Scripts

**Linux/Mac:**
```bash
chmod +x teardown.sh
./teardown.sh
```

**Windows PowerShell:**
```powershell
.\teardown.ps1
```

### Option 2: Manual Teardown

```bash
terraform destroy
```

Type `yes` when prompted. This will:
- Terminate the EC2 instance
- Delete the security group
- Clean up all resources

## Troubleshooting

### Cannot connect to API

1. **Check security group**: Ensure your IP hasn't changed
   - If your IP changed, update the security group manually or re-run `terraform apply`

2. **Check instance status**: 
   ```bash
   aws ec2 describe-instances --instance-ids <instance-id>
   ```

3. **Check application logs** (SSH into instance):
   ```bash
   ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
   docker logs fastapi-app
   ```

### Application not starting

1. **Check Docker logs**:
   ```bash
   ssh -i your-key.pem ec2-user@<EC2_PUBLIC_IP>
   docker ps -a
   docker logs fastapi-app
   ```

2. **Check user data logs**:
   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```

### IP Address Changed

If your IP address changes after deployment:

1. **Update security group manually** via AWS Console, OR
2. **Re-run terraform apply** (it will detect your new IP)

## Security Notes

- The security group only allows traffic from your current public IP
- SSH access is also restricted to your IP
- API key is passed as environment variable (consider using AWS Secrets Manager for production)
- For production, consider:
  - Using AWS Secrets Manager for API keys
  - Adding HTTPS with a load balancer
  - Using VPC with private subnets
  - Implementing CloudWatch monitoring

## Cost Estimation

- **t2.micro instance**: Free tier eligible (750 hours/month for 12 months)
- **Data transfer**: Minimal for testing
- **Storage**: EBS volume included in free tier

**Total cost for free tier: $0/month** (within free tier limits)

## Next Steps

- Monitor application: Set up CloudWatch alarms
- Scale horizontally: Use Auto Scaling Groups
- Add HTTPS: Use Application Load Balancer with ACM certificate
- CI/CD: Integrate with GitHub Actions or AWS CodePipeline




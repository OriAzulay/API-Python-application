# Manual Terraform Deployment Guide - Step by Step

This guide will walk you through every step manually, including how to check and find your AWS credentials.

---

## 📋 Prerequisites Checklist

Before starting, we need to verify you have everything needed.

### Step 0.1: Check AWS CLI Installation

Open PowerShell and run:
```powershell
aws --version
```

**Expected output:**
```
aws-cli/2.x.x Python/x.x.x Windows/10
```

**If you see an error:**
- Install AWS CLI from: https://aws.amazon.com/cli/
- Restart PowerShell after installation

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
1. **AWS Access Key ID**: Your access key (starts with `AKIA...`)
2. **AWS Secret Access Key**: Your secret key (long string)
3. **Default region**: `us-east-1` (or your preferred region)
4. **Default output format**: `json` (just press Enter)

**Where to find your AWS credentials:**
1. Log into AWS Console: https://console.aws.amazon.com/
2. Click your username (top right) → **Security credentials**
3. Scroll to **Access keys** section
4. Click **Create access key** (if you don't have one)
5. Download or copy:
   - **Access key ID** (starts with `AKIA...`)
   - **Secret access key** (long string - save this immediately, you can't see it again!)

#### Option B: Check if credentials are set as environment variables
```powershell
$env:AWS_ACCESS_KEY_ID
$env:AWS_SECRET_ACCESS_KEY
```

If these return values, your credentials are set via environment variables.

---

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

---

### Step 0.4: Check Terraform Installation

```powershell
terraform --version
```

**Expected output:**
```
Terraform v1.x.x
```

**If you see an error:**
- Install Terraform from: https://www.terraform.io/downloads
- Add Terraform to your PATH

---

## 🚀 Deployment Steps

### Step 1: Navigate to Terraform Directory

```powershell
# Change to your project directory
cd C:\Users\ori\Desktop\app\terraform

# Verify you're in the right place
Get-Location
# Should show: C:\Users\ori\Desktop\app\terraform

# List files to confirm
Get-ChildItem
# You should see: main.tf, variables.tf, terraform.tfvars, etc.
```

---

### Step 2: Verify Configuration File

Check your `terraform.tfvars` file:

```powershell
Get-Content terraform.tfvars
```

**Expected content:**
```
aws_region     = "us-east-1"
app_name       = "fastapi-app"
instance_type  = "t2.micro"
key_pair_name  = "fastapi-app-key"
api_key        = "4VvjxmNUFLAdQkU0xcKcyWuFDvmPZptVCXRmgzxC"
```

**If the file doesn't exist or is missing values:**
1. Copy the example file:
   ```powershell
   Copy-Item terraform.tfvars.example terraform.tfvars
   ```
2. Edit `terraform.tfvars` with your values
3. **Important**: Make sure `key_pair_name` matches an existing EC2 key pair

---

### Step 3: Check EC2 Key Pair Exists

Verify the key pair exists in your AWS account:

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
✅ Key pair exists - proceed to Step 4

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

---

### Step 4: Initialize Terraform

Initialize Terraform (downloads providers and sets up backend):

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

---

### Step 5: Validate Configuration

Validate your Terraform configuration:

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

---

### Step 6: Review Deployment Plan (Dry Run)

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

---

### Step 7: Apply Configuration (Deploy)

Deploy the infrastructure:

```powershell
terraform apply
```

**What happens:**
1. Terraform shows the plan again
2. Prompts: `Do you want to perform these actions?`
3. **Type:** `yes` and press Enter

**Expected output:**
```
aws_security_group.app_sg: Creating...
aws_security_group.app_sg: Creation complete after 2s [id=sg-xxxxx]

aws_instance.app_server: Creating...
aws_instance.app_server: Still creating... [10s elapsed]
aws_instance.app_server: Still creating... [20s elapsed]
aws_instance.app_server: Still creating... [30s elapsed]
...
aws_instance.app_server: Creation complete after 1m30s [id=i-xxxxx]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

instance_public_ip = "54.123.45.67"
api_url = "http://54.123.45.67:5000"
status_endpoint = "http://54.123.45.67:5000/status"
update_endpoint = "http://54.123.45.67:5000/update"
logs_endpoint = "http://54.123.45.67:5000/logs"
```

**⚠️ IMPORTANT:**
- **Save the `instance_public_ip` value!** You'll need it for testing
- **Deployment takes 3-5 minutes** - be patient!
- The EC2 instance needs time to:
  1. Launch (~1-2 minutes)
  2. Install Docker (~1 minute)
  3. Build and start the application (~1-2 minutes)

**Time:** 3-5 minutes total

---

### Step 8: Wait for Application to Start

**Wait 2-3 minutes after `terraform apply` completes** before testing.

The application needs time to:
- Install Docker on the EC2 instance
- Build the Docker image
- Start the container

**Optional - Check instance status:**
```powershell
# Get instance ID
$instanceId = terraform output -raw instance_id

# Check instance state
aws ec2 describe-instances --region us-east-1 --instance-ids $instanceId --query 'Reservations[0].Instances[0].State.Name' --output text
# Should return: running
```

---

### Step 9: Get Instance IP Address

Get the public IP address of your EC2 instance:

```powershell
terraform output instance_public_ip
```

**Or get all outputs:**
```powershell
terraform output
```

**Save this IP address!** You'll need it for testing.

---

### Step 10: Test the Application

#### Test 1: Get Status

```powershell
$ip = terraform output -raw instance_public_ip
Invoke-RestMethod -Uri "http://$ip:5000/status"
```

**Expected response:**
```json
{
  "counter": 0,
  "message": "",
  "timestamp": "2024-...",
  "uptime_seconds": 123.45
}
```

**If you get an error:**
- Wait another minute (application might still be starting)
- Check if your IP address has changed (security group might need update)
- Verify the instance is running

#### Test 2: Update State

```powershell
$ip = terraform output -raw instance_public_ip
$apiKey = "4VvjxmNUFLAdQkU0xcKcyWuFDvmPZptVCXRmgzxC"

$headers = @{
    "X-API-Key" = $apiKey
    "Content-Type" = "application/json"
}

$body = @{
    counter = 42
    message = "Hello from Terraform deployment!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://$ip:5000/update" -Method Post -Headers $headers -Body $body
```

**Expected response:**
```json
{
  "success": true,
  "message": "State updated successfully",
  "old_state": {
    "counter": 0,
    "message": ""
  },
  "new_state": {
    "counter": 42,
    "message": "Hello from Terraform deployment!"
  }
}
```

#### Test 3: Verify Updated State

```powershell
$ip = terraform output -raw instance_public_ip
Invoke-RestMethod -Uri "http://$ip:5000/status"
```

Should show the updated counter and message.

#### Test 4: Get Logs

```powershell
$ip = terraform output -raw instance_public_ip
Invoke-RestMethod -Uri "http://$ip:5000/logs?page=1&limit=10"
```

**Expected response:**
```json
{
  "logs": [
    {
      "id": 1,
      "timestamp": "2024-...",
      "old_counter": 0,
      "new_counter": 42,
      "old_message": "",
      "new_message": "Hello from Terraform deployment!",
      "update_type": "counter, message"
    }
  ],
  "page": 1,
  "limit": 10,
  "total": 1,
  "total_pages": 1
}
```

#### Test 5: Open API Documentation

Open in your browser:
```
http://<INSTANCE_IP>:5000/docs
```

Replace `<INSTANCE_IP>` with your actual IP from Step 9.

---

## 🧹 Cleanup (When Done Testing)

**Always destroy resources when done to avoid AWS charges!**

### Step 11: Destroy Resources

```powershell
terraform destroy
```

**What happens:**
1. Terraform shows what will be destroyed
2. Prompts: `Do you really want to destroy all resources?`
3. **Type:** `yes` and press Enter

**Expected output:**
```
aws_instance.app_server: Destroying...
aws_instance.app_server: Destruction complete after 1m30s
aws_security_group.app_sg: Destroying...
aws_security_group.app_sg: Destruction complete after 2s

Destroy complete! Resources: 2 destroyed.
```

✅ All resources cleaned up!

---

## 🔍 Troubleshooting

### Issue: "Error: InvalidKeyPair.NotFound"
**Solution:**
```powershell
# Check if key pair exists
aws ec2 describe-key-pairs --region us-east-1 --key-names fastapi-app-key

# If it doesn't exist, create it
aws ec2 create-key-pair --region us-east-1 --key-name fastapi-app-key --query 'KeyMaterial' --output text > fastapi-app-key.pem
```

### Issue: "Error: InvalidClientTokenId"
**Solution:** Your AWS credentials are invalid or expired
```powershell
# Re-configure AWS credentials
aws configure

# Or check if credentials file exists
Test-Path "$env:USERPROFILE\.aws\credentials"
```

### Issue: "Cannot connect to API"
**Solution:**
1. Wait 3-5 minutes after deployment
2. Check if your IP changed:
   ```powershell
   # Get your current IP
   (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip
   
   # If it changed, update security group by re-running:
   terraform apply
   ```
3. Check instance status:
   ```powershell
   aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Name,Values=fastapi-app" --query 'Reservations[0].Instances[0].State.Name'
   ```

### Issue: "Error: creating EC2 Instance"
**Solution:**
- Check your AWS account limits
- Verify region availability
- Check if you have permissions to create EC2 instances

---

## 📝 Quick Reference

### Essential Commands
```powershell
# Navigate to terraform directory
cd C:\Users\ori\Desktop\app\terraform

# Initialize
terraform init

# Validate
terraform validate

# Plan (dry run)
terraform plan

# Deploy
terraform apply

# Get outputs
terraform output
terraform output instance_public_ip

# Destroy (cleanup)
terraform destroy
```

### Check AWS Credentials
```powershell
# Check if credentials file exists
Test-Path "$env:USERPROFILE\.aws\credentials"

# View credentials location
Get-Content "$env:USERPROFILE\.aws\credentials"

# Test credentials
aws sts get-caller-identity

# Configure credentials
aws configure
```

### Check Key Pair
```powershell
# List all key pairs
aws ec2 describe-key-pairs --region us-east-1

# Check specific key pair
aws ec2 describe-key-pairs --region us-east-1 --key-names fastapi-app-key

# Create key pair (if needed)
aws ec2 create-key-pair --region us-east-1 --key-name fastapi-app-key --query 'KeyMaterial' --output text > fastapi-app-key.pem
```

---

## ✅ Deployment Checklist

Before deploying:
- [ ] AWS CLI installed
- [ ] AWS credentials configured
- [ ] AWS credentials tested (`aws sts get-caller-identity`)
- [ ] Terraform installed
- [ ] `terraform.tfvars` configured
- [ ] EC2 key pair exists
- [ ] In terraform directory

During deployment:
- [ ] `terraform init` completed
- [ ] `terraform validate` passed
- [ ] `terraform plan` reviewed
- [ ] `terraform apply` approved with `yes`
- [ ] Waited 3-5 minutes for deployment

After deployment:
- [ ] Got instance IP from `terraform output`
- [ ] Waited 2-3 minutes for app to start
- [ ] Tested `/status` endpoint
- [ ] Tested `/update` endpoint
- [ ] Tested `/logs` endpoint
- [ ] Opened `/docs` in browser

When done:
- [ ] Ran `terraform destroy`
- [ ] Confirmed all resources destroyed

---

## 🎯 Summary

**Complete command sequence:**
```powershell
# 1. Check credentials
aws sts get-caller-identity

# 2. Navigate to terraform
cd C:\Users\ori\Desktop\app\terraform

# 3. Initialize
terraform init

# 4. Validate
terraform validate

# 5. Plan
terraform plan

# 6. Deploy (type 'yes' when prompted)
terraform apply

# 7. Get IP (after deployment)
terraform output instance_public_ip

# 8. Test (wait 2-3 minutes first)
$ip = terraform output -raw instance_public_ip
Invoke-RestMethod -Uri "http://$ip:5000/status"

# 9. Cleanup (when done)
terraform destroy
```

**Total time:** ~5-10 minutes (including wait times)

---

## 📚 Additional Resources

- **AWS Console**: https://console.aws.amazon.com/
- **Terraform Docs**: https://www.terraform.io/docs
- **AWS EC2 Docs**: https://docs.aws.amazon.com/ec2/

---

**You're ready to deploy! Follow the steps above one by one.** 🚀


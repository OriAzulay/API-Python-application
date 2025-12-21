# Terraform Configuration for FastAPI Deployment

This directory contains Terraform configuration to deploy the FastAPI application to AWS EC2.

## Quick Start

1. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Deploy**:
   ```bash
   terraform init
   terraform apply
   ```

3. **Verify** (after deployment):
   ```bash
   # Linux/Mac
   ./verify.sh <EC2_IP> <API_KEY>
   
   # Windows PowerShell
   .\verify.ps1 -EC2IP <EC2_IP> -APIKey <API_KEY>
   ```

4. **Teardown**:
   ```bash
   # Linux/Mac
   ./teardown.sh
   
   # Windows PowerShell
   .\teardown.ps1
   ```

## Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `terraform.tfvars.example` - Example variables file
- `user_data.sh.tpl` - EC2 user data template
- `verify.sh` / `verify.ps1` - Verification scripts
- `teardown.sh` / `teardown.ps1` - Teardown scripts
- `DEPLOYMENT.md` - Detailed deployment guide

## Key Features

- ✅ Automatic IP detection (no manual IP configuration needed)
- ✅ Security group restricted to your IP only
- ✅ Docker image built on EC2 (no registry required)
- ✅ Free tier eligible (t2.micro)
- ✅ Multi-stage Docker build for optimization

See `DEPLOYMENT.md` for detailed instructions.



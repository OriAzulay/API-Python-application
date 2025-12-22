# Comprehensive AWS EC2 and Terraform Connection Test Script
# This script tests all components needed for deployment

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AWS EC2 & Terraform Connection Test" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$allTestsPassed = $true

# Test 1: AWS CLI Installation
Write-Host "Test 1: AWS CLI Installation" -ForegroundColor Yellow
try {
    $awsVersion = aws --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ AWS CLI installed: $awsVersion" -ForegroundColor Green
    } else {
        Write-Host "  ✗ AWS CLI not found" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "  ✗ AWS CLI not found" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 2: AWS Credentials
Write-Host "Test 2: AWS Credentials" -ForegroundColor Yellow
try {
    $identityJson = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -eq 0) {
        $identity = $identityJson | ConvertFrom-Json
        Write-Host "  ✓ AWS credentials valid" -ForegroundColor Green
        Write-Host "    Account ID: $($identity.Account)" -ForegroundColor Gray
        Write-Host "    User ARN: $($identity.Arn)" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ AWS credentials invalid or not configured" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "  ✗ AWS credentials invalid or not configured" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 3: Terraform Installation
Write-Host "Test 3: Terraform Installation" -ForegroundColor Yellow
try {
    $tfVersion = terraform --version 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Terraform installed: $tfVersion" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Terraform not found" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "  ✗ Terraform not found" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 4: Terraform Configuration Validation
Write-Host "Test 4: Terraform Configuration Validation" -ForegroundColor Yellow
try {
    Push-Location terraform
    terraform init -upgrade -reconfigure | Out-Null
    $validateResult = terraform validate 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Terraform configuration is valid" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Terraform configuration has errors" -ForegroundColor Red
        Write-Host $validateResult -ForegroundColor Red
        $allTestsPassed = $false
    }
    Pop-Location
} catch {
    Write-Host "  ✗ Terraform validation failed: $_" -ForegroundColor Red
    $allTestsPassed = $false
    Pop-Location
}
Write-Host ""

# Test 5: IP Detection (HTTP Data Source)
Write-Host "Test 5: IP Detection" -ForegroundColor Yellow
try {
    $ipResponse = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -ErrorAction Stop
    Write-Host "  ✓ Public IP detected: $($ipResponse.ip)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to detect public IP: $_" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 6: AWS Region Access
Write-Host "Test 6: AWS Region Access (us-east-1)" -ForegroundColor Yellow
try {
    $regions = aws ec2 describe-regions --region-names us-east-1 --query 'Regions[0].RegionName' --output text 2>&1
    if ($LASTEXITCODE -eq 0 -and $regions -eq "us-east-1") {
        Write-Host "  ✓ Region us-east-1 is accessible" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Region access issue" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "  ✗ Failed to access region: $_" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 7: EC2 Key Pair Verification
Write-Host "Test 7: EC2 Key Pair Verification" -ForegroundColor Yellow
try {
    $keyPairs = aws ec2 describe-key-pairs --region us-east-1 --query 'KeyPairs[*].KeyName' --output text 2>&1
    $keyPairName = "fastapi-app-key"
    if ($LASTEXITCODE -eq 0 -and $keyPairs -match $keyPairName) {
        Write-Host "  ✓ Key pair '$keyPairName' exists" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Key pair '$keyPairName' not found" -ForegroundColor Yellow
        Write-Host "    Available key pairs: $keyPairs" -ForegroundColor Gray
        Write-Host "    Please update terraform.tfvars with correct key_pair_name" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ Failed to check key pairs: $_" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 8: AMI Availability
Write-Host "Test 8: Amazon Linux 2 AMI Availability" -ForegroundColor Yellow
try {
    $ami = aws ec2 describe-images --region us-east-1 --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text 2>&1
    if ($LASTEXITCODE -eq 0 -and $ami -match "ami-") {
        Write-Host "  ✓ Latest Amazon Linux 2 AMI found: $ami" -ForegroundColor Green
    } else {
        Write-Host "  ✗ AMI not found" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "  ✗ Failed to find AMI: $_" -ForegroundColor Red
    $allTestsPassed = $false
}
Write-Host ""

# Test 9: Terraform Plan (Dry Run)
Write-Host "Test 9: Terraform Plan (Dry Run)" -ForegroundColor Yellow
try {
    Push-Location terraform
    $planOutput = terraform plan -out=test-plan.tfplan 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Terraform plan successful" -ForegroundColor Green
        Write-Host "    Plan file saved to: test-plan.tfplan" -ForegroundColor Gray
        if (Test-Path "test-plan.tfplan") {
            Remove-Item "test-plan.tfplan" -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  ✗ Terraform plan failed" -ForegroundColor Red
        Write-Host $planOutput -ForegroundColor Red
        $allTestsPassed = $false
    }
    Pop-Location
} catch {
    Write-Host "  ✗ Terraform plan error: $_" -ForegroundColor Red
    $allTestsPassed = $false
    Pop-Location
}
Write-Host ""

# Test 10: Security Group Check
Write-Host "Test 10: Existing Security Groups" -ForegroundColor Yellow
try {
    $sgName = "fastapi-app-sg"
    $sgs = aws ec2 describe-security-groups --region us-east-1 --filters "Name=group-name,Values=$sgName" --query 'SecurityGroups[*].GroupId' --output text 2>&1
    if ($LASTEXITCODE -eq 0 -and $sgs) {
        Write-Host "  ⚠ Security group '$sgName' already exists: $sgs" -ForegroundColor Yellow
        Write-Host "    Terraform will update or recreate it" -ForegroundColor Gray
    } else {
        Write-Host "  ✓ No existing security group found (will be created)" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠ Could not check security groups: $_" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "==========================================" -ForegroundColor Cyan
if ($allTestsPassed) {
    Write-Host "All Critical Tests PASSED! ✓" -ForegroundColor Green
    Write-Host ""
    Write-Host "You are ready to deploy:" -ForegroundColor Cyan
    Write-Host "  cd terraform" -ForegroundColor White
    Write-Host "  terraform apply" -ForegroundColor White
} else {
    Write-Host "Some Tests FAILED ✗" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the issues above before deploying." -ForegroundColor Yellow
}
Write-Host "==========================================" -ForegroundColor Cyan

# PowerShell teardown script to destroy Terraform resources
# Usage: .\teardown.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Terraform Teardown" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will destroy:" -ForegroundColor Yellow
Write-Host "  - EC2 instance" -ForegroundColor Yellow
Write-Host "  - Security group" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Are you sure you want to proceed? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "Teardown cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Running terraform destroy..." -ForegroundColor Yellow
terraform destroy

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teardown completed successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan



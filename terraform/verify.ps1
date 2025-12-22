# PowerShell verification script for FastAPI application on EC2
# Usage: .\verify.ps1 -EC2IP <EC2_PUBLIC_IP> -APIKey <API_KEY>

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2IP,
    
    [Parameter(Mandatory=$true)]
    [string]$APIKey
)

$BaseURL = "http://${EC2IP}:5000"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Verifying FastAPI Application" -ForegroundColor Cyan
Write-Host "Base URL: $BaseURL" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Wait for service to become available
Write-Host "Waiting for service to become available (this may take 2-3 minutes)..." -ForegroundColor Yellow
$RetryCount = 0
$MaxRetries = 40 # 40 * 5 seconds = ~3.5 minutes
$ServiceUp = $false

while (-not $ServiceUp -and $RetryCount -lt $MaxRetries) {
    try {
        $null = Invoke-RestMethod -Uri "${BaseURL}/status" -Method Get -ErrorAction Stop
        $ServiceUp = $true
        Write-Host "`n✓ Service is UP!" -ForegroundColor Green
    } catch {
        Write-Host "." -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
        $RetryCount++
    }
}

if (-not $ServiceUp) {
    Write-Host "`n✗ Service failed to start within timeout. Check EC2 logs." -ForegroundColor Red
    exit 1
}

# Test 1: GET /status - Initial state
Write-Host "Test 1: GET /status (Initial State)" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow
try {
    $StatusResponse = Invoke-RestMethod -Uri "${BaseURL}/status" -Method Get
    $StatusResponse | ConvertTo-Json -Depth 10
    $InitialCounter = $StatusResponse.counter
    $InitialMessage = $StatusResponse.message
    Write-Host ""
    Write-Host "✓ Initial counter: $InitialCounter" -ForegroundColor Green
    Write-Host "✓ Initial message: '$InitialMessage'" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "✗ Failed to get initial status: $_" -ForegroundColor Red
    exit 1
}

# Test 2: POST /update - Update state
Write-Host "Test 2: POST /update (Update State)" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow
try {
    $UpdateBody = @{
        counter = 42
        message = "Hello from Terraform deployment!"
    } | ConvertTo-Json

    $Headers = @{
        "X-API-Key" = $APIKey
        "Content-Type" = "application/json"
    }

    $UpdateResponse = Invoke-RestMethod -Uri "${BaseURL}/update" -Method Post -Body $UpdateBody -Headers $Headers
    $UpdateResponse | ConvertTo-Json -Depth 10
    Write-Host ""
    Write-Host "✓ State updated successfully" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "✗ Failed to update state: $_" -ForegroundColor Red
    exit 1
}

# Wait a moment for the update to be processed
Start-Sleep -Seconds 2

# Test 3: GET /status - Verify updated state
Write-Host "Test 3: GET /status (Updated State)" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow
try {
    $UpdatedStatusResponse = Invoke-RestMethod -Uri "${BaseURL}/status" -Method Get
    $UpdatedStatusResponse | ConvertTo-Json -Depth 10
    $UpdatedCounter = $UpdatedStatusResponse.counter
    $UpdatedMessage = $UpdatedStatusResponse.message
    Write-Host ""
    
    if ($UpdatedCounter -eq 42 -and $UpdatedMessage -eq "Hello from Terraform deployment!") {
        Write-Host "✓ Counter updated: $InitialCounter -> $UpdatedCounter" -ForegroundColor Green
        Write-Host "✓ Message updated: '$InitialMessage' -> '$UpdatedMessage'" -ForegroundColor Green
        Write-Host "✓ State verification PASSED" -ForegroundColor Green
    } else {
        Write-Host "✗ State verification FAILED" -ForegroundColor Red
        Write-Host "  Expected: counter=42, message='Hello from Terraform deployment!'" -ForegroundColor Red
        Write-Host "  Got: counter=$UpdatedCounter, message='$UpdatedMessage'" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
} catch {
    Write-Host "✗ Failed to get updated status: $_" -ForegroundColor Red
    exit 1
}

# Test 4: GET /logs - Verify logging
Write-Host "Test 4: GET /logs (Verify Logging)" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow
try {
    $LogsResponse = Invoke-RestMethod -Uri "${BaseURL}/logs?page=1&limit=10" -Method Get
    $LogsResponse | ConvertTo-Json -Depth 10
    $LogCount = $LogsResponse.logs.Count
    Write-Host ""
    
    if ($LogCount -gt 0) {
        Write-Host "✓ Found $LogCount log entry/entries" -ForegroundColor Green
        Write-Host "✓ Logging verification PASSED" -ForegroundColor Green
    } else {
        Write-Host "✗ No logs found - logging verification FAILED" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
} catch {
    Write-Host "✗ Failed to get logs: $_" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "All verification tests PASSED! ✓" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan



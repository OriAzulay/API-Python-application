#!/bin/bash
# Verification script for FastAPI application on EC2
# Usage: ./verify.sh <EC2_PUBLIC_IP> <API_KEY>

set -e

EC2_IP=$1
API_KEY=$2

if [ -z "$EC2_IP" ] || [ -z "$API_KEY" ]; then
    echo "Usage: ./verify.sh <EC2_PUBLIC_IP> <API_KEY>"
    echo "Example: ./verify.sh 54.123.45.67 your-secret-api-key-12345"
    exit 1
fi

BASE_URL="http://${EC2_IP}:5000"
echo "=========================================="
echo "Verifying FastAPI Application"
echo "Base URL: ${BASE_URL}"
echo "=========================================="
echo ""

# Test 1: GET /status - Initial state
echo "Test 1: GET /status (Initial State)"
echo "-----------------------------------"
STATUS_RESPONSE=$(curl -s "${BASE_URL}/status")
echo "$STATUS_RESPONSE" | python3 -m json.tool
INITIAL_COUNTER=$(echo "$STATUS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['counter'])")
INITIAL_MESSAGE=$(echo "$STATUS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['message'])")
echo ""
echo "✓ Initial counter: $INITIAL_COUNTER"
echo "✓ Initial message: '$INITIAL_MESSAGE'"
echo ""

# Test 2: POST /update - Update state
echo "Test 2: POST /update (Update State)"
echo "-----------------------------------"
UPDATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/update" \
    -H "X-API-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"counter": 42, "message": "Hello from Terraform deployment!"}')
echo "$UPDATE_RESPONSE" | python3 -m json.tool
echo ""
echo "✓ State updated successfully"
echo ""

# Wait a moment for the update to be processed
sleep 2

# Test 3: GET /status - Verify updated state
echo "Test 3: GET /status (Updated State)"
echo "-----------------------------------"
UPDATED_STATUS_RESPONSE=$(curl -s "${BASE_URL}/status")
echo "$UPDATED_STATUS_RESPONSE" | python3 -m json.tool
UPDATED_COUNTER=$(echo "$UPDATED_STATUS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['counter'])")
UPDATED_MESSAGE=$(echo "$UPDATED_STATUS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['message'])")
echo ""
if [ "$UPDATED_COUNTER" = "42" ] && [ "$UPDATED_MESSAGE" = "Hello from Terraform deployment!" ]; then
    echo "✓ Counter updated: $INITIAL_COUNTER -> $UPDATED_COUNTER"
    echo "✓ Message updated: '$INITIAL_MESSAGE' -> '$UPDATED_MESSAGE'"
    echo "✓ State verification PASSED"
else
    echo "✗ State verification FAILED"
    exit 1
fi
echo ""

# Test 4: GET /logs - Verify logging
echo "Test 4: GET /logs (Verify Logging)"
echo "-----------------------------------"
LOGS_RESPONSE=$(curl -s "${BASE_URL}/logs?page=1&limit=10")
echo "$LOGS_RESPONSE" | python3 -m json.tool
LOG_COUNT=$(echo "$LOGS_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['logs']))")
echo ""
if [ "$LOG_COUNT" -gt 0 ]; then
    echo "✓ Found $LOG_COUNT log entry/entries"
    echo "✓ Logging verification PASSED"
else
    echo "✗ No logs found - logging verification FAILED"
    exit 1
fi
echo ""

echo "=========================================="
echo "All verification tests PASSED! ✓"
echo "=========================================="



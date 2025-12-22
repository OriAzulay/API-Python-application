#!/bin/bash
# Teardown script to destroy Terraform resources
# Usage: ./teardown.sh

set -e

echo "=========================================="
echo "Terraform Teardown"
echo "=========================================="
echo ""
echo "This will destroy:"
echo "  - EC2 instance"
echo "  - Security group"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Running terraform destroy..."
terraform destroy

echo ""
echo "=========================================="
echo "Teardown completed successfully!"
echo "=========================================="




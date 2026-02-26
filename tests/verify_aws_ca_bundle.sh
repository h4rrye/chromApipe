#!/bin/bash
# Verification script to check AWS_CA_BUNDLE in AWS Batch container
#
# This script is designed to be run INSIDE an AWS Batch container
# to verify the environment variable configuration.
#
# Usage: Run this as a Nextflow process or manually exec into a running container

echo "=========================================="
echo "AWS_CA_BUNDLE Environment Check"
echo "=========================================="
echo ""

# Check if AWS_CA_BUNDLE is set
if [ -z "${AWS_CA_BUNDLE}" ]; then
    echo "❌ AWS_CA_BUNDLE is NOT set"
    echo "   This is the BUG CONDITION - environment variable missing"
    echo ""
    echo "COUNTEREXAMPLE: AWS_CA_BUNDLE not present in container environment"
    exit 1
else
    echo "✅ AWS_CA_BUNDLE is set to: ${AWS_CA_BUNDLE}"
    echo ""
    
    # Check if the file exists
    if [ -f "${AWS_CA_BUNDLE}" ]; then
        echo "✅ CA bundle file exists at: ${AWS_CA_BUNDLE}"
        echo "   File size: $(stat -c%s "${AWS_CA_BUNDLE}" 2>/dev/null || stat -f%z "${AWS_CA_BUNDLE}" 2>/dev/null) bytes"
    else
        echo "❌ CA bundle file does NOT exist at: ${AWS_CA_BUNDLE}"
        echo "   This will cause SSL validation failures"
        exit 1
    fi
fi

echo ""
echo "Checking for CA certificate files in container..."

# Check common CA bundle locations
LOCATIONS=(
    "/etc/ssl/certs/ca-certificates.crt"
    "/etc/pki/tls/certs/ca-bundle.crt"
    "/etc/ssl/ca-bundle.pem"
)

for loc in "${LOCATIONS[@]}"; do
    if [ -f "${loc}" ]; then
        echo "  ✅ Found: ${loc}"
    else
        echo "  ❌ Not found: ${loc}"
    fi
done

echo ""
echo "Testing AWS CLI with current configuration..."

# Test AWS CLI S3 access
if command -v aws &> /dev/null; then
    echo "AWS CLI is installed"
    
    # Try a simple S3 operation
    if aws s3 ls s3://chromapipe-data/ --region us-west-2 2>&1 | grep -q "SSL"; then
        echo "❌ SSL error detected when accessing S3"
        echo "   This confirms the bug condition"
        exit 1
    else
        echo "✅ AWS CLI can access S3 without SSL errors"
    fi
else
    echo "⚠️  AWS CLI not found in container"
fi

echo ""
echo "Environment check complete"
exit 0

#!/bin/bash
# Bug Condition Exploration Test for AWS Batch SSL Validation
# 
# **Validates: Requirements 2.1, 2.2, 2.3**
#
# This test verifies the bug condition exists on UNFIXED code.
# EXPECTED OUTCOME: This test MUST FAIL on unfixed code with SSL validation errors.
# 
# The bug manifests when:
# - Nextflow runs with -profile aws on AWS Batch
# - S3 staging operations are attempted (upload/download of .command.run, .command.log, nextflow-bin)
# - AWS_CA_BUNDLE is not properly set in the container environment
# - SSL validation fails with "No such file or directory" error
#
# This test encodes the EXPECTED BEHAVIOR (which will fail on unfixed code):
# - S3 staging operations should succeed
# - No SSL validation errors should occur
# - AWS_CA_BUNDLE should be properly set in container

set -e

echo "=========================================="
echo "Bug Condition Exploration Test"
echo "Testing AWS Batch S3 Staging SSL Validation"
echo "=========================================="
echo ""

# Test configuration
TEST_CHROMOSOMES="21"  # Use single chromosome for faster test
TEST_PROFILE="aws"
EXPECTED_ERROR_PATTERN="SSL validation failed.*No such file or directory"

echo "Test Setup:"
echo "  Profile: ${TEST_PROFILE}"
echo "  Chromosomes: ${TEST_CHROMOSOMES}"
echo "  Expected to FAIL on unfixed code with SSL errors"
echo ""

# Run the pipeline with AWS profile
echo "Running Nextflow pipeline with -profile aws..."
echo "Command: nextflow run main.nf -profile ${TEST_PROFILE} --chromosomes ${TEST_CHROMOSOMES}"
echo ""

# Capture output and exit code
set +e
OUTPUT=$(nextflow run main.nf -profile ${TEST_PROFILE} --chromosomes ${TEST_CHROMOSOMES} 2>&1)
EXIT_CODE=$?
set -e

echo "Pipeline execution completed with exit code: ${EXIT_CODE}"
echo ""

# Check for SSL validation errors (expected on unfixed code)
if echo "${OUTPUT}" | grep -q "SSL validation failed"; then
    echo "❌ FOUND SSL VALIDATION ERROR (Expected on unfixed code)"
    echo ""
    echo "Error details:"
    echo "${OUTPUT}" | grep -A 5 "SSL validation failed" || true
    echo ""
    echo "COUNTEREXAMPLE DOCUMENTED:"
    echo "  - S3 staging operations fail with SSL validation error"
    echo "  - Error: 'SSL validation failed... [Errno 2] No such file or directory'"
    echo "  - Root cause: AWS_CA_BUNDLE not properly set in container"
    echo ""
    echo "This confirms the bug condition exists."
    echo "Test result: FAILED (as expected on unfixed code)"
    exit 1
fi

# Check if pipeline succeeded (unexpected on unfixed code)
if [ ${EXIT_CODE} -eq 0 ]; then
    echo "✅ PIPELINE SUCCEEDED"
    echo ""
    echo "Verifying S3 staging operations completed successfully..."
    
    # Check Nextflow logs for successful S3 operations
    if [ -f ".nextflow.log" ]; then
        echo ""
        echo "Checking for S3 staging operations in logs..."
        
        # Look for successful S3 uploads/downloads
        S3_OPS=$(grep -i "s3://" .nextflow.log | grep -v "ERROR" | wc -l || echo "0")
        echo "  Found ${S3_OPS} successful S3 operations"
        
        # Check for AWS_CA_BUNDLE in logs
        if grep -q "AWS_CA_BUNDLE" .nextflow.log; then
            echo "  ✅ AWS_CA_BUNDLE referenced in logs"
        else
            echo "  ⚠️  AWS_CA_BUNDLE not found in logs"
        fi
    fi
    
    echo ""
    echo "Test result: PASSED"
    echo "This indicates the bug is FIXED or does not exist."
    exit 0
else
    echo "❌ PIPELINE FAILED"
    echo ""
    echo "Exit code: ${EXIT_CODE}"
    echo ""
    echo "Checking error type..."
    
    # Check for other errors
    if echo "${OUTPUT}" | grep -q "No such file or directory"; then
        echo "  Found 'No such file or directory' error"
    fi
    
    if echo "${OUTPUT}" | grep -q "AWS_CA_BUNDLE"; then
        echo "  AWS_CA_BUNDLE mentioned in error output"
    fi
    
    echo ""
    echo "Full error output:"
    echo "${OUTPUT}"
    echo ""
    echo "Test result: FAILED"
    exit 1
fi

#!/bin/bash
# Test Runner for AWS Batch SSL Bug Condition Exploration
#
# This script runs all bug condition exploration tests and provides a summary.
# 
# IMPORTANT: On UNFIXED code, tests are EXPECTED TO FAIL
# Test failures confirm the bug condition exists and document counterexamples.

set +e  # Don't exit on errors - we expect failures on unfixed code

echo "=========================================="
echo "AWS Batch SSL Bug Condition Test Suite"
echo "=========================================="
echo ""
echo "IMPORTANT: These tests are designed to FAIL on unfixed code."
echo "Test failures confirm the bug exists and document counterexamples."
echo ""

# Track test results
TOTAL_TESTS=0
FAILED_TESTS=0
PASSED_TESTS=0

# Test 1: Main integration test
echo "=========================================="
echo "Test 1: Bug Condition Exploration"
echo "=========================================="
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ -f "bug_condition_exploration.sh" ]; then
    chmod +x bug_condition_exploration.sh
    ./bug_condition_exploration.sh
    if [ $? -eq 0 ]; then
        echo "Result: PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "Result: FAILED (Expected on unfixed code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo "ERROR: bug_condition_exploration.sh not found"
fi

echo ""
echo ""

# Test 2: Nextflow test workflow
echo "=========================================="
echo "Test 2: Nextflow Test Workflow"
echo "=========================================="
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ -f "test_aws_batch_ssl.nf" ]; then
    echo "Running: nextflow run test_aws_batch_ssl.nf -profile aws"
    nextflow run test_aws_batch_ssl.nf -profile aws
    if [ $? -eq 0 ]; then
        echo "Result: PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "Result: FAILED (Expected on unfixed code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo "ERROR: test_aws_batch_ssl.nf not found"
fi

echo ""
echo ""

# Test 3: Environment verification (requires manual container access)
echo "=========================================="
echo "Test 3: Container Environment Verification"
echo "=========================================="
echo "NOTE: This test requires manual execution inside an AWS Batch container"
echo "      Run: docker exec -it <container-id> ./tests/verify_aws_ca_bundle.sh"
echo "      Skipping automated execution"
echo ""

# Summary
echo "=========================================="
echo "Test Suite Summary"
echo "=========================================="
echo ""
echo "Total Tests: ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: ${FAILED_TESTS}"
echo ""

if [ ${FAILED_TESTS} -gt 0 ]; then
    echo "Status: TESTS FAILED (Expected on unfixed code)"
    echo ""
    echo "Counterexamples documented:"
    echo "  - AWS_CA_BUNDLE environment variable not set in containers"
    echo "  - S3 staging operations fail with SSL validation errors"
    echo "  - Invalid Nextflow syntax ignored: process.env.AWS_CA_BUNDLE"
    echo "  - CA bundle path mismatch: Red Hat path used on Debian container"
    echo ""
    echo "These failures confirm the bug condition exists."
    echo "Proceed to implement the fix in nextflow.config"
    echo ""
    echo "See COUNTEREXAMPLES.md for detailed analysis"
    exit 1
else
    echo "Status: ALL TESTS PASSED"
    echo ""
    echo "This indicates the bug is FIXED or does not exist."
    echo "Verify that:"
    echo "  - AWS_CA_BUNDLE is set to /etc/ssl/certs/ca-certificates.crt"
    echo "  - S3 staging operations complete successfully"
    echo "  - No SSL validation errors occur"
    echo ""
    exit 0
fi

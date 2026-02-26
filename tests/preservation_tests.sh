#!/bin/bash
# Preservation Property Tests for Standard Profile
# 
# **Validates: Requirements 3.1, 3.2, 3.3**
#
# This test verifies that local Docker execution behavior is preserved.
# EXPECTED OUTCOME: These tests MUST PASS on unfixed code to establish baseline.
# After the fix, these tests should still PASS to confirm no regressions.
#
# Property 2: Preservation - Local Docker Execution
# For any Nextflow execution that does NOT use the aws profile,
# the configuration SHALL produce identical behavior before and after the fix.

set -e

echo "=========================================="
echo "Preservation Property Tests"
echo "Testing Standard Profile Behavior"
echo "=========================================="
echo ""

# Test configuration
TEST_PROFILE="standard"

echo "Test Setup:"
echo "  Profile: ${TEST_PROFILE}"
echo "  Expected: Tests PASS on unfixed code (baseline behavior)"
echo "  Goal: Verify local Docker execution works correctly"
echo ""

# Run the preservation test workflow
echo "Running preservation tests with -profile ${TEST_PROFILE}..."
echo "Command: nextflow run test_preservation_standard_profile.nf -profile ${TEST_PROFILE}"
echo ""

# Capture output and exit code
set +e
OUTPUT=$(nextflow run test_preservation_standard_profile.nf -profile ${TEST_PROFILE} 2>&1)
EXIT_CODE=$?
set -e

echo "Test execution completed with exit code: ${EXIT_CODE}"
echo ""

# Check if tests passed
if [ ${EXIT_CODE} -eq 0 ]; then
    echo "✅ ALL PRESERVATION TESTS PASSED"
    echo ""
    echo "Verified behaviors:"
    echo "  ✅ AWS_CA_BUNDLE is NOT set in standard profile containers"
    echo "  ✅ Container options are appropriate for local Docker"
    echo "  ✅ Python execution environment is functional"
    echo "  ✅ Resource allocations are correct"
    echo "  ✅ File access and permissions work correctly"
    echo ""
    echo "Baseline behavior documented successfully."
    echo "These same tests should pass after implementing the fix."
    echo ""
    
    # Display test output files if available
    if ls work/*/aws_ca_bundle_check.txt 1> /dev/null 2>&1; then
        echo "=== AWS_CA_BUNDLE Check Results ==="
        cat work/*/aws_ca_bundle_check.txt | head -20
        echo ""
    fi
    
    if ls work/*/container_options_check.txt 1> /dev/null 2>&1; then
        echo "=== Container Options Check Results ==="
        cat work/*/container_options_check.txt | head -20
        echo ""
    fi
    
    echo "Test result: PASSED"
    echo "Preservation baseline established."
    exit 0
else
    echo "❌ PRESERVATION TESTS FAILED"
    echo ""
    echo "Exit code: ${EXIT_CODE}"
    echo ""
    echo "This is unexpected - standard profile should work on unfixed code."
    echo "Investigating failure..."
    echo ""
    
    # Check for specific errors
    if echo "${OUTPUT}" | grep -q "AWS_CA_BUNDLE"; then
        echo "  ⚠️  AWS_CA_BUNDLE unexpectedly present in standard profile"
        echo "  This would be a regression if it appears after the fix"
    fi
    
    if echo "${OUTPUT}" | grep -q "Docker"; then
        echo "  ⚠️  Docker-related error detected"
    fi
    
    echo ""
    echo "Error output:"
    echo "${OUTPUT}" | tail -50
    echo ""
    echo "Test result: FAILED"
    exit 1
fi

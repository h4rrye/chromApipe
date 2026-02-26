#!/usr/bin/env nextflow

// Bug Condition Exploration Test - AWS Batch SSL Validation
// 
// **Validates: Requirements 2.1, 2.2, 2.3**
//
// This test workflow verifies the bug condition by:
// 1. Running a simple process on AWS Batch that checks AWS_CA_BUNDLE
// 2. Attempting S3 operations to trigger SSL validation
// 3. Documenting counterexamples when the bug exists
//
// EXPECTED OUTCOME on unfixed code:
// - AWS_CA_BUNDLE will NOT be set in container
// - S3 operations will fail with SSL validation errors
// - Test will FAIL, confirming the bug exists
//
// EXPECTED OUTCOME on fixed code:
// - AWS_CA_BUNDLE will be set to /etc/ssl/certs/ca-certificates.crt
// - S3 operations will succeed
// - Test will PASS, confirming the fix works

params.test_bucket = "s3://chromapipe-data"
params.test_region = "us-west-2"

process check_aws_ca_bundle {
    // This process will run on AWS Batch when using -profile aws
    
    output:
    path "env_check.txt"
    
    script:
    """
    echo "=== AWS_CA_BUNDLE Environment Check ===" > env_check.txt
    echo "" >> env_check.txt
    
    # Check if AWS_CA_BUNDLE is set
    if [ -z "\${AWS_CA_BUNDLE}" ]; then
        echo "FAIL: AWS_CA_BUNDLE is NOT set" >> env_check.txt
        echo "COUNTEREXAMPLE: Environment variable missing in container" >> env_check.txt
        echo "" >> env_check.txt
        echo "This is the BUG CONDITION" >> env_check.txt
        exit 1
    else
        echo "PASS: AWS_CA_BUNDLE is set to: \${AWS_CA_BUNDLE}" >> env_check.txt
        echo "" >> env_check.txt
        
        # Check if the file exists
        if [ -f "\${AWS_CA_BUNDLE}" ]; then
            echo "PASS: CA bundle file exists at \${AWS_CA_BUNDLE}" >> env_check.txt
        else
            echo "FAIL: CA bundle file does NOT exist at \${AWS_CA_BUNDLE}" >> env_check.txt
            exit 1
        fi
    fi
    
    # List all environment variables for debugging
    echo "" >> env_check.txt
    echo "=== All Environment Variables ===" >> env_check.txt
    env | sort >> env_check.txt
    """
}

process test_s3_access {
    // This process tests actual S3 access to trigger SSL validation
    
    input:
    path env_check
    
    output:
    path "s3_test.txt"
    
    script:
    """
    echo "=== S3 Access Test ===" > s3_test.txt
    echo "" >> s3_test.txt
    
    # Test S3 listing
    echo "Testing S3 access to ${params.test_bucket}..." >> s3_test.txt
    
    if aws s3 ls ${params.test_bucket}/ --region ${params.test_region} 2>&1 | tee -a s3_test.txt | grep -q "SSL"; then
        echo "" >> s3_test.txt
        echo "FAIL: SSL validation error detected" >> s3_test.txt
        echo "COUNTEREXAMPLE: S3 operations fail with SSL errors" >> s3_test.txt
        echo "This confirms the bug condition exists" >> s3_test.txt
        exit 1
    else
        echo "" >> s3_test.txt
        echo "PASS: S3 access successful without SSL errors" >> s3_test.txt
    fi
    
    # Copy the env check results
    cat ${env_check} >> s3_test.txt
    """
}

process verify_ca_certificates {
    // Verify CA certificates are installed in the container
    
    output:
    path "ca_check.txt"
    
    script:
    """
    echo "=== CA Certificates Check ===" > ca_check.txt
    echo "" >> ca_check.txt
    
    # Check for CA certificate files
    echo "Checking common CA bundle locations:" >> ca_check.txt
    
    if [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
        echo "  FOUND: /etc/ssl/certs/ca-certificates.crt (Debian/Ubuntu)" >> ca_check.txt
    else
        echo "  NOT FOUND: /etc/ssl/certs/ca-certificates.crt" >> ca_check.txt
    fi
    
    if [ -f "/etc/pki/tls/certs/ca-bundle.crt" ]; then
        echo "  FOUND: /etc/pki/tls/certs/ca-bundle.crt (Red Hat/CentOS)" >> ca_check.txt
    else
        echo "  NOT FOUND: /etc/pki/tls/certs/ca-bundle.crt" >> ca_check.txt
    fi
    
    echo "" >> ca_check.txt
    echo "Container OS information:" >> ca_check.txt
    cat /etc/os-release >> ca_check.txt || echo "Could not read /etc/os-release" >> ca_check.txt
    """
}

workflow {
    // Run all verification checks
    env_check = check_aws_ca_bundle()
    s3_test = test_s3_access(env_check)
    ca_check = verify_ca_certificates()
    
    // Combine results
    s3_test.view { "S3 Test Result: ${it}" }
    ca_check.view { "CA Check Result: ${it}" }
}

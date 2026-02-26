# Bug Condition Exploration Tests

## Overview

This directory contains tests for the AWS Batch SSL validation bug fix. These tests follow the bug condition exploration methodology:

1. **Write tests that encode expected behavior** (tests will FAIL on unfixed code)
2. **Run tests on unfixed code** to surface counterexamples
3. **Document the bug condition** based on test failures
4. **Implement the fix**
5. **Re-run tests** to verify they now pass

## Test Files

### 1. `bug_condition_exploration.sh`

**Purpose**: Main integration test that runs the full Nextflow pipeline with `-profile aws` on AWS Batch.

**What it tests**:
- Nextflow execution with AWS Batch profile
- S3 staging operations (upload/download of .command.run, .command.log, nextflow-bin)
- SSL validation during S3 access
- Pipeline completion status

**Expected outcome on UNFIXED code**:
- ❌ Test FAILS with SSL validation error
- Error message: "SSL validation failed for https://chromapipe-data.s3.us-west-2.amazonaws.com/... [Errno 2] No such file or directory"
- Counterexample documented: S3 staging fails due to missing AWS_CA_BUNDLE

**Expected outcome on FIXED code**:
- ✅ Test PASSES
- S3 staging operations complete successfully
- No SSL validation errors

**Usage**:
```bash
cd tests
chmod +x bug_condition_exploration.sh
./bug_condition_exploration.sh
```

**Requirements**:
- AWS credentials configured
- Access to AWS Batch queue: chromapipe-queue-v2
- Access to S3 bucket: chromapipe-data
- Nextflow installed

### 2. `test_aws_batch_ssl.nf`

**Purpose**: Nextflow test workflow that systematically checks AWS_CA_BUNDLE configuration and S3 access.

**What it tests**:
- AWS_CA_BUNDLE environment variable presence in container
- CA bundle file existence at specified path
- S3 access with SSL validation
- CA certificate installation in container

**Expected outcome on UNFIXED code**:
- ❌ `check_aws_ca_bundle` process FAILS
- Counterexample: AWS_CA_BUNDLE not set in container environment
- S3 operations fail with SSL errors

**Expected outcome on FIXED code**:
- ✅ All processes PASS
- AWS_CA_BUNDLE set to `/etc/ssl/certs/ca-certificates.crt`
- S3 operations succeed without SSL errors

**Usage**:
```bash
# Run with AWS profile (will fail on unfixed code)
nextflow run tests/test_aws_batch_ssl.nf -profile aws

# Check output files
cat work/*/env_check.txt
cat work/*/s3_test.txt
cat work/*/ca_check.txt
```

### 3. `verify_aws_ca_bundle.sh`

**Purpose**: Standalone script to verify AWS_CA_BUNDLE configuration inside a container.

**What it tests**:
- AWS_CA_BUNDLE environment variable
- CA bundle file existence
- Available CA certificate locations
- AWS CLI S3 access

**Usage**:
```bash
# Option 1: Run inside a running AWS Batch container
aws batch describe-jobs --jobs <job-id> --region us-west-2
# Get container ID, then:
docker exec -it <container-id> bash
./tests/verify_aws_ca_bundle.sh

# Option 2: Add as a Nextflow process for automated checking
```

## Test Execution Strategy

### Phase 1: Bug Condition Exploration (BEFORE fix)

**Goal**: Surface counterexamples that prove the bug exists

1. Run `bug_condition_exploration.sh` on AWS Batch with UNFIXED code
2. Run `test_aws_batch_ssl.nf` with `-profile aws` on UNFIXED code
3. Document all counterexamples found:
   - AWS_CA_BUNDLE not set in container
   - S3 staging operations fail with SSL errors
   - Invalid `process.env.AWS_CA_BUNDLE` syntax ignored by Nextflow

**Expected Results**:
- All tests FAIL (this is correct - confirms bug exists)
- SSL validation errors documented
- Environment variable absence confirmed

### Phase 2: Fix Verification (AFTER fix)

**Goal**: Verify the fix resolves the bug condition

1. Implement fix in `nextflow.config`:
   - Remove: `process.env.AWS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'`
   - Add: `process.containerOptions = '-e AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt'`

2. Re-run `bug_condition_exploration.sh` on AWS Batch with FIXED code
3. Re-run `test_aws_batch_ssl.nf` with `-profile aws` on FIXED code

**Expected Results**:
- All tests PASS (confirms fix works)
- AWS_CA_BUNDLE properly set in container
- S3 operations succeed without SSL errors

## Counterexamples Documented

Based on test failures on unfixed code, the following counterexamples confirm the bug:

1. **Environment Variable Not Set**:
   - `echo $AWS_CA_BUNDLE` in container returns empty
   - Nextflow warning: "Unrecognized config option 'process.env.AWS_CA_BUNDLE'"
   - Root cause: Invalid syntax not recognized by Nextflow

2. **S3 Staging Failures**:
   - Error: "SSL validation failed for https://chromapipe-data.s3.us-west-2.amazonaws.com/work/..."
   - Error: "[Errno 2] No such file or directory"
   - AWS CLI cannot find CA bundle to validate SSL certificates

3. **Path Mismatch**:
   - Configured path: `/etc/pki/tls/certs/ca-bundle.crt` (Red Hat)
   - Container OS: Debian (python:3.11-slim)
   - Actual CA bundle location: `/etc/ssl/certs/ca-certificates.crt`

## Requirements Validated

These tests validate the following requirements from the bugfix specification:

- **Requirement 2.1**: AWS Batch execution with `-profile aws` completes successfully
- **Requirement 2.2**: S3 staging operations (upload/download) succeed without SSL errors
- **Requirement 2.3**: AWS_CA_BUNDLE environment variable is properly set in AWS Batch containers

## Notes

- These tests require actual AWS Batch execution and cannot be fully mocked
- Tests may take several minutes to run due to AWS Batch job scheduling
- Ensure AWS credentials and permissions are properly configured
- The tests are designed to FAIL on unfixed code - this is expected and correct behavior

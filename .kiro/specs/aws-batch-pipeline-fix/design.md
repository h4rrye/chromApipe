# AWS Batch Pipeline SSL Fix Design

## Overview

This bugfix addresses SSL validation failures that occur when Nextflow runs on AWS Batch. The pipeline fails during Nextflow's internal S3 staging operations (uploading/downloading .command.run, .command.log, and nextflow-bin) with the error "SSL validation failed for https://chromapipe-data.s3.us-west-2.amazonaws.com/... [Errno 2] No such file or directory". The root cause is incorrect AWS_CA_BUNDLE configuration syntax in nextflow.config that prevents the AWS CLI from locating the system CA certificate bundle. The fix involves correcting the environment variable syntax and ensuring the CA bundle path is valid in the container.

## Glossary

- **Bug_Condition (C)**: The condition that triggers SSL validation failures - when Nextflow runs with the aws profile and attempts S3 staging operations
- **Property (P)**: The desired behavior - Nextflow successfully completes all S3 staging operations using valid SSL certificate verification
- **Preservation**: Local Docker execution (standard profile) and all Python script functionality must remain unchanged
- **S3 Staging**: Nextflow's internal process of uploading/downloading task scripts, logs, and bin folder to/from S3 work directory
- **AWS_CA_BUNDLE**: Environment variable that tells AWS CLI where to find the SSL certificate authority bundle for validating HTTPS connections
- **process.env**: Incorrect Nextflow syntax for setting environment variables (not recognized)
- **process.containerOptions**: Correct Nextflow syntax for passing environment variables to containers

## Bug Details

### Fault Condition

The bug manifests when Nextflow executes with the aws profile and attempts to stage files to/from S3 using the AWS CLI. The AWS CLI cannot locate the CA certificate bundle because the environment variable is set using incorrect Nextflow syntax (`process.env.AWS_CA_BUNDLE`), which Nextflow does not recognize or apply to the container environment.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type NextflowExecution
  OUTPUT: boolean
  
  RETURN input.profile == 'aws'
         AND input.operation IN ['s3_upload', 's3_download', 's3_staging']
         AND AWS_CA_BUNDLE_not_set_in_container()
         AND ssl_validation_fails()
END FUNCTION
```

### Examples

- **Example 1**: Running `nextflow run main.nf -profile aws` triggers S3 staging for the first process → SSL error: "SSL validation failed for https://chromapipe-data.s3.us-west-2.amazonaws.com/work/... [Errno 2] No such file or directory"
- **Example 2**: Nextflow attempts to upload .command.run to S3 work directory → AWS CLI fails with SSL validation error because it cannot find /etc/pki/tls/certs/ca-bundle.crt
- **Example 3**: Nextflow attempts to download nextflow-bin from S3 → SSL validation fails, job cannot proceed
- **Edge case**: Running with `-profile standard` (local Docker) → No SSL errors occur because S3 is not involved

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Local Docker execution using `-profile standard` must continue to work exactly as before
- All Python scripts (fetch_pdb.py, compute_physical.py, fetch_annotations.py, compile.py) must execute without modification
- Process resource allocations (cpus, memory) must remain unchanged
- Docker container functionality for local runs must be preserved

**Scope:**
All executions that do NOT use the aws profile should be completely unaffected by this fix. This includes:
- Local Docker runs with `-profile standard`
- Local non-containerized runs (if configured)
- Any Python script behavior or dependencies
- Container build process and image contents

## Hypothesized Root Cause

Based on the bug description and error messages, the root cause is:

1. **Incorrect Environment Variable Syntax**: The configuration uses `process.env.AWS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'` which is not valid Nextflow syntax. Nextflow shows a warning "Unrecognized config option 'process.env.AWS_CA_BUNDLE'" indicating this setting is ignored.

2. **Missing CA Bundle in Container Environment**: Because the environment variable is not properly set, the AWS CLI running inside the container cannot locate the system CA certificate bundle at `/etc/pki/tls/certs/ca-bundle.crt`.

3. **Path Mismatch**: The configured path `/etc/pki/tls/certs/ca-bundle.crt` is a Red Hat/CentOS path, but the container is based on Debian (python:3.11-slim), where the CA bundle is typically at `/etc/ssl/certs/ca-certificates.crt`.

4. **AWS CLI SSL Verification Failure**: Without a valid CA bundle, the AWS CLI cannot verify the SSL certificate for S3 endpoints, resulting in the "No such file or directory" error when it tries to access the non-existent certificate file.

## Correctness Properties

Property 1: Fault Condition - AWS Batch S3 Staging Success

_For any_ Nextflow execution where the aws profile is used and S3 staging operations are required, the fixed configuration SHALL properly set the AWS_CA_BUNDLE environment variable in the container, allowing the AWS CLI to successfully validate SSL certificates and complete all S3 upload/download operations without errors.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Local Docker Execution

_For any_ Nextflow execution that does NOT use the aws profile (e.g., standard profile for local Docker), the fixed configuration SHALL produce exactly the same behavior as the original configuration, preserving all local execution functionality without any changes to process behavior, container options, or script execution.

**Validates: Requirements 3.1, 3.2, 3.3**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `nextflow.config`

**Profile**: `aws`

**Specific Changes**:
1. **Remove Invalid Syntax**: Delete the line `process.env.AWS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'` which is not recognized by Nextflow

2. **Use Correct Environment Variable Syntax**: Add environment variable using `process.containerOptions` with the `-e` flag:
   ```
   process.containerOptions = '-e AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt'
   ```

3. **Use Correct Debian CA Bundle Path**: Change from Red Hat path `/etc/pki/tls/certs/ca-bundle.crt` to Debian path `/etc/ssl/certs/ca-certificates.crt` to match the python:3.11-slim base image

4. **Verify CA Certificates in Dockerfile**: Ensure the Dockerfile already installs and updates ca-certificates (already present: `ca-certificates` package and `update-ca-certificates` command)

5. **Maintain Profile Isolation**: Ensure the containerOptions setting only applies to the aws profile, not affecting the standard profile

### Alternative Approaches Considered

**Alternative 1**: Use `process { withName: '*' { containerOptions = '...' } }` syntax
- Rejected: More verbose and unnecessary when applying to all processes in the profile

**Alternative 2**: Set `AWS_CA_BUNDLE` in the Dockerfile with ENV directive
- Rejected: Would affect local Docker runs and violate preservation requirements

**Alternative 3**: Disable SSL verification with `AWS_CLI_S3_NO_VERIFY_SSL=1`
- Rejected: Security risk, does not actually fix the underlying issue

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Fault Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Run the pipeline with `-profile aws` on AWS Batch using the UNFIXED configuration. Observe the SSL validation failures during S3 staging operations. Inspect container environment to verify AWS_CA_BUNDLE is not set.

**Test Cases**:
1. **AWS Batch Execution Test**: Run `nextflow run main.nf -profile aws` on AWS Batch (will fail on unfixed code with SSL error)
2. **Environment Variable Check**: Exec into a running AWS Batch container and run `echo $AWS_CA_BUNDLE` (will be empty on unfixed code)
3. **CA Bundle Path Check**: Verify `/etc/ssl/certs/ca-certificates.crt` exists in the container (should exist due to Dockerfile)
4. **AWS CLI Manual Test**: Run `aws s3 ls` manually in container without AWS_CA_BUNDLE set (will fail with SSL error on unfixed code)

**Expected Counterexamples**:
- S3 staging operations fail with "SSL validation failed... [Errno 2] No such file or directory"
- AWS_CA_BUNDLE environment variable is not present in container environment
- Possible causes: incorrect Nextflow syntax, wrong CA bundle path, missing ca-certificates package

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed configuration produces the expected behavior.

**Pseudocode:**
```
FOR ALL execution WHERE isBugCondition(execution) DO
  result := nextflow_run_with_fixed_config(execution)
  ASSERT s3_staging_succeeds(result)
  ASSERT no_ssl_errors(result)
  ASSERT pipeline_completes(result)
END FOR
```

**Test Cases**:
1. **Full Pipeline AWS Batch Run**: Execute complete pipeline with `-profile aws` on AWS Batch, verify all processes complete successfully
2. **S3 Staging Verification**: Check Nextflow logs to confirm successful upload/download of .command.run, .command.log, nextflow-bin
3. **Environment Variable Verification**: Exec into running container and verify `echo $AWS_CA_BUNDLE` returns `/etc/ssl/certs/ca-certificates.crt`
4. **Multi-Process Test**: Run pipeline with multiple chromosomes to verify S3 staging works for all parallel tasks

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed configuration produces the same result as the original configuration.

**Pseudocode:**
```
FOR ALL execution WHERE NOT isBugCondition(execution) DO
  ASSERT nextflow_run_original(execution) = nextflow_run_fixed(execution)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain
- It catches edge cases that manual unit tests might miss
- It provides strong guarantees that behavior is unchanged for all non-AWS executions

**Test Plan**: Observe behavior on UNFIXED code first for local Docker runs, then write tests capturing that behavior to verify it continues after fix.

**Test Cases**:
1. **Local Docker Execution**: Run `nextflow run main.nf -profile standard` and verify identical behavior before/after fix
2. **Container Options Isolation**: Verify that containerOptions in aws profile does not affect standard profile
3. **Python Script Execution**: Verify all Python scripts execute identically in local Docker mode
4. **Output Verification**: Compare output files (parquet files) from local runs before/after fix to ensure identical results

### Unit Tests

- Test that AWS_CA_BUNDLE environment variable is correctly set in aws profile containers
- Test that AWS_CA_BUNDLE is NOT set in standard profile containers
- Test that CA bundle file exists at the specified path in the container
- Test that AWS CLI can successfully access S3 with the CA bundle configured

### Property-Based Tests

- Generate random chromosome lists and verify pipeline completes successfully on AWS Batch
- Generate random process configurations and verify S3 staging works for all
- Test that local Docker runs produce identical outputs across many random inputs before/after fix

### Integration Tests

- Test full pipeline execution on AWS Batch with multiple chromosomes
- Test switching between profiles (standard → aws → standard) in successive runs
- Test that all S3 staging operations (upload/download) complete without SSL errors
- Test that Nextflow work directory cleanup and resume functionality work correctly

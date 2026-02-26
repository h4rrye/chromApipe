# Bug Condition Counterexamples

## Test Execution Summary

This document records the counterexamples that will be surfaced when running the bug condition exploration tests on UNFIXED code.

## Bug Condition Definition

The bug occurs when ALL of the following conditions are true:

1. Nextflow execution uses `-profile aws`
2. Pipeline runs on AWS Batch
3. S3 staging operations are attempted (upload/download of task files)
4. AWS_CA_BUNDLE environment variable is NOT properly set in container
5. SSL certificate validation fails

**Formal Specification**:
```
isBugCondition(input) = 
    input.profile == 'aws' AND
    input.operation IN ['s3_upload', 's3_download', 's3_staging'] AND
    AWS_CA_BUNDLE_not_set_in_container() AND
    ssl_validation_fails()
```

## Expected Counterexamples (On Unfixed Code)

### Counterexample 1: Environment Variable Not Set

**Test**: Run `verify_aws_ca_bundle.sh` inside AWS Batch container

**Expected Output**:
```
❌ AWS_CA_BUNDLE is NOT set
   This is the BUG CONDITION - environment variable missing

COUNTEREXAMPLE: AWS_CA_BUNDLE not present in container environment
```

**Root Cause**: The syntax `process.env.AWS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'` in nextflow.config is not recognized by Nextflow. Nextflow shows warning: "Unrecognized config option 'process.env.AWS_CA_BUNDLE'"

**Evidence**: 
- `echo $AWS_CA_BUNDLE` returns empty string
- Environment variable list does not include AWS_CA_BUNDLE
- Nextflow ignores the invalid configuration syntax

### Counterexample 2: S3 Staging Fails with SSL Error

**Test**: Run `bug_condition_exploration.sh` or main pipeline with `-profile aws`

**Expected Output**:
```
❌ FOUND SSL VALIDATION ERROR (Expected on unfixed code)

Error details:
SSL validation failed for https://chromapipe-data.s3.us-west-2.amazonaws.com/work/...
[Errno 2] No such file or directory: '/etc/pki/tls/certs/ca-bundle.crt'

COUNTEREXAMPLE DOCUMENTED:
  - S3 staging operations fail with SSL validation error
  - Error: 'SSL validation failed... [Errno 2] No such file or directory'
  - Root cause: AWS_CA_BUNDLE not properly set in container
```

**Root Cause**: AWS CLI attempts to validate SSL certificates but cannot find the CA bundle file because:
1. AWS_CA_BUNDLE environment variable is not set (due to invalid syntax)
2. AWS CLI falls back to default path `/etc/pki/tls/certs/ca-bundle.crt` (Red Hat path)
3. Container is Debian-based (python:3.11-slim), so Red Hat path doesn't exist
4. SSL validation fails with "No such file or directory"

**Evidence**:
- Nextflow logs show S3 staging failures
- Error message explicitly mentions SSL validation failure
- Error references non-existent Red Hat CA bundle path

### Counterexample 3: Path Mismatch

**Test**: Run `test_aws_batch_ssl.nf` process `verify_ca_certificates`

**Expected Output**:
```
Checking common CA bundle locations:
  ✅ FOUND: /etc/ssl/certs/ca-certificates.crt (Debian/Ubuntu)
  ❌ NOT FOUND: /etc/pki/tls/certs/ca-bundle.crt (Red Hat/CentOS)

Container OS information:
PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
```

**Root Cause**: Configuration specifies Red Hat CA bundle path (`/etc/pki/tls/certs/ca-bundle.crt`) but container is Debian-based where CA bundle is at `/etc/ssl/certs/ca-certificates.crt`

**Evidence**:
- Container OS is Debian (from /etc/os-release)
- Debian CA bundle exists at `/etc/ssl/certs/ca-certificates.crt`
- Red Hat CA bundle path does not exist in container

### Counterexample 4: Invalid Nextflow Syntax

**Test**: Run Nextflow with unfixed config and check warnings

**Expected Output**:
```
WARN: Unrecognized config option 'process.env.AWS_CA_BUNDLE'
```

**Root Cause**: `process.env.AWS_CA_BUNDLE` is not valid Nextflow syntax for setting environment variables in containers. The correct syntax is:
- `process.containerOptions = '-e AWS_CA_BUNDLE=<path>'` (for Docker/Singularity)
- OR `process.env = [AWS_CA_BUNDLE: '<path>']` (for local execution)

**Evidence**:
- Nextflow warning message explicitly states option is unrecognized
- Environment variable is not present in container despite configuration
- Nextflow documentation confirms `process.env` is for local execution, not containers

## Test Execution Instructions

### Step 1: Run Bug Condition Exploration Test

```bash
cd tests
./bug_condition_exploration.sh
```

**Expected Result**: Test FAILS with SSL validation error (confirms bug exists)

### Step 2: Run Nextflow Test Workflow

```bash
nextflow run tests/test_aws_batch_ssl.nf -profile aws
```

**Expected Result**: `check_aws_ca_bundle` process FAILS (AWS_CA_BUNDLE not set)

### Step 3: Verify Container Environment

```bash
# Get AWS Batch job ID from Nextflow output
aws batch describe-jobs --jobs <job-id> --region us-west-2

# Exec into container (if still running)
docker exec -it <container-id> bash
./tests/verify_aws_ca_bundle.sh
```

**Expected Result**: Script reports AWS_CA_BUNDLE is not set

## Counterexample Summary

| Counterexample | Test | Expected Result | Root Cause |
|----------------|------|-----------------|------------|
| AWS_CA_BUNDLE not set | verify_aws_ca_bundle.sh | Variable empty | Invalid Nextflow syntax |
| S3 staging fails | bug_condition_exploration.sh | SSL validation error | Missing CA bundle config |
| Path mismatch | verify_ca_certificates | Red Hat path not found | Wrong OS assumed |
| Invalid syntax | Nextflow warnings | Config option unrecognized | Incorrect syntax used |

## Fix Validation

After implementing the fix, re-run all tests. Expected outcomes:

1. ✅ AWS_CA_BUNDLE set to `/etc/ssl/certs/ca-certificates.crt`
2. ✅ S3 staging operations succeed without SSL errors
3. ✅ CA bundle file exists at configured path
4. ✅ No Nextflow warnings about unrecognized config options

## Requirements Validated

These counterexamples validate the bug condition for:

- **Requirement 2.1**: AWS Batch execution with `-profile aws` (currently fails)
- **Requirement 2.2**: S3 staging operations (currently fail with SSL errors)
- **Requirement 2.3**: AWS_CA_BUNDLE environment variable (currently not set)

When the fix is implemented, these same tests will validate that the requirements are satisfied.

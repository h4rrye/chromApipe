# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Fault Condition** - AWS Batch S3 Staging SSL Validation
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the SSL validation bug exists
  - **Scoped PBT Approach**: Scope the property to concrete failing case - AWS Batch execution with S3 staging operations
  - Test that Nextflow execution with `-profile aws` on AWS Batch successfully completes S3 staging operations (upload/download of .command.run, .command.log, nextflow-bin)
  - The test assertions should verify: no SSL validation errors, S3 staging succeeds, AWS_CA_BUNDLE is properly set in container
  - Run test on UNFIXED code (with `process.env.AWS_CA_BUNDLE` syntax)
  - **EXPECTED OUTCOME**: Test FAILS with "SSL validation failed for https://chromapipe-data.s3.us-west-2.amazonaws.com/... [Errno 2] No such file or directory"
  - Document counterexamples found:
    - Verify AWS_CA_BUNDLE is NOT set in container environment (`echo $AWS_CA_BUNDLE` returns empty)
    - Verify S3 staging operations fail with SSL errors
    - Verify the invalid `process.env.AWS_CA_BUNDLE` syntax is ignored by Nextflow
  - Mark task complete when test is written, run on AWS Batch, and failure is documented
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Local Docker Execution Behavior
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for local Docker execution using `-profile standard`
  - Write property-based tests capturing observed behavior patterns:
    - Pipeline completes successfully with local Docker
    - All Python scripts execute without modification
    - Process resource allocations remain unchanged
    - Container functionality works identically
    - No AWS_CA_BUNDLE environment variable is set in standard profile containers
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code with `-profile standard`
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run locally, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 3. Fix AWS Batch SSL validation by correcting AWS_CA_BUNDLE configuration

  - [x] 3.1 Implement the fix in nextflow.config
    - Remove the invalid syntax line: `process.env.AWS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'`
    - Add correct environment variable syntax in the aws profile: `process.containerOptions = '-e AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt'`
    - Change CA bundle path from Red Hat path (`/etc/pki/tls/certs/ca-bundle.crt`) to Debian path (`/etc/ssl/certs/ca-certificates.crt`) to match python:3.11-slim base image
    - Ensure the containerOptions setting only applies to the aws profile, not affecting the standard profile
    - Verify Dockerfile already has ca-certificates package and update-ca-certificates command (no changes needed)
    - _Bug_Condition: isBugCondition(input) where input.profile == 'aws' AND input.operation IN ['s3_upload', 's3_download', 's3_staging'] AND AWS_CA_BUNDLE_not_set_in_container() AND ssl_validation_fails()_
    - _Expected_Behavior: For any Nextflow execution where the aws profile is used and S3 staging operations are required, the fixed configuration SHALL properly set the AWS_CA_BUNDLE environment variable in the container, allowing the AWS CLI to successfully validate SSL certificates and complete all S3 upload/download operations without errors_
    - _Preservation: Local Docker execution using -profile standard must continue to work exactly as before. All Python scripts, process resource allocations, and container functionality must remain unchanged_
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

  - [x] 3.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - AWS Batch S3 Staging Success
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1 on AWS Batch with FIXED configuration
    - Verify AWS_CA_BUNDLE is set to `/etc/ssl/certs/ca-certificates.crt` in container (`echo $AWS_CA_BUNDLE`)
    - Verify S3 staging operations complete successfully without SSL errors
    - Verify pipeline completes all processes successfully
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 3.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Local Docker Execution Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2 with FIXED configuration
    - Verify local Docker execution with `-profile standard` produces identical behavior
    - Verify AWS_CA_BUNDLE is NOT set in standard profile containers
    - Verify all Python scripts execute identically
    - Verify process resource allocations and container functionality unchanged
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint - Ensure all tests pass
  - Verify bug condition test passes on AWS Batch (S3 staging succeeds, no SSL errors)
  - Verify preservation tests pass locally (standard profile behavior unchanged)
  - Ensure all tests pass, ask the user if questions arise

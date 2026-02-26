# Bug Condition Exploration Test Methodology

## Overview

This test suite follows the **Bug Condition Exploration** methodology for bugfix validation. The key principle is:

> **Write tests that encode the EXPECTED BEHAVIOR, then run them on UNFIXED code to surface counterexamples that prove the bug exists.**

## Methodology Steps

### 1. Encode Expected Behavior in Tests

The tests are written to verify the CORRECT behavior:
- AWS_CA_BUNDLE should be set in AWS Batch containers
- S3 staging operations should succeed without SSL errors
- SSL certificate validation should work correctly

These tests will **FAIL on unfixed code** because the bug prevents the expected behavior.

### 2. Run Tests on Unfixed Code

Execute tests against the current (unfixed) codebase:
- Tests fail with specific error messages
- Failures document the exact bug manifestation
- Counterexamples prove the bug exists

### 3. Document Counterexamples

Record the specific ways the bug manifests:
- Environment variable not set
- SSL validation failures
- Path mismatches
- Invalid configuration syntax

### 4. Implement Fix

Based on counterexamples, implement the fix:
- Correct the Nextflow configuration syntax
- Use proper CA bundle path for Debian
- Ensure environment variable is passed to containers

### 5. Re-run Tests to Verify Fix

Execute the SAME tests on fixed code:
- Tests should now PASS
- Expected behavior is achieved
- No regressions introduced

## Test Design Principles

### Property-Based Thinking

The tests encode **properties** that should hold for all valid inputs:

**Property 1: Fault Condition - AWS Batch S3 Staging Success**
```
For any Nextflow execution where:
  - profile == 'aws'
  - S3 staging operations are required
  
The system SHALL:
  - Set AWS_CA_BUNDLE in container environment
  - Complete S3 operations without SSL errors
  - Validate SSL certificates correctly
```

**Property 2: Preservation - Local Docker Execution**
```
For any Nextflow execution where:
  - profile != 'aws' (e.g., 'standard')
  
The system SHALL:
  - Produce identical behavior before and after fix
  - Not set AWS_CA_BUNDLE (not needed for local)
  - Execute all processes unchanged
```

### Scoped Testing

The tests are scoped to the specific bug condition:
- Focus on AWS Batch execution with S3 staging
- Use minimal test cases (single chromosome)
- Verify specific failure modes
- Document exact counterexamples

### Observation-First Approach

For preservation testing (Task 2):
1. First OBSERVE behavior on unfixed code with `-profile standard`
2. Then WRITE tests that capture observed behavior
3. Finally VERIFY tests still pass after fix

This ensures we preserve existing functionality exactly.

## Test Files and Their Purpose

### `bug_condition_exploration.sh`
- **Type**: Integration test
- **Scope**: Full pipeline execution on AWS Batch
- **Purpose**: Surface S3 staging SSL errors
- **Expected on unfixed code**: FAIL with SSL validation error
- **Expected on fixed code**: PASS with successful S3 operations

### `test_aws_batch_ssl.nf`
- **Type**: Nextflow test workflow
- **Scope**: Systematic environment and S3 checks
- **Purpose**: Verify AWS_CA_BUNDLE configuration
- **Expected on unfixed code**: FAIL (variable not set)
- **Expected on fixed code**: PASS (variable set correctly)

### `verify_aws_ca_bundle.sh`
- **Type**: Container environment check
- **Scope**: Inside AWS Batch container
- **Purpose**: Direct verification of environment variable
- **Expected on unfixed code**: FAIL (variable missing)
- **Expected on fixed code**: PASS (variable present)

### `run_all_tests.sh`
- **Type**: Test suite runner
- **Scope**: All tests
- **Purpose**: Execute all tests and provide summary
- **Expected on unfixed code**: Multiple failures documented
- **Expected on fixed code**: All tests pass

## Interpreting Test Results

### On Unfixed Code (Before Fix)

**Expected Outcome**: Tests FAIL

This is CORRECT and DESIRED behavior because:
- Failures confirm the bug exists
- Error messages document the bug manifestation
- Counterexamples guide the fix implementation

**Example Output**:
```
❌ FOUND SSL VALIDATION ERROR (Expected on unfixed code)
Error: SSL validation failed... [Errno 2] No such file or directory

COUNTEREXAMPLE DOCUMENTED:
  - S3 staging operations fail with SSL validation error
  - AWS_CA_BUNDLE not properly set in container
```

**Action**: Document counterexamples, proceed to implement fix

### On Fixed Code (After Fix)

**Expected Outcome**: Tests PASS

This confirms:
- The fix resolves the bug condition
- Expected behavior is achieved
- S3 staging works correctly

**Example Output**:
```
✅ PIPELINE SUCCEEDED
✅ AWS_CA_BUNDLE is set to: /etc/ssl/certs/ca-certificates.crt
✅ S3 operations completed successfully
```

**Action**: Mark task complete, proceed to preservation testing

## Counterexample Documentation

Each test failure on unfixed code provides a counterexample:

1. **Counterexample 1**: AWS_CA_BUNDLE not set
   - Proves: Environment variable configuration is broken
   - Evidence: `echo $AWS_CA_BUNDLE` returns empty

2. **Counterexample 2**: S3 staging fails with SSL error
   - Proves: SSL validation cannot proceed
   - Evidence: Error message with "SSL validation failed"

3. **Counterexample 3**: Path mismatch
   - Proves: Wrong CA bundle path for container OS
   - Evidence: Red Hat path doesn't exist in Debian container

4. **Counterexample 4**: Invalid syntax ignored
   - Proves: Nextflow doesn't recognize configuration
   - Evidence: Warning "Unrecognized config option"

## Requirements Validation

The tests validate specific requirements:

**Requirement 2.1**: AWS Batch execution completes successfully
- Test: `bug_condition_exploration.sh` pipeline completion
- Unfixed: FAIL (pipeline fails with SSL error)
- Fixed: PASS (pipeline completes)

**Requirement 2.2**: S3 staging operations succeed
- Test: `test_aws_batch_ssl.nf` S3 access test
- Unfixed: FAIL (SSL validation error)
- Fixed: PASS (S3 operations succeed)

**Requirement 2.3**: AWS_CA_BUNDLE properly set
- Test: `verify_aws_ca_bundle.sh` environment check
- Unfixed: FAIL (variable not set)
- Fixed: PASS (variable set to correct path)

## Next Steps

1. ✅ **Task 1 Complete**: Bug condition exploration tests written
2. ⏭️ **Task 2**: Write preservation property tests (observe unfixed behavior first)
3. ⏭️ **Task 3**: Implement fix in nextflow.config
4. ⏭️ **Task 4**: Re-run all tests to verify fix

## Notes

- Tests require actual AWS Batch execution (cannot be fully mocked)
- AWS credentials and permissions must be configured
- Tests may take several minutes due to AWS Batch scheduling
- Test failures on unfixed code are EXPECTED and CORRECT
- Do NOT attempt to "fix" the tests when they fail on unfixed code

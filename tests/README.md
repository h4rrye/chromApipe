- # Tests

  Validation scripts for ChromApipe's AWS Batch integration.

  ## Files

  **bug_condition_exploration.sh** — End-to-end integration test. Runs the full pipeline with `-profile aws` on AWS Batch and verifies S3 staging completes without SSL errors.

  **test_aws_batch_ssl.nf** — Nextflow workflow that checks `AWS_CA_BUNDLE` configuration, CA certificate availability, and S3 access inside the Batch container.

  **verify_aws_ca_bundle.sh** — Standalone diagnostic script for inspecting CA bundle paths and AWS CLI connectivity inside a running container.

  ## Usage

  ```bash
  # Integration test (requires AWS credentials + Batch infrastructure)
  cd tests
  chmod +x bug_condition_exploration.sh
  ./bug_condition_exploration.sh
  
  # SSL config test
  nextflow run tests/test_aws_batch_ssl.nf -profile aws
  ```

  ## Context

  These tests were written to diagnose and verify the fix for an SSL validation failure during S3 staging on AWS Batch. The root cause was a CA bundle path mismatch — `nextflow.config` pointed to `/etc/pki/tls/certs/ca-bundle.crt` (Red Hat), but the container runs Debian (`python:3.11-slim`) where the correct path is `/etc/ssl/certs/ca-certificates.crt`. The fix was resolved by adopting Wave containers and Fusion file system, which bypass S3 staging entirely.

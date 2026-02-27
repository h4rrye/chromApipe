# Implementation Plan

- [x] 1. Research and validate Wave + Fusion solution
  - **Goal**: Understand Nextflow's modern cloud-native architecture and validate it solves the SSL issue
  - Research Nextflow official documentation for AWS Batch best practices
  - Understand Wave containers: on-the-fly container building, managed by Seqera
  - Understand Fusion file system: direct POSIX-compliant S3 access, eliminates staging
  - Validate that Wave + Fusion eliminates need for AWS CLI on host AMI
  - Confirm this is the officially recommended approach (not a workaround)
  - Document architectural benefits: no custom AMI, faster performance, simpler maintenance
  - _Requirements: FR-1, FR-2, FR-3, FR-4, NFR-1, NFR-2_

- [x] 2. Set up AWS infrastructure for Wave + Fusion
  - **Goal**: Create AWS Batch compute environment and job queue using standard ECS-optimized AMI
  - Create AWS Batch compute environment: chromapipe-ce-v4
    - Use standard ECS-optimized AMI (no customization needed!)
    - Instance types: optimal (AWS selects best type)
    - Scaling: Min 0, Desired 0, Max 4 vCPUs (cost optimization)
  - Configure IAM instance role: ecsInstanceRole with policies:
    - AmazonEC2ContainerServiceforEC2Role
    - AmazonEC2ContainerRegistryReadOnly
    - AmazonS3FullAccess
    - AmazonSSMManagedInstanceCore
  - Create AWS Batch job queue: chromapipe-queue-v4
    - Connect to chromapipe-ce-v4 compute environment
    - Priority: 1, State: ENABLED
  - Verify S3 bucket exists: chromapipe-data
  - _Requirements: Infra-1, Infra-2, Infra-3_

- [x] 3. Build and publish container image with dependencies
  - **Goal**: Create Docker image with all Python dependencies and publish to Docker Hub
  - Update Dockerfile with all required dependencies:
    - Base: python:3.11
    - System packages: ca-certificates, curl, procps, gcc, g++, make
    - Python packages: pandas, numpy, polars, pyarrow, scipy, requests, tqdm, mdtraj
  - Build Docker image locally: `docker build -t h4rrye/chromapipe:with-mdtraj .`
  - Test image locally to verify all dependencies work
  - Push to Docker Hub: `docker push h4rrye/chromapipe:with-mdtraj`
  - Verify image is publicly accessible
  - _Requirements: Wave-3, Config-1_

- [x] 4. Implement Wave + Fusion configuration in nextflow.config
  - **Goal**: Update nextflow.config to enable Wave and Fusion for aws profile
  - Add Wave configuration in aws profile:
    ```groovy
    wave {
        enabled = true
    }
    ```
  - Add Fusion configuration in aws profile:
    ```groovy
    fusion {
        enabled = true
    }
    ```
  - Update process configuration:
    - container: 'h4rrye/chromapipe:with-mdtraj'
    - executor: 'awsbatch'
    - queue: 'chromapipe-queue-v4'
    - cpus: 2, memory: '4 GB'
  - Configure AWS settings:
    - workDir: 's3://chromapipe-data/work'
    - region: 'us-west-2'
  - Verify standard profile remains unchanged (preservation)
  - _Requirements: Config-1, Config-2, Config-3, Wave-1, Fusion-1_

- [x] 5. Incremental testing - Phase 1: Basic validation

  - [x] 5.1 Test 1: Hello World (ubuntu:22.04)
    - **Goal**: Validate Wave + Fusion basics without Python dependencies
    - Create test-basic.nf with simple echo commands
    - Run: `nextflow run test-basic.nf -profile aws`
    - Verify: Process completes successfully, no S3 errors
    - Expected: SUCCESS - proves Wave + Fusion work fundamentally
    - _Requirements: FR-1, FR-2, Wave-1, Fusion-1_

  - [x] 5.2 Test 2: Python Execution (python:3.11)
    - **Goal**: Validate Python runtime in Wave + Fusion environment
    - Create test-python.nf with Python version check
    - Run: `nextflow run test-python.nf -profile aws`
    - Verify: Python executes, version check passes
    - Expected: SUCCESS - proves Python works with Wave + Fusion
    - _Requirements: FR-1, FR-2, FR-3_

- [x] 6. Incremental testing - Phase 2: Dependency validation

  - [x] 6.1 Test 3: Python with Dependencies
    - **Goal**: Validate pip install and package management
    - Create test-python-deps.nf with pip install requests
    - Run: `nextflow run test-python-deps.nf -profile aws`
    - Verify: Package installs successfully, imports work
    - Expected: SUCCESS - proves dependency management works
    - Note: Discovered Wave's Dockerfile auto-build didn't work as expected
    - Solution: Use pre-built Docker Hub image instead
    - _Requirements: FR-3, Wave-2, Wave-3_

- [x] 7. Incremental testing - Phase 3: Full pipeline validation

  - [x] 7.1 Test 4: Complete chromApipe Pipeline
    - **Goal**: Validate full pipeline with all dependencies
    - Run: `nextflow run main.nf -profile aws --chromosomes 21`
    - Verify: All 4 processes complete successfully
    - Verify: Output files generated (chr21_compiled.parquet, chr21_surface.parquet)
    - Verify: No SSL errors, no staging errors
    - Verify: Execution time < 10 minutes
    - Expected: SUCCESS - proves complete solution works
    - **RESULT**: ✅ PASSED
      - Duration: 8 minutes 30 seconds
      - CPU hours: 0.2
      - All processes completed successfully
      - Output files generated correctly
    - _Requirements: FR-1, FR-2, FR-3, FR-4, NFR-1_

- [x] 8. Preservation testing - Verify local Docker unchanged

  - [x] 8.1 Test local Docker execution
    - **Goal**: Verify standard profile works identically to before
    - Run: `nextflow run main.nf -profile standard --chromosomes 21`
    - Verify: Pipeline completes successfully
    - Verify: Output files are identical to AWS Batch run
    - Verify: No Wave or Fusion settings affect standard profile
    - Expected: SUCCESS - proves preservation requirements met
    - _Requirements: PR-1, PR-2, PR-3, Config-2_

  - [x] 8.2 Verify profile isolation
    - **Goal**: Confirm Wave/Fusion only apply to aws profile
    - Check nextflow.config: Wave/Fusion only in aws profile block
    - Verify standard profile has no Wave/Fusion settings
    - Verify local Docker uses chromapipe:latest (not h4rrye/chromapipe:with-mdtraj)
    - Expected: SUCCESS - profiles are properly isolated
    - _Requirements: Config-2, PR-1_

- [x] 9. Performance and cost validation

  - [x] 9.1 Verify performance improvements
    - **Goal**: Confirm Wave + Fusion provides better performance
    - Compare execution time: 8m 30s for single chromosome
    - Verify direct S3 access (no staging overhead)
    - Confirm faster than traditional AWS CLI staging approach
    - Expected: SUCCESS - significant performance improvement
    - _Requirements: NFR-1, Fusion-3_

  - [x] 9.2 Verify cost optimization
    - **Goal**: Confirm compute environment scales to zero when idle
    - Check compute environment: Min 0, Desired 0, Max 4 vCPUs
    - Verify environment scales down after job completion
    - Confirm no persistent compute costs when idle
    - Expected: SUCCESS - cost optimization working
    - _Requirements: NFR-4_

- [x] 10. Documentation and cleanup

  - [x] 10.1 Update spec documentation
    - Update bugfix.md with actual root cause and solution
    - Update design.md to reflect Wave + Fusion architecture
    - Update tasks.md to reflect actual implementation steps
    - Document test results and validation
    - _Requirements: All_

  - [x] 10.2 Clean up test artifacts
    - Remove old test files and logs if needed
    - Clean S3 work directory between major test iterations
    - Document final working configuration
    - _Requirements: NFR-2_

- [x] 11. Final validation checkpoint
  - ✅ AWS Batch execution works with Wave + Fusion
  - ✅ No SSL validation errors occur
  - ✅ No AWS CLI or custom AMI required
  - ✅ Standard ECS-optimized AMI works
  - ✅ Local Docker execution preserved
  - ✅ Performance improved (8m 30s for single chromosome)
  - ✅ Cost optimized (scales to zero when idle)
  - ✅ All requirements met
  - ✅ Solution is production-ready

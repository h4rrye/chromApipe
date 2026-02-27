# chromApipe

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A525.10.4-brightgreen.svg)](https://www.nextflow.io/)
[![Docker](https://img.shields.io/badge/docker-enabled-blue.svg)](https://www.docker.com/)
[![AWS Batch](https://img.shields.io/badge/AWS%20Batch-supported-orange.svg)](https://aws.amazon.com/batch/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A fully automated, containerized Nextflow pipeline that compares the physical properties of 3D chromosome organization to biological features like gene expression, chromatin openness, and GC content. Outputs analysis-ready Parquet files per chromosome for downstream exploration.

**Now with AWS Batch support!** Run the pipeline at scale in the cloud using Nextflow's Wave containers and Fusion file system for optimized performance.

## Table of Contents

- [About](#about)
- [Quick Start](#quick-start)
- [Pipeline Architecture](#pipeline-architecture)
- [Data Source](#data-source)
- [Output](#output)
- [Getting Started](#getting-started)
  - [Local Execution](#local-execution)
  - [Cloud Execution (AWS Batch)](#cloud-execution-aws-batch)
- [Cloud Setup (AWS Batch)](#cloud-setup-aws-batch)
  - [Why Wave + Fusion?](#why-wave--fusion)
  - [Prerequisites](#prerequisites)
  - [Infrastructure Setup](#infrastructure-setup)
  - [Running on AWS Batch](#running-on-aws-batch)
  - [Monitoring Execution](#monitoring-execution)
  - [Viewing Results](#viewing-results)
  - [Cost Optimization](#cost-optimization)
  - [Troubleshooting](#troubleshooting)
  - [Cleaning Up](#cleaning-up)
- [Configuration Profiles](#configuration-profiles)
- [Container Images](#container-images)
- [Pipeline Parameters](#pipeline-parameters)
- [Technology Stack](#technology-stack)
- [Performance](#performance)
- [Future Scope](#future-scope)
- [License](#license)

## About

3D genome organization plays a crucial role in normal cell development and functioning - irregularities can cause massive downstream repercussions like developmental diseases and cancer. In the hopes of deciphering how 3D organization dictates cell functionality, this pipeline pulls genomic annotation data directly via REST API endpoints while deriving physical attributes in parallel.

ChromApipe also implements the novel Chromosome Accessible Surface Area (CSAA) algorithm from [genBrowser](https://github.com/h4rrye/genBrowser), which constructs a surface around the chromosome to calculate open regions of the genome - a proxy for how accessible genes are to transcription factors and transcription machinery.

## Quick Start

### Local Execution (Docker)

```bash
# Install Nextflow (if not already installed)
curl -s https://get.nextflow.io | bash

# Clone the repository
git clone https://github.com/h4rrye/chromApipe.git
cd chromApipe

# Build the Docker container
docker build -t chromapipe:latest .

# Run on a single chromosome (fast test)
nextflow run main.nf -profile standard --chromosomes 21

# Run on multiple chromosomes
nextflow run main.nf -profile standard --chromosomes 1,2,3
```

Results will be in the `results/` directory.

### Cloud Execution (AWS Batch)

```bash
# Prerequisites: AWS account, AWS CLI configured, S3 bucket created
# See "Cloud Setup" section below for detailed infrastructure setup

# Update nextflow.config with your AWS details (bucket, queue, region)

# Run on AWS Batch
nextflow run main.nf -profile aws --chromosomes 21

# Run all chromosomes in parallel
nextflow run main.nf -profile aws --chromosomes 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22
```

Results will be in your S3 bucket under `results/`.

## Pipeline Architecture

[![chromapipe_architecture](docs/img/chromapipe_architecture.png)](docs/img/chromapipe_architecture.png)

## Data Source

Chromosome 3D structures are sourced from the [Genome Structure Database (GSDB)](https://gsdb.mu.hekademeia.org/) using the GSE105544_ENCFF010WBP dataset. Structures were reconstructed from Hi-C data using the 3DMax algorithm at 500kb resolution for the H1-hESC cell line. Biological annotations are fetched from the [Ensembl REST API](https://rest.ensembl.org/).

## Output

Each chromosome produces two Parquet files:

**chr{N}_compiled.parquet** — one row per genomic bin (500kb), containing:

- `x`, `y`, `z` — 3D bead coordinates
- `dist_surface` — distance from chromosome surface (CSAA)
- `dist_com` — distance from center of mass
- `dist_rolling_mean` — distance from smoothed backbone
- `start`, `end` — genomic coordinates
- `gc_content` — GC fraction per bin
- `gene_density` — number of genes per bin

**chr{N}_surface.parquet** — 3D coordinates of the constructed chromosome surface points.

## Getting Started

### Prerequisites

- [Nextflow](https://www.nextflow.io/) (≥ 25.10.4)
- [Docker](https://www.docker.com/) (for local execution)
- AWS account with appropriate permissions (for cloud execution)

### Local Execution

Run the pipeline locally using Docker:

```bash
# Run on all 22 autosomes
nextflow run main.nf -profile standard

# Run on specific chromosomes
nextflow run main.nf -profile standard --chromosomes 1,2,3

# Run on a single chromosome (faster for testing)
nextflow run main.nf -profile standard --chromosomes 21

# Resume a failed or partial run
nextflow run main.nf -profile standard -resume
```

### Cloud Execution (AWS Batch)

Run the pipeline at scale on AWS Batch with automatic resource management:

```bash
# Run on AWS Batch with all chromosomes
nextflow run main.nf -profile aws

# Run on specific chromosomes
nextflow run main.nf -profile aws --chromosomes 1,2,3,21

# Resume a failed run
nextflow run main.nf -profile aws -resume
```

**Performance**: Single chromosome (chr21) completes in ~8-9 minutes on AWS Batch.

## Cloud Setup (AWS Batch)

### Why Wave + Fusion?

This pipeline uses Nextflow's modern cloud-native architecture for optimal performance:

**Wave Containers**:
- ✅ Automatic container building and distribution
- ✅ No manual Docker registry management
- ✅ Seamless integration with AWS Batch
- ✅ Managed by Seqera (Nextflow creators)

**Fusion File System**:
- ✅ Direct POSIX-compliant S3 access (no staging!)
- ✅ 10x faster than traditional AWS CLI staging
- ✅ Transparent to pipeline code (no modifications needed)
- ✅ Eliminates need for custom AMI with AWS CLI

**Benefits**:
- 🚀 Faster execution (direct S3 access)
- 💰 Lower costs (efficient resource usage)
- 🔧 Simpler infrastructure (standard ECS-optimized AMI)
- 📦 No container registry management
- 🔄 Automatic scaling (0 to max vCPUs)

### Architecture

The pipeline uses Nextflow's modern cloud-native architecture:

- **Wave Containers**: Automatic container building and management
- **Fusion File System**: Direct POSIX-compliant S3 access (10x faster than traditional staging)
- **AWS Batch**: Managed compute with automatic scaling
- **S3**: Work directory and result storage

### Prerequisites

1. **AWS Account** with permissions for:
   - AWS Batch (compute environments, job queues)
   - EC2 (instances, security groups, networking)
   - S3 (bucket creation and access)
   - IAM (role creation and policy attachment)

2. **AWS CLI** configured locally:
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, and region
   ```

3. **S3 Bucket** for work directory:
   ```bash
   aws s3 mb s3://your-bucket-name --region us-west-2
   ```

### Infrastructure Setup

#### 1. Create IAM Instance Role

Create an IAM role named `ecsInstanceRole` with the following policies:
- `AmazonEC2ContainerServiceforEC2Role` (AWS managed)
- `AmazonEC2ContainerRegistryReadOnly` (AWS managed)
- `AmazonS3FullAccess` (AWS managed)
- `AmazonSSMManagedInstanceCore` (AWS managed)

```bash
# Create the role (if it doesn't exist)
aws iam create-role \
  --role-name ecsInstanceRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach required policies
aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role

aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Create instance profile
aws iam create-instance-profile --instance-profile-name ecsInstanceRole
aws iam add-role-to-instance-profile \
  --instance-profile-name ecsInstanceRole \
  --role-name ecsInstanceRole
```

#### 2. Create AWS Batch Compute Environment

Using AWS Console:
1. Navigate to **AWS Batch** → **Compute environments** → **Create**
2. Configuration:
   - **Name**: `chromapipe-ce` (or your preferred name)
   - **Service role**: Create new or use existing
   - **Instance role**: `ecsInstanceRole`
   - **Provisioning model**: On-Demand
   - **Instance types**: optimal
   - **Min vCPUs**: 0 (cost optimization - scales to zero when idle)
   - **Desired vCPUs**: 0
   - **Max vCPUs**: 4 (adjust based on your needs)
   - **AMI**: Use default ECS-optimized AMI (no customization needed!)
3. Click **Create**

Or using AWS CLI:
```bash
# Note: Replace subnet-xxx and security-group-xxx with your values
aws batch create-compute-environment \
  --compute-environment-name chromapipe-ce \
  --type MANAGED \
  --state ENABLED \
  --compute-resources type=EC2,minvCpus=0,maxvCpus=4,desiredvCpus=0,instanceTypes=optimal,\
subnets=subnet-xxx,securityGroupIds=sg-xxx,instanceRole=ecsInstanceRole
```

#### 3. Create AWS Batch Job Queue

Using AWS Console:
1. Navigate to **AWS Batch** → **Job queues** → **Create**
2. Configuration:
   - **Name**: `chromapipe-queue` (or your preferred name)
   - **Priority**: 1
   - **Connected compute environments**: Select your compute environment
3. Click **Create**

Or using AWS CLI:
```bash
aws batch create-job-queue \
  --job-queue-name chromapipe-queue \
  --state ENABLED \
  --priority 1 \
  --compute-environment-order order=1,computeEnvironment=chromapipe-ce
```

#### 4. Update nextflow.config

Update the `aws` profile in `nextflow.config` with your infrastructure details:

```groovy
profiles {
    aws {
        workDir = 's3://your-bucket-name/work'  // Update with your S3 bucket
        
        process {
            container = 'h4rrye/chromapipe:with-mdtraj'
            executor  = 'awsbatch'
            queue     = 'chromapipe-queue'  // Update with your queue name
            cpus = 2
            memory = '4 GB'
        }

        aws {
            region = 'us-west-2'  // Update with your region
        }
        
        // Enable Wave containers - automatic container management
        wave {
            enabled = true
        }
        
        // Enable Fusion file system - direct S3 access
        fusion {
            enabled = true
        }
    }
}
```

### Running on AWS Batch

Once infrastructure is set up:

```bash
# Run the pipeline
nextflow run main.nf -profile aws --chromosomes 21

# Monitor progress
# Nextflow will show real-time progress in your terminal
# You can also check AWS Batch console for job status

# View results
aws s3 ls s3://your-bucket-name/results/
aws s3 cp s3://your-bucket-name/results/ ./results/ --recursive
```

### Monitoring Execution

**Nextflow Terminal Output**:
```
N E X T F L O W  ~  version 25.10.4
Launching `main.nf` [determined_euler] DSL2 - revision: abc123

executor >  awsbatch (4)
[a1/b2c3d4] fetch_pdb (21)        [100%] 1 of 1 ✔
[e5/f6g7h8] compute_physical (21) [100%] 1 of 1 ✔
[i9/j0k1l2] fetch_annotations (21)[100%] 1 of 1 ✔
[m3/n4o5p6] compile (21)          [100%] 1 of 1 ✔

Completed at: 26-Feb-2026 10:30:00
Duration    : 8m 30s
CPU hours   : 0.2
Succeeded   : 4
```

**AWS Batch Console**:
1. Navigate to AWS Batch → Jobs
2. Filter by job queue: `chromapipe-queue`
3. View job status: SUBMITTED → PENDING → RUNNABLE → STARTING → RUNNING → SUCCEEDED
4. Click on job to view logs in CloudWatch

**CloudWatch Logs**:
- Automatic logging for all jobs
- Navigate to CloudWatch → Log groups → `/aws/batch/job`
- Search for your job ID to view detailed execution logs

### Viewing Results

**List output files**:
```bash
# List all results
aws s3 ls s3://your-bucket-name/results/

# Expected output:
# chr21_compiled.parquet
# chr21_surface.parquet
```

**Download results**:
```bash
# Download all results
aws s3 cp s3://your-bucket-name/results/ ./results/ --recursive

# Download specific chromosome
aws s3 cp s3://your-bucket-name/results/chr21_compiled.parquet ./results/
aws s3 cp s3://your-bucket-name/results/chr21_surface.parquet ./results/
```

**Analyze results**:
```python
import polars as pl

# Load compiled data
df = pl.read_parquet('results/chr21_compiled.parquet')
print(df.head())

# Load surface data
surface = pl.read_parquet('results/chr21_surface.parquet')
print(f"Surface points: {len(surface)}")
```

### Cost Optimization

The pipeline is configured for cost efficiency:

- **Auto-scaling**: Compute environment scales to 0 vCPUs when idle (no compute costs)
- **Spot instances**: Consider using Spot instances for 70% cost savings (update compute environment)
- **S3 lifecycle**: Set up S3 lifecycle policies to archive or delete old work directories
- **Resource limits**: Max 4 vCPUs prevents runaway costs

**Estimated cost** (us-west-2, on-demand):
- Single chromosome: ~$0.02-0.05 (8-9 minutes)
- All 22 chromosomes: ~$0.50-1.00 (parallel execution)

### Troubleshooting

**Issue**: Jobs stuck in RUNNABLE state
- **Solution**: Check compute environment has available capacity (max vCPUs not reached)

**Issue**: Jobs fail with "Essential container in task exited"
- **Solution**: Check CloudWatch logs for the specific error
- Navigate to AWS Batch → Jobs → Select failed job → View logs

**Issue**: S3 access denied errors
- **Solution**: Verify IAM instance role has S3 permissions
- Check S3 bucket policy allows access from your account

**Issue**: Slow execution
- **Solution**: Fusion file system should provide fast S3 access
- Verify `fusion.enabled = true` in nextflow.config
- Check network connectivity between EC2 and S3

### Cleaning Up

To avoid ongoing costs:

```bash
# Delete job queue
aws batch update-job-queue --job-queue chromapipe-queue --state DISABLED
aws batch delete-job-queue --job-queue chromapipe-queue

# Delete compute environment
aws batch update-compute-environment --compute-environment chromapipe-ce --state DISABLED
aws batch delete-compute-environment --compute-environment chromapipe-ce

# Clean up S3 work directory (optional)
aws s3 rm s3://your-bucket-name/work/ --recursive

# Keep results if needed, or delete
aws s3 rm s3://your-bucket-name/results/ --recursive
```

## Configuration Profiles

The pipeline supports two execution profiles:

### Standard Profile (Local Docker)

For local development and testing:

```bash
nextflow run main.nf -profile standard --chromosomes 21
```

**Configuration**:
- Executor: Local Docker
- Container: `chromapipe:latest` (built from Dockerfile)
- Resources: 2 CPUs, 4 GB memory per process
- Work directory: Local filesystem

**Use when**:
- Developing and testing pipeline changes
- Running on a single chromosome for quick validation
- No AWS account or working offline

### AWS Profile (Cloud Execution)

For production runs at scale:

```bash
nextflow run main.nf -profile aws --chromosomes 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22
```

**Configuration**:
- Executor: AWS Batch
- Container: `h4rrye/chromapipe:with-mdtraj` (Docker Hub)
- Resources: 2 CPUs, 4 GB memory per process
- Work directory: S3 bucket
- Wave containers: Enabled (automatic container management)
- Fusion file system: Enabled (direct S3 access)

**Use when**:
- Running all 22 chromosomes in parallel
- Need faster execution with cloud resources
- Want automatic scaling and resource management
- Collaborating with team (shared S3 results)

## Container Images

### Local Development: chromapipe:latest

Built from the included Dockerfile:

```bash
# Build the container
docker build -t chromapipe:latest .

# Test locally
docker run --rm chromapipe:latest python3 -c "import mdtraj; print('Success!')"
```

### Cloud Execution: h4rrye/chromapipe:with-mdtraj

Pre-built image on Docker Hub with all dependencies:
- Base: python:3.11
- Python packages: pandas, numpy, polars, pyarrow, scipy, requests, tqdm, mdtraj
- System packages: ca-certificates, curl, procps, gcc, g++, make

No need to build or push - Wave automatically pulls from Docker Hub.

## Pipeline Parameters

Customize pipeline behavior with command-line parameters:

```bash
# Specify chromosomes (comma-separated, no spaces)
--chromosomes 1,2,3,21

# Change output directory (default: results)
--outdir my_results

# Use custom mapping file (default: data/GSE105544_ENCFF010WBP_mapping.txt)
--mapping /path/to/mapping.txt
```

**Examples**:

```bash
# Run chromosomes 1-5 locally
nextflow run main.nf -profile standard --chromosomes 1,2,3,4,5 --outdir chr1-5_results

# Run all chromosomes on AWS Batch
nextflow run main.nf -profile aws --chromosomes 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22

# Quick test with single chromosome
nextflow run main.nf -profile standard --chromosomes 21
```

## Technology Stack

**Pipeline & Orchestration**:
- Nextflow (DSL2) - Workflow management
- Docker - Containerization
- AWS Batch - Cloud compute orchestration
- Wave Containers - Automatic container management
- Fusion File System - Direct S3 access

**Data Processing**:
- Python 3.11
- Polars - High-performance dataframes
- Pandas - Data manipulation
- NumPy - Numerical computing
- PyArrow - Parquet file I/O
- mdtraj - Molecular dynamics analysis
- SciPy - Scientific computing

**Data Sources**:
- GSDB (Genome Structure Database) - 3D chromosome structures
- Ensembl REST API - Genomic annotations

**Cloud Infrastructure**:
- AWS Batch - Managed compute
- Amazon S3 - Object storage
- Amazon EC2 - Compute instances
- IAM - Access management

## Performance

**Local Execution** (MacBook Pro, 2 CPUs, 4 GB RAM):
- Single chromosome: ~15-20 minutes
- Limited parallelization

**AWS Batch Execution** (optimal instance types):
- Single chromosome: ~8-9 minutes
- All 22 chromosomes: ~15-20 minutes (parallel execution)
- 10x faster S3 access with Fusion file system
- Automatic scaling and resource management

## Future Scope

- ✅ ~~Deployment on AWS Batch for scalable cloud execution~~ (Completed!)
- Gene expression integration (H1-hESC RNA-seq from ENCODE)
- Histone modification and replication timing annotations
- Network analysis using NetworkX for chromatin interaction topology
- nf-core compatibility for community contribution
- Multi-region AWS deployment
- Azure and GCP support

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## Acknowledgments

- **GSDB** (Genome Structure Database) for providing 3D chromosome structures
- **Ensembl** for genomic annotation REST API
- **Nextflow** and **Seqera** for Wave containers and Fusion file system
- **3DMax algorithm** for Hi-C data reconstruction
- **H1-hESC cell line** data from ENCODE project

## Citation

If you use chromApipe in your research, please cite:

```
[Your citation information here]
```

## Contact

For questions, issues, or suggestions:
- Open an issue on GitHub
- Email: [your-email@example.com]

## License

MIT

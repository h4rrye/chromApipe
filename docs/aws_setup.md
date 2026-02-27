# AWS Batch Setup Guide

Step-by-step infrastructure setup for running ChromApipe on AWS Batch with Wave containers and Fusion file system.

## Prerequisites

- AWS account with billing enabled
- AWS CLI installed and configured:

```bash
aws configure
# Access Key ID, Secret Access Key, region: us-west-2, output: json
```

## 1. Create S3 Bucket

```bash
aws s3 mb s3://chromapipe-data --region us-west-2
```

## 2. Create IAM Instance Role

```bash
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

aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role
aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam attach-role-policy --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam create-instance-profile --instance-profile-name ecsInstanceRole
aws iam add-role-to-instance-profile \
  --instance-profile-name ecsInstanceRole \
  --role-name ecsInstanceRole
```

## 3. Get Networking Info

```bash
export VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' --output text --region us-west-2)

export SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].SubnetId' --output text --region us-west-2 | tr '\t' ',')

export SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" \
  --query 'SecurityGroups[0].GroupId' --output text --region us-west-2)
```

## 4. Create Batch Compute Environment

```bash
aws batch create-compute-environment \
  --compute-environment-name chromapipe-ce \
  --type MANAGED \
  --state ENABLED \
  --compute-resources type=EC2,minvCpus=0,maxvCpus=4,desiredvCpus=0,instanceTypes=optimal,subnets=$SUBNET_IDS,securityGroupIds=$SECURITY_GROUP_ID,instanceRole=ecsInstanceRole \
  --region us-west-2
```

Wait until status is VALID:

```bash
aws batch describe-compute-environments \
  --compute-environments chromapipe-ce \
  --query 'computeEnvironments[0].status' --output text --region us-west-2
```

## 5. Create Batch Job Queue

```bash
aws batch create-job-queue \
  --job-queue-name chromapipe-queue \
  --state ENABLED \
  --priority 1 \
  --compute-environment-order order=1,computeEnvironment=chromapipe-ce \
  --region us-west-2
```

## 6. Run the Pipeline

```bash
# Single chromosome
nextflow run main.nf -profile aws --chromosomes 21

# All 22 autosomes in parallel
nextflow run main.nf -profile aws --chromosomes 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22
```

## 7. View Results

```bash
aws s3 ls s3://chromapipe-data/results/ --region us-west-2
aws s3 cp s3://chromapipe-data/results/ ./results/ --recursive --region us-west-2
```

## Monitoring

```bash
# Job status
aws batch list-jobs --job-queue chromapipe-queue --region us-west-2

# CloudWatch logs
aws logs tail /aws/batch/job --follow --region us-west-2
```

## Cleanup

```bash
# Disable and delete job queue
aws batch update-job-queue --job-queue chromapipe-queue --state DISABLED --region us-west-2
sleep 5
aws batch delete-job-queue --job-queue chromapipe-queue --region us-west-2

# Disable and delete compute environment
aws batch update-compute-environment --compute-environment chromapipe-ce --state DISABLED --region us-west-2
sleep 10
aws batch delete-compute-environment --compute-environment chromapipe-ce --region us-west-2

# Clean up S3 work directory (keeps results)
aws s3 rm s3://chromapipe-data/work/ --recursive --region us-west-2
```

## Estimated Costs

| Run                       | On-Demand   | Spot        |
| ------------------------- | ----------- | ----------- |
| Single chromosome (chr21) | ~$0.02-0.05 | ~$0.01-0.02 |
| All 22 chromosomes        | ~$0.50-1.00 | ~$0.15-0.30 |
| Idle (min vCPUs = 0)      | $0.00       | $0.00       |

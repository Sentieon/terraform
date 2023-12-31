# Sentieon - Terraform
Terraform configuration files for the Sentieon software

## Introduction

[Terraform](https://www.terraform.io/) is an open-source infrastructure as code (IaC) tool for the provisioning and management of cloud infrastructure. This repository contains example terraform configuration files that can be used to quickly deploy the Sentieon software to your cloud infrastructure.

## Quick Start - Sentieon License server deployment to AWS

### Requirements

* The [Terraform CLI](https://developer.hashicorp.com/terraform/downloads)
* The [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* An AWS account and credentials with permission to provision resources inside the account
* A Sentieon license file for your FQDN, bound to port 8990 and placed in your s3 bucket

### Provision the license server

Use the terraform configuration files to provision the following infrastructure:
* Security groups for the Sentieon license server and any compute nodes
* A CloudWatch log group for the license server logs
* An IAM role and instance profile for the license server
  * Granting read access to the Sentieon software package and license file in AWS s3
  * Granting write access to the CloudWatch log group
* Starts a t3.nano ec2 instance to host the license server, using the IAM profile and security group
  * Using the latest Amazon Linux 2023 AMI for the region
  * Uses an encrypted root EBS disk with either an AWS-managed or (optionally) a customer-managed key
  * Has a user data script to do the following at startup, without direct user intervention:
    * Install, configure, and start the cloudwatch universal agent to push the license server logs to CloudWatch
    * Download the customer's license file from s3
    * Download and install the Sentieon software. Start the license server using the license file
* Create a private hosted zone with AWS Route 53
  * Create a Route53 record associating the FQDN with the private IP of the license server instance


```bash
git clone https://github.com/sentieon/terraform
cd terraform/aws_license-server

# Configure your AWS credentials
export AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>
export AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>

# Initialize the directory with Terraform
terraform init

# Provision the license server infrastructure
terraform apply \
  -var 'aws_region=<AWS_REGION>' \
  -var 'licsrvr_fqdn=<FQDN>' \
  -var 'license_s3_uri=s3://<S3_URI>'
```

The infrastructure should startup within a few minutes.

AWS will charge your account for deployed infrastructure including the ec2 instance, EBS disk, Route53 hosted zone. The deployment will also generate charges for DNS queries resolved by Route53.

### Cleanup

The provisioned infrastructure can be destroyed with the `terraform apply -destroy` command:
```bash
terraform apply -destroy \
  -var 'aws_region=<AWS_REGION>' \
  -var 'licsrvr_fqdn=<FQDN>' \
  -var 'license_s3_uri=s3://<S3_URI>'
```
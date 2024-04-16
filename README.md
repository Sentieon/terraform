# Sentieon - Terraform
Terraform configuration files for the Sentieon software

## Introduction

[Terraform](https://www.terraform.io/) is an open-source infrastructure as code (IaC) tool for the provisioning and management of cloud infrastructure. This repository contains example terraform configuration files that can be used to quickly deploy the Sentieon software to your cloud infrastructure.

## Quick Start - Sentieon License server deployment to Azure

### Requirements

* The [Terraform CLI](https://developer.hashicorp.com/terraform/downloads)
* The [Azure CLI]( https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* An Azure account and credentials with permission to provision resources inside the account

### Provision the license server

Use the terraform configuration files to provision the following infrastructure:

* An Azure Virtual Network. The default network configuration with the default subnet(s), internet gateway, and route table is assumed in this deployment guide.
* Security groups for the Sentieon license server.
* A (Standard_B1s) instance.

```bash
git clone https://github.com/sentieon/terraform
cd terraform/azure_license-server


# login into Azure using az cli
az login

# Initialize the directory with Terraform
terraform init  

# Provision the license server infrastructure
terraform apply \
  -var 'azure_region=<AZURE_REGION>' \
  -var 'resource_name=<RESOURCE_NAME>' \
  -var 'private_key_location=<KEY_LOCATION>'

# For example
# terraform apply \
#   -var 'azure_region=West US' \
#   -var 'resource_name=sentieon-licsrvr' \
#   -var 'private_key_location=azure_licsrvr_key.pem'
```

The infrastructure should startup within a few minutes and terraform will create a private key file at `KEY_LOCATION`. Additionally, terraform will output the public and private IP addresses of the VM to the terminal.

Azure will charge your account for deployed infrastructure including the VM instance, disk, public ip and virtual network.

### Install Sentieon and license file

Send your Sentieon support representative the private IP address of your instance and port 8990. They will send you back a Sentieon license file that can be used on the newly created VM.

Use the private key file and the instance's public IP to transfer the license file into the vm and ssh into the VM:
```bash
# Transfer the license file into the instance
scp -i <KEY_LOCATION> <SENTIEON_LICENSE_FILE> adminUser@<PUBLIC_IP>:~/

# Connect to the vm
ssh -i <KEY_LOCATION> adminUser@<PUBLIC_IP>
```

Download the Sentieon software to the VM and start the Sentieon license server:
```bash
# Download the Sentieon software package
curl -L <SENTIEON_URL.tar.gz> \
  | tar -zxf -

# Start the sentieon license server
sentieon-genomics-<VERSION>/bin/sentieon licsrvr --start -l licsrvr.log ~/<LICENSE_FILE>
```

### Cleanup

The provisioned infrastructure can be destroyed with the `terraform apply -destroy` command:
```bash
terraform apply -destroy \
  -var 'azure_region=<AZURE_REGION>' \
  -var 'resource_name=<RESOURCE_NAME>' \
  -var 'private_key_location=<KEY_LOCATION>'
```

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

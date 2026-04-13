variable "aws_region" {
  type        = string
  description = "AWS region for the license server deployment"
}

variable "licsrvr_fqdn" {
  type        = string
  description = "Fully qualified domain name for the license server"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.licsrvr_fqdn))
    error_message = "licsrvr_fqdn must be a valid fully qualified domain name"
  }
}

variable "license_s3_uri" {
  type        = string
  description = "S3 URI of the Sentieon license file (e.g. s3://bucket/path/file.lic)"

  validation {
    condition     = startswith(var.license_s3_uri, "s3://")
    error_message = "license_s3_uri must start with s3://"
  }
}

variable "kms_key" {
  type        = string
  description = "Optional KMS key ARN for EBS encryption. Uses AWS-managed key if null"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the deployment. Uses the default VPC if not specified"
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the license server instance. Required when vpc_id is specified"
  default     = null
}

variable "sentieon_version" {
  type        = string
  description = "Sentieon software version to install"
  default     = "202503.03"
}

locals {
  license_bucket_arn     = format("arn:aws:s3:::%s", split("/", var.license_s3_uri)[2])
  s3_uri_arr             = split("/", var.license_s3_uri)
  license_obj_arn        = format("arn:aws:s3:::%s", join("/", slice(local.s3_uri_arr, 2, length(local.s3_uri_arr))))
  licsrvr_log_group_name = "/sentieon/licsrvr/LicsrvrLog"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    dns = {
      source = "hashicorp/dns"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "sentieon-license-server"
      ManagedBy = "terraform"
    }
  }
}

# Find the IP of the master server
data "dns_a_record_set" "master" {
  host = "master.sentieon.com"
}

# Find the VPC
data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_vpc" "selected" {
  count = var.vpc_id != null ? 1 : 0
  id    = var.vpc_id
}

locals {
  vpc_id   = var.vpc_id != null ? data.aws_vpc.selected[0].id : data.aws_vpc.default[0].id
  vpc_cidr = var.vpc_id != null ? data.aws_vpc.selected[0].cidr_block : data.aws_vpc.default[0].cidr_block
}

# Find the AWS account ID
data "aws_caller_identity" "current" {}

## Configure the security group for the license server
# Create a security group
resource "aws_security_group" "sentieon_license_server" {
  name        = "sentieon_license_server"
  description = "Security groups for the Sentieon license server"
  vpc_id      = local.vpc_id
}

# Create a security group for the compute nodes
resource "aws_security_group" "sentieon_compute_nodes" {
  name        = "sentieon_compute"
  description = "Security groups for Sentieon compute nodes"
  vpc_id      = local.vpc_id
}

# Security group rules are definied in a separate file

# Cloudwatch log group for logs
data "aws_cloudwatch_log_groups" "existing_licsrvr" {
  log_group_name_prefix = local.licsrvr_log_group_name
}

resource "aws_cloudwatch_log_group" "licsrvr" {
  count             = contains(data.aws_cloudwatch_log_groups.existing_licsrvr.log_group_names, local.licsrvr_log_group_name) ? 0 : 1
  name              = local.licsrvr_log_group_name
  retention_in_days = 120
}

# IAM role for the license server
resource "aws_iam_role" "licsrvr" {
  name = "sentieon_licsrvr_role"

  # Allow policy to be assumed by ec2 instances
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  # s3 access to the license file in s3 and Sentieon software
  inline_policy {
    name = "s3_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["s3:Get*", "s3:List*", "s3-object-lambda:Get*", "s3-object-lambda:List*"]
          Effect = "Allow"
          Resource = [
            local.license_bucket_arn,
            local.license_obj_arn,
            "arn:aws:s3:::sentieon-release",
            format("arn:aws:s3:::sentieon-release/software/sentieon-genomics-%s.tar.gz", var.sentieon_version)
          ]
        },
      ]
    })
  }

  # access to write license server logs to cloudwatch
  inline_policy {
    name = "cloudwatch_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["logs:PutRetentionPolicy", "logs:CreateLogGroup", "logs:PutLogEvents", "logs:CreateLogStream"]
          Effect = "Allow"
          Resource = [
            format("arn:aws:logs:*:%v:log-group:%v", data.aws_caller_identity.current.account_id, local.licsrvr_log_group_name),
            format("arn:aws:logs:*:%v:log-group:%v:log-stream:*", data.aws_caller_identity.current.account_id, local.licsrvr_log_group_name)
          ]
        },
      ]
    })
  }
}

resource "aws_iam_instance_profile" "licsrvr" {
  name = "sentieon_licsrvr_profile"
  role = aws_iam_role.licsrvr.name
}

## Start the License server
# Find the latest Amazon Linux AMI
data "aws_ami" "al2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}

# Create the license server instance
resource "aws_instance" "sentieon_licsrvr" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.nano"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.sentieon_license_server.id]
  iam_instance_profile        = aws_iam_instance_profile.licsrvr.id
  user_data_replace_on_change = true

  tags = {
    Name = "sentieon-license-server"
  }

  root_block_device {
    encrypted  = true
    kms_key_id = var.kms_key
  }

  user_data = <<EOF
#!/usr/bin/bash -xv
yum update -y
yum install amazon-cloudwatch-agent -y
mkdir -p /opt/aws/amazon-cloudwatch-agent/bin
echo '{ "agent": { "run_as_user": "root" }, "logs": { "logs_collected": { "files": { "collect_list": [ { "file_path": "/opt/sentieon/licsrvr.log", "log_group_name": "${local.licsrvr_log_group_name}", "log_stream_name": "{instance_id}", "retention_in_days": 120 } ] } } } }' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
mkdir -p /opt/sentieon
cd /opt/sentieon
aws s3 cp 's3://sentieon-release/software/sentieon-genomics-${var.sentieon_version}.tar.gz' - | tar -zxf -
ln -s 'sentieon-genomics-${var.sentieon_version}' 'sentieon-genomics'
aws s3 cp "${var.license_s3_uri}" "./sentieon.lic"
i=0
while true; do
  if getent ahosts "${var.licsrvr_fqdn}"; then
    break
  fi
  i=$((i + 1))
  if [[ i -gt 300 ]]; then
    exit 1
  fi
  sleep 1
done
sentieon-genomics/bin/sentieon licsrvr --start --log licsrvr.log ./sentieon.lic
EOF
}

## Create a private hosted zone
# Create a hosted zone
resource "aws_route53_zone" "primary" {
  name = var.licsrvr_fqdn

  vpc {
    vpc_id     = local.vpc_id
    vpc_region = var.aws_region
  }
}

resource "aws_route53_record" "licsrvr_fqdn" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.licsrvr_fqdn
  type    = "A"
  ttl     = "300"
  records = [aws_instance.sentieon_licsrvr.private_ip]
}

output "license_server_private_ip" {
  value = aws_instance.sentieon_licsrvr.private_ip
}

output "license_server_instance_id" {
  value = aws_instance.sentieon_licsrvr.id
}

output "compute_security_group_id" {
  value       = aws_security_group.sentieon_compute_nodes.id
  description = "Attach this SG to compute nodes that need license server access"
}

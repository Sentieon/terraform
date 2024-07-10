variable "aws_region" {}
variable "licsrvr_fqdn" {}
variable "license_s3_uri" {}
variable "kms_key" {
  type    = string
  default = null
}
variable "sentieon_version" {
  type    = string
  default = "202308.03"
}

locals {
  license_bucket_arn = format("arn:aws:s3:::%s", split("/", var.license_s3_uri)[2])
  s3_uri_arr         = split("/", var.license_s3_uri)
  license_obj_arn    = format("arn:aws:s3:::%s", join("/", slice(local.s3_uri_arr, 2, length(local.s3_uri_arr))))
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    dns = {
      source = "hashicorp/dns"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

# Find the IP of the master server
data "dns_a_record_set" "master" {
  host = "master.sentieon.com"
}

# Find the default VPC
data "aws_vpc" "default" {
  default = true
}

# Find the AWS account ID
data "aws_caller_identity" "current" {}

## Configure the security group for the license server
# Create a security group
resource "aws_security_group" "sentieon_license_server" {
  name        = "sentieon_license_server"
  description = "Security groups for the Sentieon license server"
  vpc_id      = data.aws_vpc.default.id
}

# Create a security group for the compute nodes
resource "aws_security_group" "sentieon_compute_nodes" {
  name        = "sentieon_compute"
  description = "Security groups for Sentieon compute nodes"
  vpc_id      = data.aws_vpc.default.id
}

# Security group rules are definied in a separate file

# Cloudwatch log group for logs
resource "aws_cloudwatch_log_group" "licsrvr" {
  name = "/sentieon/licsrvr/LicsrvrLog"
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
            format("arn:aws:logs:*:%v:log-group:%v", data.aws_caller_identity.current.account_id, aws_cloudwatch_log_group.licsrvr.name),
            format("arn:aws:logs:*:%v:log-group:%v:log-stream:*", data.aws_caller_identity.current.account_id, aws_cloudwatch_log_group.licsrvr.name)
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
  vpc_security_group_ids      = [aws_security_group.sentieon_license_server.id]
  iam_instance_profile        = aws_iam_instance_profile.licsrvr.id
  user_data_replace_on_change = true

  root_block_device {
    encrypted  = true
    kms_key_id = var.kms_key
  }

  user_data = <<EOF
#!/usr/bin/bash -xv
yum update -y
yum install amazon-cloudwatch-agent -y
mkdir -p /opt/aws/amazon-cloudwatch-agent/bin
echo '{ "agent": { "run_as_user": "root" }, "logs": { "logs_collected": { "files": { "collect_list": [ { "file_path": "/opt/sentieon/licsrvr.log", "log_group_name": "${aws_cloudwatch_log_group.licsrvr.name}", "log_stream_name": "{instance_id}", "retention_in_days": 120 } ] } } } }' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
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
    vpc_id     = data.aws_vpc.default.id
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

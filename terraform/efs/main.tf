provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}


terraform {
  required_version = ">= 1.2.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  backend "s3" {

  }
}


resource "aws_efs_file_system" "ryedr_efs" {
  creation_token =  "${var.prefix}-${var.environment}"
  performance_mode = "generalPurpose"
  encrypted        = false

  tags = {
    Name = "${var.prefix}-${var.environment}"
    Application = "ryedr"
  }
  
}


resource "aws_efs_mount_target" "ryedr_efs_mount_target_az" {
  for_each = toset(data.aws_availability_zones.available.names)

  file_system_id = aws_efs_file_system.ryedr_efs.id
  subnet_id      = element(data.aws_subnets.private_subnets.ids, index(data.aws_availability_zones.available.names, each.key))

  security_groups = [aws_security_group.security_group.id]
}



resource "aws_security_group" "security_group" {
  name   = "${var.prefix}-${var.environment}-efs"
  vpc_id = data.aws_vpc.vpc.id
}

resource "aws_security_group_rule" "egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.security_group.id
}

resource "aws_security_group_rule" "ingress_rule1" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group.id
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  tags = {
    "IsPrivate" = "true"
  }
}

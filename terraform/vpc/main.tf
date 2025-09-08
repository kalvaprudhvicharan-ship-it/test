provider "aws" {
  region = var.aws_region
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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.12.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_flow_log           =  false
#   flow_log_destination_type = "s3"
#   flow_log_destination_arn  = "arn:aws:s3:::ryder-global-audit"

  enable_nat_gateway   = var.vpc_enable_nat_gateway
  enable_dns_hostnames = var.vpc_enable_dns_hostname
  enable_dns_support   = var.vpc_enable_dns_support

  tags = var.vpc_tags

  single_nat_gateway  = false
  reuse_nat_ips       = true
  external_nat_ip_ids = aws_eip.nat.*.id

  public_subnet_tags = merge(
    var.public_subnet_tags,
    {
      "IsPublic" = "true"
    }
  )

  private_subnet_tags = merge(
    var.private_subnet_tags,
    {
      "IsPrivate" = "true"
    }
  )

  # Required to satisfy AWS Security Hub rule
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}

resource "aws_eip" "nat" {
  count = 3
  lifecycle {
    prevent_destroy = false
  }
}





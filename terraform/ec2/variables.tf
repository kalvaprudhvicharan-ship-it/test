variable "prefix" {
    description = "Prefix of the resources"
    type = string
    default = "ryedr"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default = "ap-south-1"
}

variable "efs_dns_name" {
  description = "Dns of the efs"
  type = string
}


variable "env" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}


variable "app_port" {
  description = "Port your app is running on EC2 instances"
  type        = number
}

variable "ssl_cert_arn" {
  description = "ACM Certificate ARN for HTTPS listener"
  type        = string
}

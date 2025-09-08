variable "aws_region" {
  description = "AWS region"
  type        = string
  default     =  "ap-south-1"
}

variable "prefix" {
    description = "Prefix of the resources"
    type = string
    default = "ryedr"
}


variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_name" {
  description = "VPC Name to deploy into"
  type        = string
}



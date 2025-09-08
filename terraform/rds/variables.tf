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


variable "env" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_name" {
  description = "VPC Name to deploy into"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
}

variable "db_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

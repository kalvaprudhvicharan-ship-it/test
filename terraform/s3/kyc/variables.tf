# Required Inputs

variable "environment" {
  description = "Name of the environment to run on"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 Bucket"
  type        = string
}

# Optional Inputs

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-south-1"
}

variable "prefix" {
  description = "Prefix that we'll attach to our resources"
  type        = string
  default     = "ryedr"
}
variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "ryedr"
}

variable "env" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "github_connection_arn" {
  description = "CodeStar Connections ARN for GitHub"
  type        = string
}

variable "github_owner" {
  description = "GitHub owner/org"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch to build"
  type        = string
  default     = "main"
}

variable "ecr_repository_url" {
  description = "ECR repo URI to push image to (e.g., 123.dkr.ecr.ap-south-1.amazonaws.com/app)"
  type        = string
}



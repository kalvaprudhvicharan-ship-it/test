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

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.prefix}-${var.environment}-${var.s3_bucket_name}"

  tags = {
    Name        = "${var.prefix}-${var.environment}-${var.s3_bucket_name}"
    Environment = var.environment
  }
}



# Don't change, by default we should always block public access
resource "aws_s3_bucket_public_access_block" "s3_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.s3_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

}

# resource "aws_s3_bucket_website_configuration" "website" {
#   bucket = aws_s3_bucket.s3_bucket.id

#   index_document {
#     suffix = "index.html"
#   }

#   error_document {
#     key = "index.html"
#   }
# }
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


# Get public subnets in the VPC
data "aws_vpc" "vpc" {
    filter {
        name   = "tag:Name"
        values = [var.vpc_name]
    }
}


data "aws_subnets" "public_subnets" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.vpc.id]
    }
    tags = {
        "IsPublic" = "true"
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

# Security Group to allow PostgreSQL from anywhere (not safe for production)
resource "aws_security_group" "rds_sg" {
  name        = "${var.prefix}-${var.env}-rds-sg"
  description = "Allow PostgreSQL access from VPC only"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_subnets.private_subnets.ids]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB subnet group (public subnets used for public access)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.prefix}-${var.env}-rds-subnet-group"
  subnet_ids = data.aws_subnets.private_subnets.ids

  tags = {
    Name = "${var.prefix}-${var.env}-rds-subnet-group"
  }
}

data "aws_rds_engine_version" "postgres" {
  engine = "postgres"
  preferred_versions = [
    "16.4",
    "16.3",
    "16.2",
    "15.6",
    "15.5",
    "15.4",
  ]
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.prefix}-${var.env}-postgres-db"
  engine                  = "postgres"
  engine_version          = data.aws_rds_engine_version.postgres.version
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  storage_type            = "gp3"
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  publicly_accessible     =  false
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot     = true
  delete_automated_backups = true

  tags = {
    Name = "${var.prefix}-${var.env}-postgres-db"
  }
}

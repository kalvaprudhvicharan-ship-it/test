environment = "prod"

vpc_azs = ["aps1-az1", "aps1-az2", "aps1-az3"]
vpc_cidr = "10.2.0.0/18"
vpc_name = "ryedr-prod"
vpc_private_subnets = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
vpc_public_subnets = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]

vpc_tags = {
  Terraform   = "true"
  Environment = "prod"
}
environment = "dev"

vpc_azs = ["aps1-az1", "aps1-az2", "aps1-az3"]
vpc_cidr = "10.1.0.0/18"
vpc_name = "ryedr-dev"
vpc_private_subnets = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
vpc_public_subnets = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]

vpc_tags = {
  Terraform   = "true"
  Environment = "dev"
}
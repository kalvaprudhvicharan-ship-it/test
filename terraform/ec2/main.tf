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

resource "aws_security_group" "alb_sg" {
  name        = "${var.prefix}-${var.env}-alb-sg"
  description = "Allow HTTP and HTTPS"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.prefix}-${var.env}-ec2-sg"
  description = "Allow traffic from ALB"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  owners = ["amazon"]
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${var.prefix}-${var.env}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t4g.medium"
 # key_name      = "ryedr"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
amazon-linux-extras enable docker
yum install -y docker
systemctl start docker
systemctl enable docker
curl -sL https://rpm.nodesource.com/setup_16.x | bash -
yum install -y nodejs
docker rm -f ryedr-nginx || true
docker run -d --restart=always --name ryedr-nginx -p ${var.app_port}:80 nginx

# Install EFS/NFS utils and mount EFS
yum install -y amazon-efs-utils || yum install -y nfs-utils
mkdir -p /mnt/efs
echo "${var.efs_dns_name}:/ /mnt/efs nfs4 defaults,_netdev 0 0" >> /etc/fstab
mount -a || mount -t nfs4 "${var.efs_dns_name}:/" /mnt/efs

# Install CodeDeploy agent
yum install -y ruby
cd /home/ec2-user
curl -o codedeploy-install.sh https://aws-codedeploy-${var.aws_region}.s3.${var.aws_region}.amazonaws.com/latest/install
chmod +x codedeploy-install.sh
./codedeploy-install.sh auto
systemctl enable codedeploy-agent
systemctl start codedeploy-agent
EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role and instance profile for EC2 to pull from ECR and send CloudWatch logs
resource "aws_iam_role" "ec2_role" {
  name = "${var.prefix}-${var.env}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.prefix}-${var.env}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Allow ECR read-only (pull, auth token, image pulls)
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_autoscaling_group" "asg" {
  name_prefix          = "${var.prefix}-${var.env}-asg"
  desired_capacity     = 1
  min_size             = 1
  max_size             = 3
  vpc_zone_identifier  = data.aws_subnets.private_subnets.ids
  health_check_type    = "EC2"
  target_group_arns    = [aws_lb_target_group.app_tg.arn]
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.prefix}-${var.env}-ec2"
    propagate_at_launch = true
  }
}

resource "aws_lb" "app_alb" {
  name               = "${var.prefix}-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            =  data.aws_subnets.public_subnets.ids
}

resource "aws_lb_target_group" "app_tg" {
  name     = "${var.prefix}-${var.env}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc.id
  target_type = "instance"
  stickiness {
    enabled = true
    type= "lb_cookie"
    cookie_duration = 3600
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.app_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
# #  certificate_arn   = var.ssl_cert_arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
#}

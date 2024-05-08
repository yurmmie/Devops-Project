terraform {

  required_providers {

    aws = {

      source = "hashicorp/aws"

      version = "~> 4.16"

    }

  }

  required_version = ">= 1.2.0"

}

provider "aws" {

  region = var.region_name

}


resource "aws_vpc" "Yomi_VPC" {

  cidr_block = var.vpc_cidr

  tags = {

    Name = "yomiProjectVPC"

  }

}

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.Yomi_VPC.id

  tags = {

    Name = "yomiProjectigw"

  }

}

resource "aws_route_table" "publicRT" {

  vpc_id = aws_vpc.Yomi_VPC.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id

  }

  tags = {

    Name = "PublicRT"

  }

}

resource "aws_subnet" "project_public_subnet1" {

  vpc_id = aws_vpc.Yomi_VPC.id

  cidr_block = var.subnet1_cidr

  map_public_ip_on_launch = true

  availability_zone = var.az1

  tags = {

    Name = "yomiProjectSubnet1"

  }

}


resource "aws_subnet" "project_public_subnet2" {

  vpc_id = aws_vpc.Yomi_VPC.id

  cidr_block = var.subnet2_cidr

  map_public_ip_on_launch = true

  availability_zone = var.az2

  tags = {

    Name = "yomiProjectSubnet2"

  }

}

resource "aws_route_table_association" "public_subnet_association1" {

  subnet_id = aws_subnet.project_public_subnet1.id

  route_table_id = aws_route_table.publicRT.id

}

resource "aws_route_table_association" "public_subnet_association2" {

  subnet_id = aws_subnet.project_public_subnet2.id

  route_table_id = aws_route_table.publicRT.id

}

resource "aws_instance" "app_server" {

  ami = var.ami_id

  instance_type = var.instance_type

  subnet_id = aws_subnet.project_public_subnet1.id

  tags = {

    Nmae = "yomiTerraform_EC2"

  }

}


# Security Group for EC2

resource "aws_security_group" "EC2_SG" {

  vpc_id = aws_vpc.Yomi_VPC.id

  ingress {

    from_port = 22

    to_port = 22

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {

    from_port = 80

    to_port = 80

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {

    Name = "yomi_EC2_SG"

  }

}


# Security Group for ALB

resource "aws_security_group" "ALB_SG" {

  vpc_id = aws_vpc.Yomi_VPC.id

  ingress {

    from_port = 80

    to_port = 80

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {

    Name = "yomi_ALB_SG"

  }

}

# Security Group for RDS

resource "aws_security_group" "RDS_SG" {

  vpc_id = aws_vpc.Yomi_VPC.id

  ingress {

    from_port = 3306

    to_port = 3306

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {

    Name = "yomi_RDS_SG"

  }

}

# Launch Configuration

resource "aws_launch_configuration" "my_launch_config" {

  name = "my-launch-config"

  image_id = var.ami_id

  instance_type = var.instance_type

  security_groups = [aws_security_group.EC2_SG.id]

}


# Auto Scaling Group

resource "aws_autoscaling_group" "my_asg" {

  name = "my-asg"

  launch_configuration = aws_launch_configuration.my_launch_config.name

  min_size = 2

  max_size = 5

  desired_capacity = 2

  vpc_zone_identifier = [aws_subnet.project_public_subnet1.id, aws_subnet.project_public_subnet2.id]

  health_check_type = "EC2"

  health_check_grace_period = 300

}

# ALB Target Group

resource "aws_lb_target_group" "my_target_group" {

  name = "my-target-group"

  port = 80

  protocol = "HTTP"

  vpc_id = aws_vpc.Yomi_VPC.id

}

# ALB

resource "aws_lb" "my_alb" {

  name = "my-alb"

  internal = false

  load_balancer_type = "application"

  security_groups = [aws_security_group.ALB_SG.id]

  subnets = [aws_subnet.project_public_subnet1.id, aws_subnet.project_public_subnet2.id]

  enable_deletion_protection = false

}

# ALB Listener

resource "aws_lb_listener" "my_alb_listener" {

  load_balancer_arn = aws_lb.my_alb.arn

  port = 80

  protocol = "HTTP"

  default_action {

    type = "forward"

    target_group_arn = aws_lb_target_group.my_target_group.arn

  }

}

# S3 Bucket

resource "aws_s3_bucket" "my_bucket" {

  bucket = var.bucket_name

}


# IAM Role 

resource "aws_iam_role" "ec2_role" {

  name = "ec2-role"

  assume_role_policy = jsonencode({

    "Version" : "2012-10-17",

    "Statement" : [

      {

        "Effect" : "Allow",

        "Principal" : {

          "Service" : "ec2.amazonaws.com"

        },

        "Action" : "sts:AssumeRole"

      },

    ]

  })

}

# IAM Policy

resource "aws_iam_policy" "s3_full_access_policy" {

  name = "s3-full-access-policy"

  description = "Provides full access to S3 buckets"

  policy = jsonencode({

    "Version" : "2012-10-17",

    "Statement" : [

      {

        "Effect" : "Allow",

        "Action" : "s3:*",

        "Resource" : "*"

      },

    ]

  })

}

# Attach IAM Policy to IAM Role

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {

  role = aws_iam_role.ec2_role.name

  policy_arn = aws_iam_policy.s3_full_access_policy.arn

}

# RDS Subnet Group

resource "aws_db_subnet_group" "my_db_subnet_group" {

  name = "my-db-subnet-group"

  subnet_ids = [aws_subnet.project_public_subnet1.id, aws_subnet.project_public_subnet2.id]

}

resource "aws_db_instance" "default" {

  allocated_storage = 10

  db_name = "mydb"

  engine = "mysql"

  engine_version = "5.7"

  instance_class = "db.t3.micro"

  manage_master_user_password = true

  username = "admin"

  parameter_group_name = "default.mysql5.7"

  skip_final_snapshot = true

}
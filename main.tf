terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = "~> 4.16"
    }
  }

  required_version = ">=1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

# Creates VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr_block[0]

  tags = {
    Name = "my_vpc"
  }
}

# Creates Subnets within the VPC
resource "aws_subnet" "sbn" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_vpc.cidr_block, 2, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "crdb_demo-sbn-${var.availability_zones[count.index]}"
  }
}

# Creates security groups within the VPC
resource "aws_security_group" "tf_sg" {
  name        = "security group managed by terraform"
  description = "security group managed by terraform"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.outside_ip
  }

  ingress {
    description = "internode and load balancer connection"
    from_port = 26257
    to_port = 26257
    protocol = "tcp"
    self = true
  }

  ingress {
    description = "Local to cockroach db host connection"
    from_port = 26257
    to_port = 26257
    protocol = "tcp"
    cidr_blocks = var.outside_ip
  }

  ingress {
    description = "dbconsole"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = var.outside_ip
  }

  ingress {
    description = "Load balancer-health check communication"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = var.vpc_cidr_block
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "tf_sg"
  }
}

# Creates Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "crdb_demo_igw"
  }
}

# Creates Route Table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "crdb_demo_route"
  }
}

# Creates Routes
resource "aws_route" "igw_pub_route" {
  route_table_id         = aws_route_table.route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id

}

# Creates Route table association 
resource "aws_route_table_association" "sbn_association" {
    count = length(var.availability_zones)
    subnet_id = aws_subnet.sbn[count.index].id
    route_table_id = aws_route_table.route_table.id
}

# Creates the cockroach nodes, to change count of nodes change count variable
resource "aws_instance" "cockroachdb-node" {
  count                       = var.instance_count
  ami                         = "ami-026b57f3c383c2eec"
  instance_type               = "m6a.large"
  subnet_id                   = aws_subnet.sbn[count.index].id
  associate_public_ip_address = true
  security_groups             = [aws_security_group.tf_sg.id]
  key_name                    = "ssh-key"

  # root block device is instance store - not encrypted or backed up, if needed then use ebs volume
  root_block_device {
    volume_size = 150
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.instance_name}-${count.index + 1}"
  }
}

# Creates AWS load balancer 
resource "aws_lb" "my-nlb-demo" {
  name               = "my-nlb-demo"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in aws_subnet.sbn : subnet.id]

  tags = {
    Name = "my-nlb-demo"
  }
}

# Creates a target group 
resource "aws_lb_target_group" "my_target_group" {
  name        = "my-nlb-tg"
  target_type = "instance"
  port        = 26257
  protocol    = "TCP"
  vpc_id      = aws_vpc.my_vpc.id

  health_check {
    protocol = "HTTP"
    path = "/health?ready=1"
  }

  tags = {
    Name = "my_target_group"
  }
}

# network load balancer listener port forwarded 
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.my-nlb-demo.arn
  port              = "26257"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# target group attachment
resource "aws_lb_target_group_attachment" "tg_attach" {
    count = var.instance_count
    target_group_arn = aws_lb_target_group.my_target_group.arn
    target_id = aws_instance.cockroachdb-node[count.index].id
}
# Provider Configuration
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "eu-west-1"], var.aws_region)
    error_message = "Invalid AWS region specified."
  }
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0261755bbcb8c4a84"  # Ubuntu 20.04 LTS in us-east-1
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "ssh_ip" {
  description = "IP address allowed to SSH into the instance"
  type        = string
  default     = "0.0.0.0/0"  # Replace with your IP for production
}

# Locals for Common Tags
locals {
  common_tags = {
    Project     = "flask-app"
    Environment = "production"
  }
}

# Generate Private Key
resource "tls_private_key" "flask_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save Private Key Locally
resource "local_file" "private_key" {
  content         = tls_private_key.flask_key.private_key_pem
  filename        = "flask-app-key.pem"
  file_permission = "0600"  # Set proper permissions for the private key
}

# Create Key Pair
resource "aws_key_pair" "flask_key_pair" {
  key_name   = "flask-app-key"
  public_key = tls_private_key.flask_key.public_key_openssh
}

# VPC Configuration
resource "aws_vpc" "flask_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "flask-vpc"
  })
}

# Subnet Configuration
resource "aws_subnet" "flask_subnet" {
  vpc_id                  = aws_vpc.flask_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "flask-subnet"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "flask_igw" {
  vpc_id = aws_vpc.flask_vpc.id

  tags = merge(local.common_tags, {
    Name = "flask-igw"
  })
}

# Route Table
resource "aws_route_table" "flask_rt" {
  vpc_id = aws_vpc.flask_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.flask_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "flask-rt"
  })
}

# Route Table Association
resource "aws_route_table_association" "flask_rta" {
  subnet_id      = aws_subnet.flask_subnet.id
  route_table_id = aws_route_table.flask_rt.id
}

# Security Group
resource "aws_security_group" "flask_sg" {
  name        = "flask-sg"
  description = "Security group for Flask application"
  vpc_id      = aws_vpc.flask_vpc.id

  tags = merge(local.common_tags, {
    Name = "flask-sg"
  })
}

# Security Group Rules
resource "aws_security_group_rule" "http_access" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.flask_sg.id
  description       = "HTTP access"
}

resource "aws_security_group_rule" "flask_app_access" {
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.flask_sg.id
  description       = "Flask app access"
}

resource "aws_security_group_rule" "ssh_access" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.ssh_ip]
  security_group_id = aws_security_group.flask_sg.id
  description       = "SSH access"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.flask_sg.id
  description       = "Allow all outbound traffic"
}

# EC2 Instance
resource "aws_instance" "flask_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.flask_subnet.id

  vpc_security_group_ids = [aws_security_group.flask_sg.id]
  key_name               = aws_key_pair.flask_key_pair.key_name

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = templatefile("user_data.sh", {
    ssh_public_key = tls_private_key.flask_key.public_key_openssh
  })

  tags = merge(local.common_tags, {
    Name = "flask-server"
  })
}

# Outputs
output "public_ip" {
  value = aws_instance.flask_server.public_ip
}

output "public_dns" {
  value = aws_instance.flask_server.public_dns
}

output "ssh_command" {
  value = "ssh -i flask-app-key.pem ubuntu@${aws_instance.flask_server.public_ip}"
}
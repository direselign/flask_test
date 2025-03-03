terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project     = "flask-app"
    Environment = var.environment
  }
  name_prefix = "flask-${var.environment}"
}

# Create SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "ec2-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Save private key to file
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/ec2-key.pem"
  file_permission = "0400"
}

# Create EC2 instance
resource "aws_instance" "flask_app" {
  ami           = "ami-0261755bbcb8c4a84"  # Amazon Linux 2023 AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name

  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.flask_app.id]
  associate_public_ip_address = true

  user_data = templatefile("user_data.sh", {
    ssh_public_key = tls_private_key.ssh_key.public_key_openssh
    aws_region     = var.aws_region
    deployment_time = timestamp()
  })

  # Wait for instance to be ready
  user_data_replace_on_change = true

  # Add root volume configuration
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "flask-app-server"
  }
}

# Security group for Flask app
resource "aws_security_group" "flask_app" {
  name        = "flask-app-sg"
  description = "Security group for Flask application"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-app-sg"
  }
}

# Create Route 53 zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Create A record for the domain
resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [aws_instance.flask_app.public_ip]
}

# Create www subdomain record
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.flask_app.public_ip]
}
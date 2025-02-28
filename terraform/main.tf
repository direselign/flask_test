# Provider Configuration
provider "aws" {
  region = var.aws_region
}

# Locals for Common Tags
locals {
  common_tags = {
    Project     = "crs-app"
    Environment = "production"
  }
}

# Generate Private Key
resource "tls_private_key" "crs_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save Private Key Locally
resource "local_file" "private_key" {
  content         = tls_private_key.crs_key.private_key_pem
  filename        = "crs-app-key.pem"
  file_permission = "0600"  # Set proper permissions for the private key
}

# Create Key Pair
resource "aws_key_pair" "crs_key_pair" {
  key_name   = "crs-app-key"
  public_key = tls_private_key.crs_key.public_key_openssh
} 

# EC2 Instance
resource "aws_instance" "crs_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.crs_subnet.id
  iam_instance_profile = aws_iam_instance_profile.crs_profile.name

  vpc_security_group_ids = [aws_security_group.crs_sg.id]
  key_name               = aws_key_pair.crs_key_pair.key_name

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = templatefile("user_data.sh", {
    ssh_public_key = tls_private_key.crs_key.public_key_openssh
    aws_region     = var.aws_region
    deployment_time = timestamp()
  })

  tags = merge(local.common_tags, {
    Name = "crs-server"
    DeploymentTime = timestamp()
  })
}

# RDS Subnet Group
resource "aws_db_subnet_group" "crs_db_subnet" {
  name       = "crs-db-subnet"
  subnet_ids = [aws_subnet.crs_subnet.id, aws_subnet.crs_subnet_2.id]

  tags = merge(local.common_tags, {
    Name = "crs-db-subnet"
  })
}

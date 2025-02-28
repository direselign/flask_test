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

resource "aws_security_group_rule" "memcached_access" {
  type              = "ingress"
  from_port         = 11211
  to_port           = 11211
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.flask_sg.id
  description       = "Memcached access from EC2"
}

# EC2 Instance
resource "aws_instance" "flask_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.flask_subnet.id
  iam_instance_profile = aws_iam_instance_profile.flask_profile.name

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
    aws_region     = var.aws_region
    deployment_time = timestamp()
  })

  tags = merge(local.common_tags, {
    Name = "flask-server"
    DeploymentTime = timestamp()
  })
}

# RDS Subnet Group
resource "aws_db_subnet_group" "flask_db_subnet" {
  name       = "flask-db-subnet"
  subnet_ids = [aws_subnet.flask_subnet.id, aws_subnet.flask_subnet_2.id]

  tags = merge(local.common_tags, {
    Name = "flask-db-subnet"
  })
}

# Create another subnet in a different AZ (required for RDS)
resource "aws_subnet" "flask_subnet_2" {
  vpc_id                  = aws_vpc.flask_vpc.id
  cidr_block             = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "flask-subnet-2"
  })
}

# RDS Security Group
resource "aws_security_group" "flask_db_sg" {
  name        = "flask-db-sg"
  description = "Security group for Flask database"
  vpc_id      = aws_vpc.flask_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.flask_sg.id]
  }

  tags = merge(local.common_tags, {
    Name = "flask-db-sg"
  })
}

# Generate random DB password
resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# RDS Instance
resource "aws_db_instance" "flask_db" {
  identifier           = "flask-db"
  engine              = "postgres"
  engine_version      = "15.12"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  storage_type        = "gp2"
  
  db_name             = data.aws_ssm_parameter.db_name.value
  username           = data.aws_ssm_parameter.db_username.value
  password           = data.aws_ssm_parameter.db_password.value

  vpc_security_group_ids = [aws_security_group.flask_db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.flask_db_subnet.name

  skip_final_snapshot    = true

  tags = merge(local.common_tags, {
    Name = "flask-db"
  })
}

# Generate random secret key for Flask
resource "random_password" "flask_secret" {
  length  = 32
  special = true
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

# Output DB connection info
output "db_endpoint" {
  value = aws_db_instance.flask_db.endpoint
}

# Output DB password (remove in production)
output "db_password" {
  value     = data.aws_ssm_parameter.db_password.value
  sensitive = true
}

# Output Flask secret key (remove in production)
output "flask_secret_key" {
  value     = data.aws_ssm_parameter.flask_secret_key.value
  sensitive = true
}

# Output DB host (parsed from endpoint)
output "db_host" {
  value = split(":", aws_db_instance.flask_db.endpoint)[0]
}

# Output DB port
output "db_port" {
  value = "5432"
}

# Output DB name
# output "db_name" {
#   value = aws_db_instance.flask_db.db_name
# }

# Output DB username
# output "db_username" {
#   value = aws_db_instance.flask_db.username
# }

# Fetch existing SSM parameters
data "aws_ssm_parameter" "db_username" {
  name = "/flask-app/db/username"
}

data "aws_ssm_parameter" "db_password" {
  name        = "/flask-app/db/password"
  with_decryption = true
}

data "aws_ssm_parameter" "db_host" {
  name = "/flask-app/db/host"
}

data "aws_ssm_parameter" "db_port" {
  name = "/flask-app/db/port"
}

data "aws_ssm_parameter" "db_name" {
  name = "/flask-app/db/name"
}

data "aws_ssm_parameter" "flask_secret_key" {
  name        = "/flask-app/secret-key"
  with_decryption = true
}

# IAM role for EC2 instance
resource "aws_iam_role" "flask_role" {
  name = "flask-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for accessing SSM parameters
resource "aws_iam_role_policy" "flask_ssm_policy" {
  name = "flask-app-ssm-policy"
  role = aws_iam_role.flask_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/flask-app/*"
        ]
      }
    ]
  })
}

# IAM policy for CloudWatch Logs
resource "aws_iam_role_policy" "flask_cloudwatch_policy" {
  name = "flask-app-cloudwatch-policy"
  role = aws_iam_role.flask_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/flask-app/*"
        ]
      }
    ]
  })
}

# IAM policy for SES
resource "aws_iam_role_policy" "flask_ses_policy" {
  name = "flask-app-ses-policy"
  role = aws_iam_role.flask_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "flask_profile" {
  name = "flask-app-profile"
  role = aws_iam_role.flask_role.name
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
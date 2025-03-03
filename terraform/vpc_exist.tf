# Data source to fetch existing VPC
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["crs-vpc"]  # Replace with your existing VPC name
  }
}

# Data source to fetch existing subnets
data "aws_subnet" "existing_subnet_1" {
  filter {
    name   = "tag:Name"
    values = ["crs-subnet"]  # Replace with your existing subnet name
  }
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

data "aws_subnet" "existing_subnet_2" {
  filter {
    name   = "tag:Name"
    values = ["crs-subnet-2"]  # Replace with your existing subnet name
  }
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Data source to fetch existing internet gateway
data "aws_internet_gateway" "existing" {
  filter {
    name   = "tag:Name"
    values = ["crs-igw"]  # Replace with your existing IGW name
  }
  
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Data source to fetch existing route table
data "aws_route_table" "existing" {
  filter {
    name   = "tag:Name"
    values = ["crs-rt"]  # Replace with your existing route table name
  }
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Output the existing resource IDs for reference
output "vpc_id" {
  value = data.aws_vpc.existing.id
  description = "ID of the existing VPC"
}

output "subnet_1_id" {
  value = data.aws_subnet.existing_subnet_1.id
  description = "ID of the first existing subnet"
}

output "subnet_2_id" {
  value = data.aws_subnet.existing_subnet_2.id
  description = "ID of the second existing subnet"
}

output "internet_gateway_id" {
  value = data.aws_internet_gateway.existing.id
  description = "ID of the existing Internet Gateway"
}

output "route_table_id" {
  value = data.aws_route_table.existing.id
  description = "ID of the existing Route Table"
}

# Variables for customization
variable "vpc_name" {
  description = "Name tag of the existing VPC"
  type        = string
  default     = "crs-vpc"
}

variable "subnet_1_name" {
  description = "Name tag of the first existing subnet"
  type        = string
  default     = "crs-subnet"
}

variable "subnet_2_name" {
  description = "Name tag of the second existing subnet"
  type        = string
  default     = "crs-subnet-2"
}

variable "igw_name" {
  description = "Name tag of the existing Internet Gateway"
  type        = string
  default     = "crs-igw"
}

variable "route_table_name" {
  description = "Name tag of the existing Route Table"
  type        = string
  default     = "crs-rt"
} 
# VPC Configuration
resource "aws_vpc" "crs_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "crs-vpc"
  })
}

# Subnet Configuration
resource "aws_subnet" "crs_subnet" {
  vpc_id                  = aws_vpc.crs_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "crs-subnet"
  })
}

# Create another subnet in a different AZ (required for RDS)
resource "aws_subnet" "crs_subnet_2" {
  vpc_id                  = aws_vpc.crs_vpc.id
  cidr_block             = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "crs-subnet-2"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "crs_igw" {
  vpc_id = aws_vpc.crs_vpc.id

  tags = merge(local.common_tags, {
    Name = "crs-igw"
  })
}

# Route Table
resource "aws_route_table" "crs_rt" {
  vpc_id = aws_vpc.crs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.crs_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "crs-rt"
  })
}

# Route Table Association
resource "aws_route_table_association" "crs_rta" {
  subnet_id      = aws_subnet.crs_subnet.id
  route_table_id = aws_route_table.crs_rt.id
} 
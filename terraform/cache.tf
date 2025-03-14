resource "aws_elasticache_cluster" "memcache" {
  cluster_id           = "flask-cache"
  engine              = "memcached"
  node_type           = "cache.t3.micro"  # Free tier eligible
  num_cache_nodes     = 1
  port                = 11211
  parameter_group_name = aws_elasticache_parameter_group.memcache.name
  security_group_ids  = [aws_security_group.flask_sg.id]  # Use the EC2 security group
  subnet_group_name   = aws_elasticache_subnet_group.memcache.name
}

resource "aws_elasticache_subnet_group" "memcache" {
  name       = "flask-cache-subnet"
  subnet_ids = [aws_subnet.flask_subnet.id, aws_subnet.flask_subnet_2.id]  # Using the same subnets as RDS

  tags = {
    Name = "flask-cache-subnet"
  }
}

resource "aws_elasticache_parameter_group" "memcache" {
  family = "memcached1.6"
  name   = "flask-cache-params"

  parameter {
    name  = "max_item_size"
    value = "10485760"  # 10MB
  }
}

resource "aws_security_group" "memcache" {
  name        = "flask-memcache-sg"
  description = "Security group for Memcached cluster"
  vpc_id      = aws_vpc.flask_vpc.id 

  ingress {
    from_port   = 11211
    to_port     = 11211
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Adjust this based on your VPC CIDR
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-memcache-sg"
  }
}

output "memcache_endpoint" {
  value = aws_elasticache_cluster.memcache.cluster_address
}

output "memcache_port" {
  value = aws_elasticache_cluster.memcache.port
} 
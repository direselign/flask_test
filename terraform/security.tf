# EC2 Security Group
resource "aws_security_group" "crs_sg" {
  name        = "crs-sg"
  description = "Security group for crs application"
  vpc_id      = aws_vpc.crs_vpc.id

  tags = merge(local.common_tags, {
    Name = "crs-sg"
  })
}

# EC2 Security Group Rules
resource "aws_security_group_rule" "http_access" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.crs_sg.id
  description       = "HTTP access"
}

resource "aws_security_group_rule" "crs_app_access" {
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.crs_sg.id
  description       = "crs app access"
}

resource "aws_security_group_rule" "ssh_access" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.ssh_ip]
  security_group_id = aws_security_group.crs_sg.id
  description       = "SSH access"
}

resource "aws_security_group_rule" "memcached_access" {
  type              = "ingress"
  from_port         = 11211
  to_port           = 11211
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.crs_sg.id
  description       = "Memcached access from EC2"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.crs_sg.id
  description       = "Allow all outbound traffic"
}

# RDS Security Group
resource "aws_security_group" "crs_db_sg" {
  name        = "${local.name_prefix}-db-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.crs_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.crs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

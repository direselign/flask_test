# Generate random DB password
resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# RDS Instance
resource "aws_db_instance" "crs_db" {
  identifier           = "crs-db"
  engine              = "postgres"
  engine_version      = "15.12"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  storage_type        = "gp2"
  
  db_name             = data.aws_ssm_parameter.db_name.value
  username           = data.aws_ssm_parameter.db_username.value
  password           = data.aws_ssm_parameter.db_password.value

  vpc_security_group_ids = [aws_security_group.crs_db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.crs_db_subnet.name

  skip_final_snapshot    = true

  tags = merge(local.common_tags, {
    Name = "crs-db"
  })
}

# Generate random secret key for crs
resource "random_password" "crs_secret" {
  length  = 32
  special = true
}
# Fetch existing SSM parameters
data "aws_ssm_parameter" "db_username" {
  name = "/crs-app/db/username"
}

data "aws_ssm_parameter" "db_password" {
  name        = "/crs-app/db/password"
  with_decryption = true
}

data "aws_ssm_parameter" "db_host" {
  name = "/crs-app/db/host"
}

data "aws_ssm_parameter" "db_port" {
  name = "/crs-app/db/port"
}

data "aws_ssm_parameter" "db_name" {
  name = "/crs-app/db/name"
}

data "aws_ssm_parameter" "crs_secret_key" {
  name        = "/crs-app/secret-key"
  with_decryption = true
}

# Get current AWS account ID
data "aws_caller_identity" "current" {} 
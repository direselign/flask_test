
# Outputs
output "public_ip" {
  value = aws_instance.crs_server.public_ip
}

output "public_dns" {
  value = aws_instance.crs_server.public_dns
}

output "ssh_command" {
  value = "ssh -i crs-app-key.pem ubuntu@${aws_instance.crs_server.public_ip}"
}

# Output DB connection info
output "db_endpoint" {
  value = aws_db_instance.crs_db.endpoint
}

# Output DB password (remove in production)
output "db_password" {
  value     = data.aws_ssm_parameter.db_password.value
  sensitive = true
}

# Output crs secret key (remove in production)
output "crs_secret_key" {
  value     = data.aws_ssm_parameter.crs_secret_key.value
  sensitive = true
}

# Output DB host (parsed from endpoint)
output "db_host" {
  value = split(":", aws_db_instance.crs_db.endpoint)[0]
}

# Output DB port
output "db_port" {
  value = "5432"
}
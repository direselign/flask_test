output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.flask_app.public_ip
}

output "application_url" {
  description = "The URL to access the Flask application (via Nginx)"
  value       = "http://${aws_instance.flask_app.public_ip}"
}

output "domain_name" {
  description = "The domain name for the application"
  value       = var.domain_name
}

output "domain_url" {
  description = "The URL to access the Flask application via domain"
  value       = "http://${var.domain_name}"
}

output "www_domain_url" {
  description = "The URL to access the Flask application via www subdomain"
  value       = "http://www.${var.domain_name}"
}

output "nameservers" {
  description = "The nameservers for the domain"
  value       = aws_route53_zone.main.name_servers
}

output "ssh_command" {
  description = "The SSH command to connect to the instance"
  value       = "ssh -i ec2-key.pem ubuntu@${aws_instance.flask_app.public_ip}"
} 
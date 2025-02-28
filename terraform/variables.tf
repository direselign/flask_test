variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "eu-west-1"], var.aws_region)
    error_message = "Invalid AWS region specified."
  }
}

variable "environment" {
  type    = string
  default = "dev"
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


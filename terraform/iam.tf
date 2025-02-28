# IAM role for EC2 instance
resource "aws_iam_role" "crs_role" {
  name = "crs-app-role"

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
resource "aws_iam_role_policy" "crs_ssm_policy" {
  name = "crs-app-ssm-policy"
  role = aws_iam_role.crs_role.id

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
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/crs-app/*"
        ]
      }
    ]
  })
}

# IAM policy for CloudWatch Logs
resource "aws_iam_role_policy" "crs_cloudwatch_policy" {
  name = "crs-app-cloudwatch-policy"
  role = aws_iam_role.crs_role.id

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
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/crs-app/*"
        ]
      }
    ]
  })
}

# IAM policy for SES
resource "aws_iam_role_policy" "crs_ses_policy" {
  name = "crs-app-ses-policy"
  role = aws_iam_role.crs_role.id

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
resource "aws_iam_instance_profile" "crs_profile" {
  name = "crs-app-profile"
  role = aws_iam_role.crs_role.name
} 
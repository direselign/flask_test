# IAM role for EC2 instance
resource "aws_iam_role" "crs_role" {
  name = "${local.name_prefix}-role"

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
data "aws_iam_policy_document" "ssm_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/crs-app/*"
    ]
  }
}

resource "aws_iam_policy" "ssm_access" {
  name        = "${local.name_prefix}-ssm-policy"
  description = "Policy for accessing SSM parameters"
  policy      = data.aws_iam_policy_document.ssm_policy.json
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.crs_role.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

# IAM policy for CloudWatch Logs
resource "aws_iam_role_policy" "crs_cloudwatch_policy" {
  name = "${local.name_prefix}-cloudwatch-policy"
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
  name = "${local.name_prefix}-ses-policy"
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
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.crs_role.name
} 
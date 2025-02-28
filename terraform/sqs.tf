# Create SQS queue
resource "aws_sqs_queue" "flask_app_queue" {
  name                      = "flask-app-queue"
  delay_seconds             = 0
  max_message_size         = 262144
  message_retention_seconds = 345600 # 4 days
  receive_wait_time_seconds = 0
  visibility_timeout_seconds = 30

  tags = {
    Environment = var.environment
    Project     = "flask-app"
  }
}

# Create SQS queue policy
resource "aws_sqs_queue_policy" "flask_app_queue_policy" {
  queue_url = aws_sqs_queue.flask_app_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.flask_role.arn
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.flask_app_queue.arn
      }
    ]
  })
}

# Add SQS permissions to EC2 IAM role
resource "aws_iam_role_policy_attachment" "ec2_sqs_policy" {
  role       = aws_iam_role.flask_role.name
  policy_arn = aws_iam_policy.sqs_policy.arn
}

# Create SQS IAM policy
resource "aws_iam_policy" "sqs_policy" {
  name        = "flask-app-sqs-policy"
  description = "Policy for Flask app to interact with SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.flask_app_queue.arn
      }
    ]
  })
}

# Output the queue URL and ARN
output "sqs_queue_url" {
  value = aws_sqs_queue.flask_app_queue.url
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.flask_app_queue.arn
}
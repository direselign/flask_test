# Create SQS queue
resource "aws_sqs_queue" "main_queue" {
  name                      = "${local.name_prefix}-queue"
  delay_seconds             = 0
  max_message_size         = 262144
  message_retention_seconds = 345600 # 4 days
  receive_wait_time_seconds = 0
  visibility_timeout_seconds = 30

  tags = local.common_tags
}

# Create SQS queue policy
resource "aws_sqs_queue_policy" "main_queue_policy" {
  queue_url = aws_sqs_queue.main_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.account_id
        }
        Action = "sqs:*"
        Resource = aws_sqs_queue.main_queue.arn
      }
    ]
  })
}

# Create SQS queue
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name_prefix}-dlq"
  delay_seconds             = 0
  max_message_size         = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 0

  tags = local.common_tags
}

# Create SQS queue policy
resource "aws_sqs_queue_policy" "dlq_policy" {
  queue_url = aws_sqs_queue.dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.account_id
        }
        Action = "sqs:*"
        Resource = aws_sqs_queue.dlq.arn
      }
    ]
  })
}

# Add SQS permissions to EC2 IAM role
resource "aws_iam_role_policy_attachment" "sqs_policy_attachment" {
  role       = aws_iam_role.crs_role.name
  policy_arn = aws_iam_policy.sqs_policy.arn
}

# Create SQS IAM policy
resource "aws_iam_policy" "sqs_policy" {
  name        = "${local.name_prefix}-sqs-policy"
  description = "Policy for SQS access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.main_queue.arn,
          aws_sqs_queue.dlq.arn
        ]
      }
    ]
  })
}

# Output the queue URL and ARN
output "sqs_queue_url" {
  value = aws_sqs_queue.main_queue.url
}

output "sqs_dlq_url" {
  value = aws_sqs_queue.dlq.url
}
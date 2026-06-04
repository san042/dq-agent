# -----------------------------------
# DQ Agent — Terraform Security Layer
# -----------------------------------
# Security: Bucket policy, KMS encryption, & least-privilege IAM
# -----------------------------------

# KMS Key for S3 Data Lake encryption at rest
resource "aws_kms_key" "s3_encryption" {
  description             = var.kms_key_description
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# KMS Key Policy — Allow ONLY the Snowflake & QuickSight roles
resource "aws_kms_key_policy" "s3_encryption_policy" {
  key_id = aws_kms_key.s3_encryption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAdminAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSnowflakeAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.snowflake_s3_access.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowQuickSightAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.quicksight_s3_access.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# Security Group for VPC Endpoint (optional — uncomment if using VPC endpoints)
# resource "aws_security_group" "s3_vpc_endpoint" {
#   name_prefix = "s3-vpc-endpoint"
#   description = "Security group for S3 VPC Endpoint"
#   vpc_id      = var.vpc_id

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["10.0.0.0/16"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Project     = var.project_name
#     Environment = var.environment
#   }
# }

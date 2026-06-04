terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "dqm-terraform-state-ap-south"
    key     = "dqm/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}

# -----------------------------------
# AWS Provider (uses ~/.aws/config + ~/.aws/credentials)
# Region: ap-south-1 (detected from AWS CLI profile)
# Credentials: Profile [default] — autoloed from ~/.aws/credentials
# -----------------------------------
# -----------------------------------
# AWS Provider
# -----------------------------------
provider "aws" {
  profile = "default"
  region  = "ap-south-1"
}

# S3 Data Lake
# -----------------------------------
# Snowflake Storage Integration IAM Resource
resource "aws_iam_role" "snowflake_s3_access" {
  name = "snowflake-s3-access"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::238027390146:user/a86r1000-s"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = {
    Project     = "DQ-Agent"
    Environment = "production"
  }
}

# S3 Bucket Policy (Snowflake + QuickSight)
resource "aws_s3_bucket_policy" "dq_agent_lake" {
  bucket = aws_s3_bucket.dq_agent_lake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SnowflakeS3Access"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.snowflake_s3_access.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dq_agent_lake.arn,
          "${aws_s3_bucket.dq_agent_lake.arn}/*"
        ]
      },
      {
        Sid    = "QuickSightS3Access"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.quicksight_s3_access.arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dq_agent_lake.arn,
          "${aws_s3_bucket.dq_agent_lake.arn}/*"
        ]
      }
    ]
  })
}
# -----------------------------------
# QuickSight Access Role
# -----------------------------------
resource "aws_iam_role" "quicksight_s3_access" {
  name = "quicksight-s3-access"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = "DQ-Agent"
    Environment = "production"
  }
}

# -----------------------------------
# DQ Agent — Terraform S3 + IAM Resources
# -----------------------------------
# S3 buckets + IAM roles managed by Terraform
# -----------------------------------

# -----------------------------------
# S3 Data Lake Bucket (/landing, /processed, /logs)
# -----------------------------------
resource "aws_s3_bucket" "dq_agent_lake" {
  bucket = "${var.bucket_name_prefix}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket Lifecycle Policy — Transition & expiry
resource "aws_s3_bucket_lifecycle_configuration" "dq_agent_lake" {
  bucket = aws_s3_bucket.dq_agent_lake.id

  rule {
    id = "transition-to-glacier"
    filter {}
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "dq_agent_lake" {
  bucket = aws_s3_bucket.dq_agent_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-Side Encryption (KMS)
resource "aws_s3_bucket_server_side_encryption_configuration" "dq_agent_lake" {
  bucket = aws_s3_bucket.dq_agent_lake.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "dq_agent_lake" {
  bucket = aws_s3_bucket.dq_agent_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------
# S3 Folder Structure
# -----------------------------------
resource "aws_s3_object" "landing_folder" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "landing/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "processed_folder" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "processed/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "logs_folder" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "logs/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "landing_nyc_taxi" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "landing/nyc_taxi/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "landing_air_quality" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "landing/air_quality/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "landing_churn" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "landing/churn/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "processed_nyc_taxi" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "processed/nyc_taxi/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "processed_air_quality" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "processed/air_quality/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "processed_churn" {
  bucket       = aws_s3_bucket.dq_agent_lake.id
  key          = "processed/churn/"
  content_type = "application/x-directory"
}
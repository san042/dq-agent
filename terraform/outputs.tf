# -----------------------------------
# DQ Agent — Terraform Outputs
# -----------------------------------
# Outputs for Snowflake & QuickSight configuration
# -----------------------------------

output "s3_bucket_arn" {
  description = "ARN of the S3 Data Lake bucket"
  value       = aws_s3_bucket.dq_agent_lake.arn
}

output "s3_bucket_id" {
  description = "ID of the S3 Data Lake bucket"
  value       = aws_s3_bucket.dq_agent_lake.id
}

output "s3_bucket_region" {
  description = "Region of the S3 Data Lake bucket"
  value       = var.aws_region
}

output "snowflake_s3_access_role_arn" {
  description = "ARN of the IAM Role for Snowflake Snowpipe S3 access"
  value       = aws_iam_role.snowflake_s3_access.arn
}

output "snowflake_s3_access_role_name" {
  description = "Name of the IAM Role for Snowflake Snowpipe S3 access"
  value       = aws_iam_role.snowflake_s3_access.name
}

output "quicksight_s3_access_role_arn" {
  description = "ARN of the IAM Role for QuickSight service S3 access"
  value       = aws_iam_role.quicksight_s3_access.arn
}

output "quicksight_s3_access_role_name" {
  description = "Name of the IAM Role for QuickSight service S3 access"
  value       = aws_iam_role.quicksight_s3_access.name
}

output "storage_integration_name" {
  description = "Snowflake Storage Integration name for S3 connectivity"
  value       = var.storage_integration_name
}

output "kms_key_arn" {
  description = "ARN of the KMS encryption key used for S3 objects"
  value       = aws_kms_key.s3_encryption.arn
}

output "kms_key_id" {
  description = "ID of the KMS encryption key used for S3 objects"
  value       = aws_kms_key.s3_encryption.id
}

output "snowflake_external_id" {
  description = "External ID to provide to Snowflake for secure IAM role assumption"
  value       = var.external_id
}
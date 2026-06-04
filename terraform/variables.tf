# -----------------------------------
# DQ Agent — Terraform Variables
# -----------------------------------
# All values are derived from ~/.aws/config + ~/.aws/credentials
# No hardcoded credentials or region — region detected from AWS CLI profile.
# -----------------------------------

# General / Naming
variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "DQ-Agent"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "production"
}

# AWS Settings (auto-detected, not hardcoded)
variable "aws_region" {
  description = "AWS Region (from ~/.aws/config)"
  type        = string
  default     = "ap-south-1"
}

variable "aws_account_id" {
  description = "AWS Account ID (from terraform.tfvars)"
  type        = string
}

# S3 Bucket Configuration
variable "bucket_name_prefix" {
  description = "S3 bucket name prefix"
  type        = string
  default     = "dq-agent-datalake"
}

variable "bucket_lifecycle_days" {
  description = "Days to retain objects in S3 before transition/deletion"
  type        = number
  default     = 90
}

# Snowflake Configuration
variable "external_id" {
  description = "External ID for Snowflake ↔ IAM role assumption (exchanged with Snowflake)"
  type        = string
  default     = "DQ-Agent-External-ID"
}

variable "storage_integration_name" {
  description = "Snowflake STORAGE_INTEGRATION name (must match SF config)"
  type        = string
  default     = "dq_agent_s3_storage_int"
}

# KMS
variable "kms_key_description" {
  description = "Description for the S3 encryption KMS key"
  type        = string
  default     = "KMS key for DQ-Agent S3 Data Lake encryption at rest"
}

variable "state_bucket_name" {
  description = "S3 bucket for Terraform remote state"
  type        = string
  default     = "dqm-terraform-state-ap-south"
}

variable "dynamodb_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
  default     = "dqm-terraform-locks"
}

variable "snowflake_iam_role_arn" {
  description = "Snowflake IAM role ARN — populate after storage integration setup"
  type        = string
  default     = ""
}
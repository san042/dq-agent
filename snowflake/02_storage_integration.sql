-- ============================================
-- Snowflake 02: Storage Integration for S3
-- ============================================
-- Creates the STORAGE_INTEGRATION that links
-- Snowflake to the AWS S3 Data Lake bucket.
--
-- GET YOUR VALUES FROM terraform outputs:
--   - AWS_ROLE_ARN → snowflake_s3_access_role_arn
--   - BUCKET_NAME → s3_bucket_id (without s3://)
-- ============================================

-- IMPORTANT: Replace STORAGE_AWS_ROLE_ARN with actual value after Terraform apply:
-- Run: terraform output snowpipe_role_arn
-- Then update this value before executing this script

-- Create Storage Integration
CREATE OR REPLACE STORAGE INTEGRATION dq_agent_s3_storage_int
  TYPE = EXTERNAL_STAGE
  ENABLED = TRUE
  STORAGE_PROVIDER = 'S3'
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::011934824817:role/snowflake-s3-access'
  STORAGE_ALLOWED_LOCATIONS = (
    's3://dq-agent-datalake-production/'
  );

-- Grant access to the storage integration
GRANT USAGE ON INTEGRATION dq_agent_s3_storage_int TO ROLE sysadmin;
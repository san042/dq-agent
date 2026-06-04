# Terraform Runbook — DQ Agent Data Lake

## Prerequisites

1. **Terraform** >= 1.5.0 installed
2. **AWS CLI** configured with profile `default` in `~/.aws/config` and `~/.aws/credentials`
3. **AWS Region**: `ap-south-1` (Mumbai)

## File Layout

| File               | Purpose                                   |
| -------------------| ------------------------------------------ |
| `main.tf`          | Provider, S3 bucket, IAM policies, KMS key |
| `variables.tf`   | Variable definitions (no hardcoded creds)    |
| `outputs.tf`       | Outputs for Snowflake/QuickSight config     |
| `security.tf`    | Bucket policy, KMS policy, least-privilege   |
| `resources.tf` | S3 bucket, lifecycle, encryption, public access |

## Terraform Commands

```bash
# Navigate to terraform directory
cd terraform/

# Initialize provider plugins
terraform init

# Validate configuration
terraform validate

# Preview changes (ap-south-1)
terraform plan -out=tfplan

# Apply infrastructure (creates S3 bucket, IAM roles, KMS key)
terraform apply tfplan
```

## Key Variables

| Variable                | Default                       | Description                              |
| ----------------------- | ---------------------------- | ---------------------------------------- |
| `project_name`          | `DQ-Agent`                   | Name prefix for all resources            |
| `environment`           | `production`                 | Environment label                         |
| `aws_region`            | `ap-south-1`                 | AWS region (from ~/.aws/config)           |
| `bucket_name_prefix`    | `dq-agent-datalake`          | S3 bucket name prefix                    |
| `storage_integration_name` | `dq_agent_s3_storage_int` | Snowflake STORAGE_INTEGRATION name       |
| `external_id`           | `DQ-Agent-External-ID`       | External ID for Snowflake IAM assumption  |

## Outputs to Capture

After `terraform apply`, capture these for Snowflake configuration:

1. `s3_bucket_arn` — S3 bucket ARN
2. `snowflake_s3_access_role_arn` — IAM role ARN for Snowflake
3. `storage_integration_name` — Snowflake storage integration name
4. `kms_key_arn` — KMS encryption key ARN
5. `snowflake_external_id` — External ID for Snowflake

## Post-Terraform: Snowflake Configuration

Use the outputs to configure Snowflake:

```sql
-- Snowflake: Create Storage Integration (use values from terraform outputs)
CREATE OR REPLACE STORAGE INTEGRATION dq_agent_s3_storage_int
  TYPE = PIPELINE
  ENABLED = TRUE
  STORAGE_PROVIDER = S3
  STORAGE_AWS_ROLE_ARN = '<snowflake_s3_access_role_arn>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://dq-agent-datalake-production/landing/');
```

## Teardown

```bash
# Destroy all resources (S3 bucket must be empty first)
terraform destroy
```

## Cost Considerations

- **S3**: ~$2-3/month for ~10GB with lifecycle to Glacier
- **KMS**: ~$1/month for default keys
- **IAM**: Free
- **Terraform**: Free (open-source)

## Notes

- credentials are loaded from:
  - `~/.aws/config` reads the region (`ap-south-1`)
  - `~/.aws/credentials` provides access keys via profile `[default]`
- No credentials are hardcoded anywhere
- All resources tagged with `Project=DQ-Agent` and `Environment=production`
- S3 is blocked from public access
- All objects encrypted with KMS at rest
- enforced TLS only (SecureTransport = true)
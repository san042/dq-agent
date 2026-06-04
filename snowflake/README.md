# Snowflake SQL Runbook — DQ Agent Data Lake

## SQL Execution Order (MUST follow this order)

| # | File                                  | Purpose                                         |
|---|---------------------------------------|-------------------------------------------------
|  1| `01_dq_engineering.sql`               | Creates DQ_AGENT DB + DQ_MONITORING + DQ tables |
|  2 | `02_storage_integration.sql`          | S3 Storage Integration for Snowflake             |
|  3 | `03_snowpipe_view.sql`                | Snowpipe auto-ingest from S3 to BRONZE           |
|  4 | `04_views_bronze.sql`                 | BRONZE simplified views (raw data only)          |
|  5 | `05_dq_rules_silver.sql`              | 5 DQ rules + stored procedures                   |
|  6 | `06_bronze_to_silver_sql_task.sql`    | SQL Task: BRONZE → SILVER MERGE + CDC            |
|  7 | `07_billing_tlr.sql`                  | Billing & operational DTL views (Silver Layer)   |
|  8 | `08_qr_chart.sql`                     | QuickSight chart source view (Gold Layer)        |
|  9 | `09_user_quicksight.sql`              | QuickSight BI_USER + RSA key-pair auth           |
| 10 | `10_user_julius.sql`                  | Julius AI USER — READ-ONLY, Gold only            |
| 11 | `11_qr_matrix.sql`                    | QuickSight matrix template (optional)            |

## Prerequisites

1. Database `DQ_AGENT` and schema `DQ_MONITORING` created via `01_dq_engineering.sql`
2. S3 bucket created via Terraform (see `mysql/README.md` for Terraform steps)
3. [`~/.aws/config`](/Users/murugamachine/.aws/config) and [`~/.aws/credentials`](/Users/murugamachine/.aws/credentials) configured with profile `[default]` and region `ap-south-1`
4. Snowflake account configured with `ap-south-1` region

## Step-by-Step Notes

### 01_dq_engineering.sql
- Creates `DQ_AGENT` database and `DQ_MONITORING` schema.
- Creates `DQ_AUDIT_LOG` and `DQ_METRICS` tables for DQ monitoring.

### 02_storage_integration.sql
- Creates `STORAGE_INTEGRATION` linking Snowflake to S3 bucket.
- Replace `STORAGE_AWS_ROLE_ARN` with value from `terraform outputs.tf`.
- Replace `STORAGE_ALLOWED_LOCATIONS` with the actual S3 bucket name from Terraform outputs.

### 03_snowpipe_view.sql
- Creates Snowpipe for auto-ingest from S3 → Bronze.
- Requires `STAGE` configured with S3 URL + Storage Integration.

### 04_views_bronze.sql
- Creates simplified BRONZE views over raw data.
- No transformations — data is stored exactly as received.

### 05_dq_rules_silver.sql
- **Core DQ logic**: 5 stored procedures (non-null, fare_range, schema, geo_bounds, all_dq).
- Represents check at Silver ingested. Rules fail → DQ_AUDIT_LOG + DQ_METRICS.
- Call `run_all_dq_checks()` to execute all 5 rules in sequence.

### 06_bronze_to_silver_sql_task.sql
- `MERGE BRONZE → SILVER` with DQ rules enforced.
- Task is scheduled to run every 5 minutes.
- `RUN_DQ_CHECKS_TASK` runs automatically after `BRONZE_TO_SILVER_TASK` completes.

### 07_billing_tlr.sql
- `billing_summary` view (monthly aggregation).
- `operational_reporting` view (daily aggregation).

### 08_qr_chart.sql
- `qs_gold_summary` view: Gold layer table for QuickSight.
- `dq_health_score` view: DQ scoreline for QuickSight charts.
- `dq_violations_by_type` view: DQ pie chart data.

### 09_user_quicksight.sql
- Creates `quicksight_bi_user` with RSA key-pair auth.
- Sets up `quicksight_bi_role` with READ-only access to `DQ_AGENT.KHA` and `DQ_MONITORING`.
- Public key must be generated via `scripts/openssl_gen_keys.sh` and inserted into the `RSA_PUBLIC_KEY` variable.

### 10_user_julius.sql
- Creates `julius_ai_user` with default login.
- Sets up `julius_ai_role` with READ-ONLY access to Gold only.
- Julius AI NEVER touches S3 directly — all data flows through Snowflake.

### 11_qr_matrix.sql
- `qs_gold_matrix` view: Matrix data for QuickSight.
- `dq_trend_7d` view: 7-day historical DQ trend for QuickSight time series.
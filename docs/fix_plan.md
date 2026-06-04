# DQ Pipeline — Fix Plan
Source: internal_review.txt | Architect: Claude Sonnet 4.6 (cc-pro) | 2026-05-13

---

## TIER 0 — Pipeline cannot run (fix in order)

---

**FIX-01**
- Priority: Tier 0
- File: snowflake/03_snowpipe_view.sql
- Issue: Bronze table DDL is commented out — Snowpipe has no landing target
- Fix: Uncomment and finalize the CREATE TABLE statement for DQ_AGENT.KHA.bronze with correct column definitions matching the NYC Taxi / OpenAQ schema
- Complexity: Medium

---

**FIX-02**
- Priority: Tier 0
- File: snowflake/03_snowpipe_view.sql
- Issue: PIPE targets DQ_AGENT.DQ_AGENT.bronze_csv — wrong database and table name
- Fix: Change COPY INTO target to DQ_AGENT.KHA.bronze to match the correct schema layout
- Complexity: Simple

---

**FIX-03**
- Priority: Tier 0
- File: snowflake/03_snowpipe_view.sql
- Issue: Stage locked to bronze_json format — CSV ingestion (NYC Taxi) blocked
- Fix: Configure stage to support both bronze_csv and bronze_json file formats, or create separate stages per format
- Complexity: Medium

---

**FIX-04**
- Priority: Tier 0
- File: snowflake/04_views_bronze.sql
- Issue: View DDL has broken semi-structured path: `$1:pkec'pickup_datetime'` — unparseable, view fails to compile
- Fix: Correct variant path to `$1:'pickup_datetime'::TIMESTAMP_NTZ` — remove the stray `pkec` fragment
- Complexity: Simple

---

**FIX-05**
- Priority: Tier 0
- File: snowflake/05_dq_rules_silver.sql
- Issue: check_nulls() uses `==` operator in DQ_METRICS INSERT — invalid SQL, stored procedure fails at compile/runtime
- Fix: Replace `null_count == 0` with `null_count = 0` throughout the procedure
- Complexity: Simple

---

## TIER 1 — DQ checks silently wrong (pipeline runs, results are garbage)

---

**FIX-06**
- Priority: Tier 1
- File: snowflake/05_dq_rules_silver.sql
- Issue: check_fare_range() references non-existent column `fare_att_amount` — check always wrong
- Fix: Rename `fare_att_amount` to `fare_amount` in the WHERE clause
- Complexity: Simple

---

**FIX-07**
- Priority: Tier 1
- File: snowflake/05_dq_rules_silver.sql
- Issue: check_schema() queries TABLE_SCHEMA = 'DQ_MONITORING' instead of 'KHA' — validates audit tables not data tables
- Fix: Change TABLE_SCHEMA to 'KHA' and TABLE_NAME to the correct bronze/raw_data table name
- Complexity: Simple

---

**FIX-08**
- Priority: Tier 1
- File: snowflake/05_dq_rules_silver.sql
- Issue: check_schema() hardcodes `total_count = 1` — schema check passes any table with ≥1 column
- Fix: Replace literal 1 with a dynamic SELECT COUNT(*) from information_schema.columns for the target table
- Complexity: Simple

---

**FIX-09**
- Priority: Tier 1
- File: snowflake/05_dq_rules_silver.sql
- Issue: DQ_VIOLATIONS table is created but never populated — individual violation records are never captured
- Fix: Add INSERT INTO DQ_VIOLATIONS statements inside each DQ rule procedure for each failing record, populating violation_details
- Complexity: Complex

---

**FIX-10**
- Priority: Tier 1
- File: snowflake/05_dq_rules_silver.sql
- Issue: check_schema() references wrong table name alongside wrong schema (DQ_MONITORING / bronze instead of KHA / raw_data)
- Fix: Align both TABLE_SCHEMA and TABLE_NAME to match actual KHA schema target table
- Complexity: Simple

---

**FIX-11**
- Priority: Tier 1
- File: snowflake/05_dq_rules_silver.sql
- Issue: DQ_AUDIT_LOG INSERTs use 'bronze' as table_name reference — should be 'silver' for silver-layer checks
- Fix: Replace 'bronze' literals with 'silver' in DQ_AUDIT_LOG and DQ_METRICS INSERT statements inside silver DQ procedures
- Complexity: Simple

---

## TIER 2 — Data consistency and pipeline reliability

---

**FIX-12**
- Priority: Tier 2
- File: snowflake/02_storage_integration.sql
- Issue: STORAGE_AWS_ROLE_ARN uses hardcoded 'snowflake-role' prefix instead of Terraform output value
- Fix: Replace hardcoded ARN prefix with the actual ARN from `terraform output aws_role_arn` after infrastructure apply
- Complexity: Simple

---

**FIX-13**
- Priority: Tier 2
- File: snowflake/06_bronze_to_silver_sql_task.sql
- Issue: MERGE key uses three columns (pickup_datetime, dropoff_datetime, passenger_count) — blocks CDC updates
- Fix: Change MERGE ON clause to match only TARGET.pickup_datetime = SOURCE.pickup_datetime
- Complexity: Simple

---

**FIX-14**
- Priority: Tier 2
- File: snowflake/06_bronze_to_silver_sql_task.sql
- Issue: Column reference `__row_num_in__file` does not match source column `__row_num`
- Fix: Rename `SOURCE.__row_num_in__file` to `SOURCE.__row_num` in the MERGE SELECT clause
- Complexity: Simple

---

## GAPS — Security and infrastructure (add before production)

---

**GAP-01**
- Priority: Gap (HIGH)
- File: terraform/main.tf
- Issue: Terraform remote state backend not configured — local .tfstate exposes IAM ARNs and KMS key IDs in plaintext
- Fix: Add backend "s3" block with S3 bucket, DynamoDB lock table, and encrypt = true; provision those resources separately
- Complexity: Medium

---

**GAP-02**
- Priority: Gap (HIGH)
- File: terraform/resources.tf
- Issue: S3 bucket versioning not enabled — accidental deletes or bad writes permanently destroy raw bronze data
- Fix: Add aws_s3_bucket_versioning resource with status = "Enabled" for the landing bucket
- Complexity: Simple

---

**GAP-03**
- Priority: Gap (MEDIUM)
- File: terraform/resources.tf
- Issue: No CloudTrail trail or S3 server access logging verified — no audit trail for data access
- Fix: Verify CloudTrail trail covers the account and region; add aws_s3_bucket_logging resource pointing to a dedicated log bucket
- Complexity: Medium

---

**GAP-04**
- Priority: Gap (MEDIUM)
- File: snowflake/01_dq_engineering.sql (or new file)
- Issue: No Snowflake network policy — account reachable from any public IP
- Fix: Add CREATE NETWORK POLICY restricting allowed IPs to known CIDR ranges; assign to dq_agent_user and quicksight_user
- Complexity: Simple

---

**GAP-05**
- Priority: Gap (MEDIUM)
- File: snowflake/06_bronze_to_silver_sql_task.sql
- Issue: SQL Task has no SUSPEND_TASK_AFTER_NUM_FAILURES — broken task retries indefinitely, consuming credits silently
- Fix: Add SUSPEND_TASK_AFTER_NUM_FAILURES = 3 to the task DDL
- Complexity: Simple

---

**GAP-06**
- Priority: Gap (MEDIUM)
- File: snowflake/05_dq_rules_silver.sql
- Issue: DQ procedures insert to multiple tables with no transaction wrapper — partial failures leave inconsistent audit state
- Fix: Wrap each procedure body in BEGIN TRANSACTION / COMMIT with EXCEPTION + ROLLBACK block
- Complexity: Medium

---

**GAP-07**
- Priority: Gap (LOW)
- File: snowflake/01_dq_engineering.sql (or new file)
- Issue: No Snowflake resource monitor — runaway task or query has no credit circuit breaker
- Fix: Add CREATE RESOURCE MONITOR with monthly credit quota and NOTIFY_USERS action
- Complexity: Simple

---

**GAP-08**
- Priority: Gap (LOW)
- File: scripts/streamlit_dq_dashboard.py
- Issue: os.getenv() usage confirmed but production injection method unverified — .env file risk
- Fix: Confirm deployment injects secrets via AWS Secrets Manager or equivalent, not a .env file; document the injection method
- Complexity: Simple

---

## Summary

| Tier   | Count | Complexity breakdown          |
|--------|-------|-------------------------------|
| Tier 0 | 5     | 3 Simple, 2 Medium            |
| Tier 1 | 6     | 5 Simple, 1 Complex           |
| Tier 2 | 3     | 3 Simple                      |
| Gap    | 8     | 5 Simple, 2 Medium, 1 Complex |
| Total  | 22    | 16 Simple, 4 Medium, 2 Complex |

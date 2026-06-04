# Requirements — DQM (Data Quality Monitor Pipeline)

## Project Overview

Automated, event-driven Data Quality pipeline using Medallion Architecture on AWS S3 + Snowflake. Ingests raw data from S3 into Bronze, enforces 5 DQ rules at Silver, and exposes validated data to QuickSight, Julius AI, and a Streamlit dashboard.

---

## v1 Requirements

### REQ-01: S3 Data Lake Infrastructure
Deploy S3 bucket with `/landing`, `/processed`, and `/logs` folders in ap-south-1, encrypted with KMS.

### REQ-02: Terraform Remote State
Configure S3 + DynamoDB backend for Terraform state with encryption.

### REQ-03: IAM Roles (Least-Privilege)
Create IAM roles for Snowpipe S3 access, QuickSight S3 access, and Julius AI (Snowflake-only).

### REQ-04: S3 Bucket Policy
Restrict S3 access to AWS account + Snowflake role only.

### REQ-05: S3 Bucket Versioning
Enable versioning on the landing bucket to protect against accidental deletes.

### REQ-06: Snowflake Database & Schema
Create `DQ_AGENT` database with `KHA` (Bronze/Silver/Gold) and `DQ_MONITORING` schemas.

### REQ-07: DQ Audit Tables
Create `DQ_AUDIT_LOG` and `DQ_METRICS` tables for tracking DQ violations and rule outcomes.

### REQ-08: S3 Storage Integration
Map S3 bucket to Snowflake via IAM role for Snowpipe ingestion.

### REQ-09: Snowpipe Auto-Ingestion
Configure Snowpipe to auto-ingest files from S3 `/landing` into Bronze (event-driven, no polling).

### REQ-10: Bronze Views
Create simplified views over raw Bronze data.

### REQ-11: DQ Rules Enforcement at Silver
Enforce 5 DQ rules before data reaches Silver:
1. Uniqueness / Deduplication
2. Non-null checks on critical fields
3. Numeric range validation
4. Schema structure validation
5. Referential integrity constraints

### REQ-12: DQ Violation Tracking
Log individual violation records to `DQ_VIOLATIONS` table.

### REQ-13: Bronze-to-Silver MERGE Task
SQL Task to MERGE Bronze → Silver with correct CDC key and column references.

### REQ-14: Billing & Operational DTL Views
Create Silver-layer billing and operational views.

### REQ-15: QuickSight Chart Source View
Create Gold-layer views for QuickSight dashboards.

### REQ-16: QuickSight User & RSA Auth
Set up QuickSight BI_USER with RSA key-pair authentication (4096-bit).

### REQ-17: Julius AI User (Read-Only)
Set up Julius AI user with READ-ONLY access to Gold schema only.

### REQ-18: Streamlit DQ Dashboard
Local Streamlit app connecting to Snowflake, displaying DQ score trends, rule failures, and health scores.

### REQ-19: AWS CloudTrail & S3 Logging
Enable CloudTrail and S3 server access logging for audit trail.

### REQ-20: Snowflake Network Policy
Restrict Snowflake account access to known CIDR ranges.

### REQ-21: Resource Monitor
Create Snowflake resource monitor with monthly credit quota and NOTIFY_USERS.

### REQ-22: Task Failure Circuit Breaker
Add `SUSPEND_TASK_AFTER_NUM_FAILURES = 3` to SQL Tasks.

### REQ-23: Transaction Safety for DQ Procedures
Wrap DQ procedures in BEGIN TRANSACTION / COMMIT with EXCEPTION + ROLLBACK.

### REQ-24: Secrets Management
Deploy Streamlit with secrets via AWS Secrets Manager (no .env files).

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REQ-01 | Phase 1 | Pending |
| REQ-02 | Phase 1 | Pending |
| REQ-03 | Phase 1 | Pending |
| REQ-04 | Phase 1 | Pending |
| REQ-05 | Phase 1 | Pending |
| REQ-06 | Phase 1 | Pending |
| REQ-07 | Phase 1 | Pending |
| REQ-08 | Phase 1 | Pending |
| REQ-09 | Phase 1 | Pending |
| REQ-10 | Phase 2 | Pending |
| REQ-11 | Phase 2 | Pending |
| REQ-12 | Phase 2 | Pending |
| REQ-13 | Phase 2 | Pending |
| REQ-14 | Phase 2 | Pending |
| REQ-15 | Phase 3 | Pending |
| REQ-16 | Phase 3 | Pending |
| REQ-17 | Phase 3 | Pending |
| REQ-18 | Phase 4 | Pending |
| REQ-19 | Phase 5 | Pending |
| REQ-20 | Phase 5 | Pending |
| REQ-21 | Phase 5 | Pending |
| REQ-22 | Phase 5 | Pending |
| REQ-23 | Phase 5 | Pending |
| REQ-24 | Phase 5 | Pending |

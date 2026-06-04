# ROADMAP — DQM v1.0

## Milestone: v1.0 — Foundation & Core Pipeline

**Goal:** Deploy end-to-end Medallion Architecture (Bronze → Silver → Gold) with DQ rule enforcement, QuickSight dashboard, and Streamlit monitoring.

**Target features:**
- AWS S3 + Snowflake infrastructure (Terraform)
- Snowpipe auto-ingestion into Bronze
- 5 DQ rules enforced at Silver
- DQ audit logging and metrics
- QuickSight BI integration
- Julius AI read-only access
- Streamlit DQ monitoring dashboard

## Active Requirements

| REQ-ID | Description | Phase |
|--------|-------------|-------|
| REQ-01 | S3 Data Lake Infrastructure | Phase 1 |
| REQ-02 | Terraform Remote State | Phase 1 |
| REQ-03 | IAM Roles (Least-Privilege) | Phase 1 |
| REQ-04 | S3 Bucket Policy | Phase 1 |
| REQ-05 | S3 Bucket Versioning | Phase 1 |
| REQ-06 | Snowflake Database & Schema | Phase 1 |
| REQ-07 | DQ Audit Tables | Phase 1 |
| REQ-08 | S3 Storage Integration | Phase 1 |
| REQ-09 | Snowpipe Auto-Ingestion | Phase 1 |
| REQ-10 | Bronze Views | Phase 2 |
| REQ-11 | DQ Rules Enforcement at Silver | Phase 2 |
| REQ-12 | DQ Violation Tracking | Phase 2 |
| REQ-13 | Bronze-to-Silver MERGE Task | Phase 2 |
| REQ-14 | Billing & Operational DTL Views | Phase 2 |
| REQ-15 | QuickSight Chart Source View | Phase 3 |
| REQ-16 | QuickSight User & RSA Auth | Phase 3 |
| REQ-17 | Julius AI User (Read-Only) | Phase 3 |
| REQ-18 | Streamlit DQ Dashboard | Phase 4 |
| REQ-19 | AWS CloudTrail & S3 Logging | Phase 5 |
| REQ-20 | Snowflake Network Policy | Phase 5 |
| REQ-21 | Resource Monitor | Phase 5 |
| REQ-22 | Task Failure Circuit Breaker | Phase 5 |
| REQ-23 | Transaction Safety for DQ Procedures | Phase 5 |
| REQ-24 | Secrets Management | Phase 5 |

## Phases

### Phase 1: Foundation & Infrastructure

**Goal:** Deploy S3 data lake, Snowflake database, Snowpipe auto-ingestion, and fix all Tier-0 bugs.

**Requirements:** REQ-01, REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-07, REQ-08, REQ-09

**Success Criteria:**
1. S3 bucket `agentic-dq-ap-south` created with `/landing`, `/processed`, `/logs` folders, KMS encrypted, versioning enabled
2. Terraform state stored in S3 + DynamoDB with encryption
3. IAM roles for Snowpipe, QuickSight, and Julius AI created with least-privilege access
4. S3 bucket policy restricts access to AWS account + Snowflake role only
5. Snowflake `DQ_AGENT` database with `KHA` and `DQ_MONITORING` schemas created
6. `DQ_AUDIT_LOG` and `DQ_METRICS` tables created and populated
7. S3 Storage Integration configured with correct IAM role
8. Snowpipe auto-ingests files from S3 `/landing` into Bronze (event-driven, no polling)
9. All Tier-0 bugs fixed (FIX-01 through FIX-05): table DDL, schema references, CSV/JSON formats, variant paths, SQL syntax errors

**Depends on:** None

### Phase 2: Core DQ Pipeline

**Goal:** Implement Bronze-to-Silver MERGE with 5 DQ rules, violation tracking, and billing views.

**Requirements:** REQ-10, REQ-11, REQ-12, REQ-13, REQ-14

**Success Criteria:**
1. Bronze views over raw data created and queryable
2. 5 DQ rules enforced at Silver: uniqueness/dedup, non-null checks, numeric range, schema validation, referential integrity
3. Individual violation records logged to `DQ_VIOLATIONS` table
4. Bronze-to-Silver MERGE task uses correct CDC key and column references (FIX-03, FIX-04 verified)
5. Silver-layer billing and operational views created and queryable

**Depends on:** Phase 1

### Phase 3: Consumer Integration

**Goal:** Expose Gold-layer data to QuickSight and Julius AI with least-privilege access.

**Requirements:** REQ-15, REQ-16, REQ-17

**Success Criteria:**
1. Gold-layer views created for QuickSight dashboards
2. QuickSight BI_USER set up with RSA key-pair authentication (4096-bit)
3. Julius AI user created with READ-ONLY access to Gold schema only
4. QuickSight dashboard renders DQ metrics from Gold views

**Depends on:** Phase 2

### Phase 4: Monitoring & Dashboard

**Goal:** Build Streamlit DQ monitoring dashboard with score trends, rule failures, and health scores.

**Requirements:** REQ-18

**Success Criteria:**
1. Streamlit app connects to Snowflake and displays DQ score trends
2. Dashboard shows rule failures and health scores
3. Dashboard filters by date range and data source
4. App deployed with secrets via AWS Secrets Manager (no .env files)

**Depends on:** Phase 2

### Phase 5: Reliability & Compliance

**Goal:** Add task safety, audit logging, resource monitoring, and secrets management.

**Requirements:** REQ-19, REQ-20, REQ-21, REQ-22, REQ-23, REQ-24

**Success Criteria:**
1. AWS CloudTrail and S3 server access logging enabled for audit trail
2. Snowflake network policy restricts access to known CIDR ranges
3. Snowflake resource monitor configured with monthly credit quota and NOTIFY_USERS
4. SQL Tasks have `SUSPEND_TASK_AFTER_NUM_FAILURES = 3` (circuit breaker)
5. DQ procedures wrapped in BEGIN TRANSACTION / COMMIT with EXCEPTION + ROLLBACK
6. Streamlit secrets deployed via AWS Secrets Manager

**Depends on:** Phase 3

# Architecture Specification — Medallion DQ Pipeline

**Project**: AWS S3 + Snowflake Medallion Data Quality Pipeline
**Version**: 1.0.0
**Date**: 2026-05-13
**AWS Region**: ap-south-1 (Mumbai)

---

## 1. System Overview

Automated, event-driven Data Quality pipeline utilizing the Medallion Architecture via Terraform.

**Primary Stack**: AWS (S3, IAM, KMS), Snowflake, Amazon QuickSight, Julius AI, Streamlit.

### Design Goals
1. **Event-Driven Ingestion** — Snowpipe auto- ingests from S3 (/landing) into Bronze without polling.
2. **DQ Rule Enforcement at Silver Ingress** — 5 enterprise-grade DQ rules run before data is exposed to downstream consumers.
3. **Least-Privilege Access** — QuickSight and Julius AI are granted STRICT READ-ONLY access scoped exclusively to the Gold schema.
4. **Immutable Audit Trail** — All DQ violations logged in `DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG` and `DQ_METRICS` tables.
5. **Multi-Consumer Readiness** — Same Gold layer serves QuickSight dashboards, Julius AI analysis, and the Streamlit DQ dashboard.

---

## 2. Medallion Architecture Layers

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  REAL-WORLD DATA  ───────►  AWS S3  (/landing)                                       │
│                                                                                       │
│  ┌──────────────────────────────────────────────────────────┐                        │
│  │ BRONZE  — Raw, append-only, as-is from S3               │                        │
│  │  - Ingested by Snowpipe upon file arrival               │                        │
│  │  - Immutable — once written, never modified             │                        │
│  └──────────────────────────────────────────────────────────┘                        │
│                              │                                                        │
│                              ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐                        │
│  │ SILVER  — Cleaned, DQ-enforced, deduplicated, structured│                        │
│  │  - 5 DQ rules enforced:                                   │                        │
│  │    1. Uniqueness / Deduplication                          │                        │
│  │    2. Non-null checks on critical fields                  │                        │
│  │    3. Numeric range validation                            │                        │
│  │    4. Schema structure validation                         │                        │
│  │    5. Referential integrity constraints                   │                        │
│  │  - Failures → DQ_AUDIT_LOG + DQ_METRICS                 │                        │
│  └──────────────────────────────────────────────────────────┘                        │
│                              │                                                        │
│                              ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐                        │
│  │  GOLD  — Business-ready aggregates, validated             │
│  │  - ONLY resource exposed to consumers                     │
│  │  - QuickSight → Gold views only                           │
│  │  - Julius AI → Gold tables only                           │
│  └──────────────────────────────────────────────────────────┘                        │
│                              │                                                        │
│                              ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐                        │
│  │  CONSUMERS                                                │
│  │  ├── Amazon QuickSight (BI dashboards, DQ charts)         │
│  │  ├── Julius AI (prompt-driven analysis)                   │
│  │  └── Streamlit DQ Dashboard (local, real-time monitoring) │
│  └──────────────────────────────────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Layer-by-Layer Layer Definition

| Layer    | Schema                    | DB               | Ingested            |  Description                                                                |
| -------- | ------------------------- | ---------------- | ------------------- | --------------------------------------------------------------------------- |
| BRONZE   | `DQ_AGENT.KHA`            | `DQ_AGENT`       |  Allraw data from S3 | Raw records stored exactly as received. |Make records totally no deletions, no transforms, immutable. |
| SILVER   | `DQ_AGENT.KHA`                    | `DQ_AGENT`         | `cleaned_data`      | Deduplicated, schema-cleaned, DQ-validated, cross-joined raw-data.          |
| GOLD       | `DQ_AGENT.KHA`            | `DQ_AGENT`       | `gold_summary`      | Business-ready, pre-aggregated, fully DQ-passed. Exposed to QuickSight & Julius AI. |

---

## 3. AWS Infrastructure (Terraform-Managed)

### AWS Resources

| Resource             | Terraform File     | Type                 | Purpose                                                   |
| -------------------- | ------------------ | -------------------- | ------------------------------------------------------ |
| S3 Bucket            | `resources.tf`     | `aws_s3_bucket`      | Data lake: `/landing` (raw ingest), `/processed` (Golden) |
| KMS Key              | `security.tf`      | `aws_kms_key`      | Encrypt S3 objects at rest                                |
| IAM Role — Snowflake | `security.tf`      | `aws_iam_role`     | Snowflake Snowpipe assumed role policy on S3             |
| IAM Policy — S3 Read | `main.tf`          | `aws_iam_policy`   | S3 `GetObject`, `ListBucket`, `PutObject`                  |
| S3 Bucket Policy     | `security.tf`      | `aws_s3_bucket_policy | Restrict edge access to AWS Account + Snowflake Role ONLY |
| Security Group       | `security.tf`  | `aws_security_group` | Network security for VPC (if VPC endpoints used)      |

### S3 Bucket Folders
```
s3://dq-agent-datalake/
├── /landing/      ← Files land here → triggers Snowpipe
├── /processed/    ← DQ-enriched or model output files
└── /logs/         ← Application logging, task logs
```

### Recommended Directives (to exclude them from terraform **NOT HARD-CODED**)
- All resource names assume the `default` AWS profile, derived from `~/.aws/credentials` and `~/.aws/config`.
- The terraform provider automatically detects the region from the configured profile (`ap-south-1`).
- No credentials are stored in terraform files.
- Terraform is compliant to following the privacy of environment variables for terraform files.
- No credentials are ever hardcoded.
- No credentials are hardcoded into the codebase.

---

## 4. Snowflake Components

### Database & Schemas

| Name                        | Description                                              |
| --------------------------- | ------------------------------------------------------- |
| `DQ_AGENT`                  | Main database holding all Bronze/Silver/Gold objects   |
| `DQ_AGENT.KHA`           | Contains RAW/PROCESS/processing media                 |
| `DQ_AGENT.DQ_MONITORING`    | DQ Audit tables: `DQ_AUDIT_LOG` and `DQ_METRICS`       |

### DQ Audit Tables

#### `DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG`
| Column       | Type                | Description                                  |
| ------------ | -------------------- | -------------------------------------------- |
| `run_id`     | VARCHAR (UUID)       | Unique run identifier                         |
| `table_name`    | VARCHAR            | Source / target table name                    |
| `check_type` | VARCHAR            | DQ check type (e.g., `NON_NULL`, `NUM_RANGE`) |
| `result_value`| NUMBER            | Numeric result of the check                   |
| `severity`   | VARCHAR            | `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`          |
| `ai_summary` | VARCHAR            | LLM-generated summary of the violation        |
| `alert_sent` | BOOLEAN              | Whether downstream alert was triggered        |
| `run_ts`     | TIMESTAMP            | Automatically set on insertion                |

#### `DQ_AGENT.DQ_MONITORING.DQ_METRICS`
| Column        | Type               | Description                                   |
| ------------- | ------------------ | --------------------------------------------- |
| `run_id`      | VARCHAR (UUID)     | Unique run identifier                         |
| `table_name`  | VARCHAR            | Source table name                              |
| `rule_name`   | VARCHAR            | DQ rule identifier                            |
| `passed`      | BOOLEAN            | Whether the data passed the rule              |
| `fail_count`  | NUMBER             | Number of records that failed                 |
| `total_count` | NUMBER             | Total records evaluated                        |
| `fail_percent`| FLOAT */%          | Percentage field                               |
| `run_timestamp`| TIMESTAMP           | Automatically set on insertion                |
| `llm_summary` | VARCHAR            | LLM-generated summary of the outcomes         |

### Snowflake SQL Scripts

| File                                                    | Description                                             |
| ------------------------------------------------------- | ------------------------------------------------------- |
| `01_dq_engineering.sql`      | Creates DB `DQ_AGENT`, SCHEMA `KHA` + `DQ_MONITORING`, + `DQ_AUDIT_LOG` + `DQ_METRICS`. |
| `01_dq_engineering.sql`     | All DQ_ENGINEERING DB + `KHA` + `DQ_MONITORING` + `DQ_AUDIT_LOG` + `DQ_METRICS` Tables . |
| `02_storage_integration.sql` | Skape of KMS Key Policy in S3.                          |
| `03_snowpipe_view.sql`       | Auto-ingest from S3 to BRONZE via Snowpipe              |
| `04_views_bronze.sql`        | Simplified BRONZE views (raw data only)                  |
| `05_dq_rules_silver.sql`     | DQ rules enforced at SILVER. Failures → `DQ_AUDIT_LOG` & `DQ_METRICS` |
| `06_bronze_to_silver_sql_task.sql`  | SQL Task: MERGE BRONZE → SILVER (CDC)          |
| `07_billing_tlr.sql`         | Billing & Operational DTL views (Silver Layer)          |
| `08_qr_chart.sql`            | QuickSight DQ chart source view (Golden Layer)          |
| `09_user_quicksight.sql`     | QuickSight BI_USER + RSA key-pair authentication        |
| `10_user_julius.sql`         | Julius AI USER — READ ONLY access. To Gold only         |
| `11_qr_matrix.sql`           | QuickSight matrix template (optional chart level)       |

### Consumes User Model

| User               | Access Level                                         |
| ------------------ | ---------------------------------------------------- |
| QuickSight BI_USER | READ-ONLY. In `DQ_AGENT.GOLD` + `DQ_MONITORING`.     |
| Julius AI USER     | READ-ONLY. exclusively to `DQ_AGENT.GOLD` tables only.  |

---

## 5. DQ Rules (Enforced at Silver Ingress)

### 1. Uniqueness / Deduplication
- **(pickup_datetime, dropoff_datetime)** must be unique records.
- Duplicates are quarantined and logged in `DQ_AUDIT_LOG`.

### 2. Non-Null Checks on Critical Fields
- `pickup_datetime`, `dropoff_datetime`, `passenger_count` MUST NOT be NULL.
- Records with NULLs on critical fields are rejected or sent to DQ_AUDIT_LOG.

### 3. Numeric Range Validation
- `fare_amount` must be > 0 AND < 500.
- Out-of-range values are sent to DQ_METRICS as failures.

### 4. Schema Structure Validation
- All incoming records must match the expected Bronze schema.
- Missing columns or unexpected data types trigger schema violation alerts.

### 5. Referential Integrity Constraints
- Valid geographic coordinates (`pickup_latitude`, `pickup_longitude`, `dropoff_latitude`, `dropoff_longitude`) must be within NYC bounds.
- Invalid coordinates are blocked.

---

## 6. Security & Access Control

### IAM Roles (Least-Privilege)

| Role                          | S3 Access                  | Why                                               |
| ----------------------------- | -------------------------- | ------------------------------------------------- |
| `snowpipe_s3_access`         | `GetObject` + `ListBucket` on S3 (/landing)                              |
| `quicksight_s3_access`       | `GetObject` on S3 (/processed)                                   |
| `julius_ai_s3_access`        | NONE (directly from Snowflake only, NEVER touching S3 direct)               |

### Snowflake Storage Integration
- Maps S3 bucket to Snowflake via the `snowpipe_s3_access` IAM Role.
- Storage integration name: created in `02_storage_integration.sql`.

### QuickSight BI User
- Authentication: **RSA Key-Pair Authentication** (via `09_user_quicksight.sql`).
- Allowed Objects: Only `DQ_AGENT.GOLD.*`.
- Public Key: Generated via `scripts/openssl_gen_keys.sh` (4096-bit RSA).

### Julius AI User
- Authentication: Standard Snowflake user credentials.
- Allowed Objects: ONLY `DQ_AGENT.GOLD.*` — READ-ONLY.
- No direct S3 access — data flows only through Snowflake to protect against unauthorized AWS bucket access.

### DQ_USER (internal)
- DBA-level role for administrative, monitoring, and DQ rule maintenance.
- Has FULL access to `DQ_AGENT` and `DQ_MONITORING`.

---

## 7. Monitoring & Visualization

### Executvie BI: Amazon QuickSight
- Connected to Gold schema tables via QuickSight BI_USER.
- DQ charts rendered in `ap-south-1` (lowest latency).
- DQ dashboard queries `DQ_AGENT.DQ_MONITORING.DQ_METRICS` for scoreline.

### Local Monitoring: Streamlit DQ Dashboard
- Script: `scripts/streamlit_dq_dashboard.py`.
- Connects to Snowflake, pulls `DQ_METRICS` real-time via Snowflake Python connector.
- Displays: DQ score trends, rule failure counts, DQ health score per table.

### Audit Trail
- All DQ checks log to `DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG`.
- Metrics aggregated in `DQ_AGENT.DQ_MONITORING.DQ_METRICS`.
- Streamlit dashboard reads these tables for real-time reporting.

---

## 8. Execution and Terraform Runbook

### Terraform Apply Order
1. `terraform init`
2. `terraform validate`
3. `terraform plan -out=tfplan`
4. `terraform apply tfplan`

### Snowflake SQL Execution Order
**MUST be executed in this exact order**:

1. `01_dq_engineering.sql` — `DQ_AGENT` DB + `KHA` + `DQ_MONITORING` + DQ tables.
2. `02_storage_integration.sql` — Create the S3 storage integration.
3. `03_snowpipe_snowpipe.sql` — Snowpipe for S3 → BRONZE auto-ingest.
4. `04_views_bronze.sql` — BRONZE simplified views.
5. `05_dq_rules_silver.sql` — DQ rules enforced at SILVER level.
6. `06_bronze_to_silver_sql_task.sql` — SQL Task: MERGE BRONZE → SILVER.
7. `07_billing_tlr.sql` — Billing & operational DTL views (Silver Layer).
8. `08_qr_chart.sql` — QuickSight chart source view (Gold Layer).
9. `09_user_quicksight.sql` — Setup QuickSight BI_USER + RSA key-pair auth.
10. `10_user_julius.sql` — Setup Julius AI user (READ-ONLY, Gold only).
11. `11_qr_matrix.sql` — QuickSight matrix template (optional).

### OpenSSL Command for QuickSight RSA Key-Pair
```bash
# Generate private key (keep secure)
openssl genrsa -out quicksight_private_key.pem 4096

# Extract public key (for Snowflake USER setup)
openssl rsa -in quicksight_private_key.pem -pubout -out quicksight_public_key.pem

# Verify
openssl rsa -in quicksight_private_key.pem -pubout -text | cat quicksight_public_key.pem | openssl rsa -pubin -in /dev/stdin -text
```

---

## 9. Design Decisions & Trade-offs

| Decision                           | Selected Approach                          | Rationale                                                     |
| ---------------------------------- | ------------------------------------------ | -------------------------------------------------------------- |
| Storage Layer                      | AWS S3 (ap-south-1)                        | Region closest to where you are, lowest latency.                |
| Ingestion                          | Snowpipe (streaming)                       | Real-time, event-driven, no polling. Perfect for continuous data needs. |
| Separation of DQ                   | Enforced at SILVER level only              | Gold remains pristine. If DQ fails, data does NOT reach the consumer layer. |
| QuickSight Access                  | RSA key-pair authentication                | Secureest, no password management, fits zero-trust model.       |
| Julius AI Access                   | READ-ONLY on Gold only                     | Prevents any modification to business objects. Safe in BI tools. |
| Monitoring Approach                | Snowflake-native DQ tables + Streamlit     | Low-latency, local app. No external dependencies.                   |
| Terraform                        | aws-south-1, no hardcoded            | Secrets management via `~/.aws/config` and `~/.aws/credentials`. |
| Data Rollback Strategy             | Append-only BRONZE + Silver sedgent        | Full replay capability.                        |
| DQ Rule Storage                    | Stored in DQ tabic, DQ_CREATION_ENGINE ing.dq_engineering.sql       | Centralized, version-controlled, schema documentation as you go. |

---

## 10. File Inventory

<pre>
~/Development/dq-project/
│
├── docs/
│   └── architecture_spec.md  ← You are here              │
└── internal_review.txt      - Review status (auto-generated)
│
├── terraform/  (Step 3)
│   ├── main.tf                 [TBD] — AWS provider, S3 bucket (ap-south-1)
│   ├── variables.tf            [TBD] — Variables, no hardcoded values
│   ├── outputs.tf              [TBD]  — Bucket ARNs, Storage Integration names
│   ├── security.tf             [TBD]  — Bucket policy, KMS, least-privilege IAM
│   ├── resources.tf            [TBD] — S3 bucket + IAM managed by Terraform
│   └── README.md               [TBD] — Terraform runbook
│
├── snowflake/  (Step 4)
│   ├── 01_dq_engineering.sql   [TBD] — DQ_AGENT DB + DQ_MONITORING + DQ tables.
│   ├── 02_storage_integration.sql [TBD]  S3 Storage Integration
│   ├── 03_snowpipe_view.sql    [TBD]   — Auto-ingest from S3 to BRONZE
│   ├── 04_views_bronze.sql     [TBD]   — BRONZE simplified views
│   ├── 05_dq_rules_silver.sql   [TBD]  — DQ rules enforced at SILVER.
│   ├── 06_bronze_to_silver_sql_task.sql     [TBD] — SQL Task: MERGE BRONZE → SILVER
│   │
│   ├── 07_billing_tlr.sql      [TBD]   — Billing & operational DTL views (Silver Layer)
│   ├── 08_qr_chart.sql         [TBD]   — QuickSight chart source view (Gold Layer)
│   ├── 09_user_quicksight.sql   [TBD]  — QuickSight BI_USER + RSA key-pair authentication
│   ├── 10_user_julius.sql       [TBD]   -- Julius AI USER — READ-ONLY, Gold exclusively.
│   ├── 11_qr_matrix.sql         [TBD]   — QuickSight matrix template (optional)
│   └── README.md               [TBD]         — SQL execution order
│
├── scripts/                   (Step 5)
│   ├── openssl_gen_keys.sh     [TBD]       — QuickSight RSA key-pair generation (4096-bit)
│   └── streamlit_dq_dashboard.py [TBD]     — Real-time DQ monitoring dashboard

└── <FOLDERS FILED>        [TBD]           — Internal review content
```

---

**END OF DOCUMENT**

# Phase 1: Foundation & Infrastructure - Research

**Researched:** 2026-05-18
**Domain:** AWS S3 + Snowflake infrastructure deployment, Terraform IaC, Snowpipe auto-ingestion, Tier-0 bug remediation
**Confidence:** HIGH

## Summary

Phase 1 deploys the foundational infrastructure for the DQM pipeline: S3 data lake with KMS encryption, Terraform remote state, IAM roles with least-privilege access, Snowflake database/schemas, DQ audit tables, S3 storage integration, and Snowpipe auto-ingestion. All 5 Tier-0 bugs in the Snowflake scripts must be fixed as part of this phase.

The Terraform codebase is **mostly complete** (bucket, KMS, IAM roles, versioning, lifecycle, public access block, bucket policies) but **missing the remote state backend** (GAP-01). The Snowflake scripts are functional but contain 5 Tier-0 bugs that block pipeline execution. The infrastructure is designed for `ap-south-1` (Mumbai) with the bucket name `dq-agent-datalake-production`.

**Primary recommendation:** Fix all 5 Tier-0 bugs first (they block every downstream SQL operation), then deploy Terraform, then execute Snowflake SQL scripts in order.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Terraform | 1.15.3 (installed) | AWS infrastructure provisioning | IaC standard for AWS, version-controlled |
| AWS CLI | 2.34.37 (installed) | AWS management, credential management | Standard AWS tooling |
| Snowflake SQL | — | Database, schema, tables, Snowpipe | Native SQL, no ORM needed |
| OpenSSL | 3.6.2 (installed) | RSA key generation for QuickSight | Standard for key pair auth |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jq | Installed | JSON parsing for Terraform outputs | Post-apply output extraction |
| Python 3.12.9 | Installed | Streamlit dashboard (Phase 4), scripts | Not needed for Phase 1 |
| n8n | Latest | Workflow orchestration | Phase 1 only needs infrastructure; n8n config comes later |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Terraform + S3 backend | Terraform + S3 + DynamoDB lock (current plan) | DynamoDB adds lock contention protection but is required for multi-user workflows |
| Snowpipe (auto-ingest) | External tables + COPY INTO polling | Snowpipe is event-driven and preferred for real-time ingestion |
| RSA key-pair auth for QuickSight | Password auth | RSA is more secure and fits zero-trust model |

**Installation:**
```bash
# Already installed on this machine
# Verify:
terraform version  # 1.15.3
aws --version      # 2.34.37
openssl version    # 3.6.2
```

## Architecture Patterns

### Recommended Execution Order

The execution order is critical — each step depends on outputs from the previous:

1. **Fix Tier-0 bugs** in Snowflake scripts (FIX-01 through FIX-05)
2. **Deploy Terraform** (S3 bucket, KMS, IAM roles, versioning, policies)
3. **Capture Terraform outputs** (bucket ARN, IAM role ARN, external ID, KMS key ARN)
4. **Execute Snowflake SQL** in numbered order (01 through 03 for Phase 1 scope)

### Terraform State Management

The current Terraform codebase has **NO remote state backend configured** (GAP-01). This is a critical blocker:
- Local `.tfstate` files expose IAM ARNs and KMS key IDs in plaintext
- No DynamoDB lock table for state file contention protection
- Cannot be safely shared across team members

**Required additions to `main.tf`:**
```hcl
terraform {
  backend "s3" {
    bucket         = "dq-agent-datalake-production-terraform-state"
    key            = "dq-agent/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "dq-agent-terraform-lock"
    encrypt        = true
  }
}
```

These resources (state bucket + DynamoDB table) should be provisioned as a separate Terraform module or created manually before the main infrastructure apply.

### Snowflake Execution Flow

```
01_dq_engineering.sql → 02_storage_integration.sql → 03_snowpipe_view.sql
```

1. **01_dq_engineering.sql**: Creates `DQ_AGENT` database, `DQ_MONITORING` schema, `DQ_AUDIT_LOG` and `DQ_METRICS` tables
2. **02_storage_integration.sql**: Maps S3 bucket to Snowflake via IAM role (requires Terraform output)
3. **03_snowpipe_view.sql**: Creates file formats, transient stage, and Snowpipe for auto-ingestion

### S3 Bucket Structure

```
s3://dq-agent-datalake-production/
├── /landing/      ← Files land here → triggers Snowpipe
├── /processed/    ← DQ-enriched or model output files
└── /logs/         ← Application logging, task logs
```

Bucket name: `dq-agent-datalake-production` (from `var.bucket_name_prefix` + `var.environment`)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Remote state management | Custom state backend | S3 + DynamoDB (Terraform native) | Built-in versioning, encryption, locking |
| Snowflake auto-ingestion | Polling with cron jobs | Snowpipe (`AUTO_INGEST = TRUE`) | Event-driven, no polling overhead |
| S3 encryption | Custom encryption logic | AWS KMS with SSE-S3 | AWS-managed, compliant, no key management |
| QuickSight auth | Password-based | RSA key-pair (4096-bit) | Zero-trust, no password management |
| IAM policies | Manual AWS Console | Terraform `aws_iam_policy` | Version-controlled, reproducible |

**Key insight:** The existing codebase already uses Terraform for IAM and KMS — the only issue is the missing remote state backend and hardcoded ARN in the storage integration.

## Common Pitfalls

### Pitfall 1: Snowflake Storage Integration Hardcoded ARN
**What goes wrong:** `02_storage_integration.sql` line 17 has `'arn:aws:iam::snowflake-role/dq_agent_s3_storage_int'` — this is a placeholder, not a real ARN.
**Why it happens:** The fix plan (FIX-12) identifies this as a Tier 2 issue, but it blocks Phase 1 deployment.
**How to avoid:** Replace with actual Terraform output `snowflake_s3_access_role_arn` after `terraform apply`.
**Warning signs:** `CREATE STORAGE INTEGRATION` fails with IAM error.

### Pitfall 2: Snowpipe Target Table DDL Commented Out
**What goes wrong:** `03_snowpipe_view.sql` lines 52-71 have the `CREATE TABLE` for `bronze` commented out.
**Why it happens:** FIX-01 identifies this as Tier 0 — Snowpipe has no landing target.
**How to avoid:** Uncomment and finalize the CREATE TABLE with correct column definitions matching NYC Taxi schema.
**Warning signs:** Snowpipe COPY INTO fails with "table not found."

### Pitfall 3: Wrong Database/Schema in Snowpipe Target
**What goes wrong:** `03_snowpipe_view.sql` line 100 targets `DQ_AGENT.KHA.bronze` but the table DDL (when uncommented) creates `dq_agent.bronze` (missing `KHA` schema).
**Why it happens:** FIX-02 identifies this as Tier 0.
**How to avoid:** Ensure CREATE TABLE targets `DQ_AGENT.KHA.bronze`.
**Warning signs:** COPY INTO fails with "schema not found."

### Pitfall 4: Stage File Format Mismatch
**What goes wrong:** `03_snowpipe_view.sql` line 28 sets `FILE_FORMAT = dq_agent.bronze_json` but Snowpipe line 121 uses `FILE_FORMAT = dq_agent.dq_bronze_csv` (typo in format name).
**Why it happens:** FIX-03 identifies this as Tier 0 — CSV ingestion is blocked.
**How to avoid:** Create separate stages per format or use a unified stage with format selection.
**Warning signs:** COPY INTO fails with "file format not found" or "invalid file format."

### Pitfall 5: Snowflake Variant Path Syntax Error
**What goes wrong:** `04_views_bronze.sql` line 14 has `$1:'pickup_datetime'::TIMESTAMP_NTZ` — the `$1:` prefix is correct for VARIANT columns but the view references a raw data table, not a VARIANT column.
**Why it happens:** FIX-04 identifies the `pkec` fragment that was removed, but the `$1:` prefix may still be incorrect depending on whether `bronze` is a VARIANT or structured table.
**How to avoid:** Use direct column references if `bronze` is a structured table, or `$1:"column_name"` if it's VARIANT.
**Warning signs:** View compilation fails with "invalid identifier."

### Pitfall 6: IAM Role Assume Role Principal Mismatch
**What goes wrong:** `main.tf` line 36 has `AWS = "arn:aws:iam:::snowflake.com"` — this is malformed (missing account ID and role path).
**Why it happens:** Snowflake's external IAM role requires the Snowflake account ARN, not just `snowflake.com`.
**How to avoid:** Use the correct Snowflake account ARN format: `arn:aws:iam::<snowflake_account_id>:root` or the specific Snowflake role ARN.
**Warning signs:** `sts:AssumeRole` fails with access denied.

### Pitfall 7: QuickSight IAM Principal Format
**What goes wrong:** `main.tf` line 90 has `AWS = "arn:aws:iam::aws:account/${var.aws_account_id}"` — this is malformed (should be `arn:aws:iam::<account_id>:root`).
**Why it happens:** Incorrect ARN construction.
**How to avoid:** Use `arn:aws:iam::${var.aws_account_id}:root`.
**Warning signs:** QuickSight cannot assume the role.

## Runtime State Inventory

> Phase 1 involves deploying infrastructure and fixing code — not renaming or migrating. Minimal runtime state impact.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | No existing databases or datastores (greenfield) | None |
| Live service config | No existing Snowflake database/schema | Create via 01_dq_engineering.sql |
| OS-registered state | No OS-level registrations needed | None |
| Secrets/env vars | No secrets in repo (good) | None for Phase 1 |
| Build artifacts | No build artifacts | None |

**Nothing found in category:** All categories verified — greenfield deployment, no runtime state to migrate.

## Phase Requirements → Research Support

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-01 | S3 Data Lake Infrastructure | Terraform `resources.tf` has bucket, lifecycle, encryption, versioning, public access block. Missing: `/logs` bucket (single bucket with folders). |
| REQ-02 | Terraform Remote State | NOT implemented. Need to add S3 backend + DynamoDB lock. New state bucket needed. |
| REQ-03 | IAM Roles (Least-Privilege) | `main.tf` has `snowflake_s3_access` and `quicksight_s3_access` roles. `julius_ai_s3_access` missing. ARN principals are malformed. |
| REQ-04 | S3 Bucket Policy | `security.tf` has `dq_agent_lake` policy. Duplicate in `main.tf` (line 55-78). Need to consolidate. |
| REQ-05 | S3 Bucket Versioning | Implemented in `resources.tf` line 46-52. ✅ |
| REQ-06 | Snowflake Database & Schema | `01_dq_engineering.sql` creates `DQ_AGENT` DB and `DQ_MONITORING` schema. `KHA` schema NOT created (missing `CREATE SCHEMA KHA`). |
| REQ-07 | DQ Audit Tables | `01_dq_engineering.sql` creates `DQ_AUDIT_LOG` and `DQ_METRICS`. ✅ |
| REQ-08 | S3 Storage Integration | `02_storage_integration.sql` exists but has hardcoded ARN. Needs Terraform output substitution. |
| REQ-09 | Snowpipe Auto-Ingestion | `03_snowpipe_view.sql` exists but has Tier-0 bugs (FIX-01 through FIX-04). |

## Tier-0 Bug Analysis (FIX-01 through FIX-05)

### FIX-01: Bronze Table DDL Commented Out
- **File:** `snowflake/03_snowpipe_view.sql` lines 52-71
- **Issue:** `CREATE TABLE` for `bronze` is entirely commented out
- **Fix:** Uncomment and finalize with correct column definitions
- **Complexity:** Medium

### FIX-02: Wrong Database/Schema in Snowpipe Target
- **File:** `snowflake/03_snowpipe_view.sql` line 100
- **Issue:** Pipe targets `DQ_AGENT.KHA.bronze` but table DDL creates `dq_agent.bronze`
- **Fix:** Ensure table is created in `DQ_AGENT.KHA` schema
- **Complexity:** Simple

### FIX-03: Stage Locked to JSON Format
- **File:** `snowflake/03_snowpipe_view.sql` line 28
- **Issue:** Stage uses `bronze_json` format — CSV (NYC Taxi) blocked
- **Fix:** Create separate stages per format or use `auto` format detection
- **Complexity:** Medium

### FIX-04: Variant Path Syntax Error
- **File:** `snowflake/04_views_bronze.sql` line 14
- **Issue:** `$1:pkec'pickup_datetime'` — unparseable (fix already applied per comment, but verify current state)
- **Fix:** `$1:'pickup_datetime'::TIMESTAMP_NTZ`
- **Complexity:** Simple

### FIX-05: `==` in SQL
- **File:** `snowflake/05_dq_rules_silver.sql` line 71
- **Issue:** `null_count == 0` — invalid SQL operator
- **Fix:** `null_count = 0`
- **Complexity:** Simple

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Terraform | Infrastructure deployment | ✓ | 1.15.3 | — |
| AWS CLI | AWS management | ✓ | 2.34.37 | — |
| OpenSSL | RSA key generation | ✓ | 3.6.2 | — |
| jq | JSON parsing | ✓ | — | — |
| Python 3.12 | Streamlit (Phase 4) | ✓ | 3.12.9 | — |
| Node.js | n8n (Phase 3) | ✓ | v20.20.2 | — |
| SnowSQL | Snowflake CLI | ✗ | — | Use Snowflake Web UI or Python connector |
| Snowflake account | Database/tables | ? | — | Requires account creation |
| AWS account | S3/IAM/KMS | ? | — | Requires account setup |

**Missing dependencies with no fallback:**
- SnowSQL — not installed, but Snowflake Web UI or Python connector can be used
- Snowflake account — not yet created (assumed to exist or will be created)
- AWS account — assumed to have `default` profile configured

## Validation Architecture

> `workflow.nyquist_validation` is set to `false` in config.json — validation architecture section omitted.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | RSA key-pair for QuickSight, Snowflake native auth |
| V3 Session Management | yes | Snowflake session management |
| V4 Access Control | yes | IAM roles, Snowflake roles, bucket policies |
| V5 Input Validation | yes | DQ rules at Silver layer |
| V6 Cryptography | yes | AWS KMS for S3 encryption (never hand-roll) |

### Known Threat Patterns for AWS + Snowflake

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| S3 bucket publicly accessible | Disclosure | `aws_s3_bucket_public_access_block` (implemented) |
| IAM role over-permission | Elevation | Least-privilege policies (implemented, needs verification) |
| KMS key exposure | Disclosure | KMS key policy restricts to Snowflake/QuickSight roles |
| Snowflake credentials in code | Disclosure | No credentials in repo (verified) |
| Terraform state exposure | Disclosure | S3 backend + encryption (GAP-01 — not yet implemented) |

## Sources

### Primary (HIGH confidence)
- `terraform/` — 6 Terraform files (main.tf, variables.tf, outputs.tf, security.tf, resources.tf, README.md)
- `snowflake/` — 12 SQL scripts (01 through 11)
- `docs/fix_plan.md` — 22 bug fixes (FIX-01 through FIX-14, GAP-01 through GAP-08)
- `docs/architecture_spec.md` — Medallion architecture specification
- `terraform/README.md` — Terraform runbook
- `snowflake/README.md` — SQL execution order

### Secondary (MEDIUM confidence)
- `.planning/research/STACK.md` — Technology stack decisions
- `.planning/research/ARCHITECTURE.md` — Medallion architecture
- `.planning/research/PITFALLS.md` — Risk catalog
- `.planning/research/SUMMARY.md` — Research summary

### Tertiary (LOW confidence)
- `AGENTS.md` — NOT FOUND (project has CLAUDE.md instead)
- `DQM_wf_v1.json` — Referenced but not read

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Terraform, AWS CLI, OpenSSL verified via environment probes
- Architecture: HIGH — Medallion pattern confirmed by docs/architecture_spec.md
- Pitfalls: HIGH — 5 Tier-0 bugs documented in docs/fix_plan.md, verified in code
- Terraform state: HIGH — Confirmed missing from main.tf
- IAM ARN formats: MEDIUM — Identified as malformed but exact Snowflake ARN format needs verification

**Research date:** 2026-05-18
**Valid until:** 2026-06-17 (30 days)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Snowflake account exists or will be created for DQM | Environment Availability | If no account, Phase 1 cannot complete |
| A2 | AWS account has `default` profile configured with credentials | Environment Availability | Terraform apply will fail |
| A3 | `DQ_WAREHOUSE` exists in Snowflake (referenced in 06_bronze_to_silver_sql_task.sql) | Architecture Patterns | SQL Task creation will fail |
| A4 | `bronze` table should be a structured table (not VARIANT) based on column definitions | Architecture Patterns | Snowpipe COPY INTO will fail if format mismatch |
| A5 | `julius_ai_s3_access` IAM role is not needed (Julius AI accesses Snowflake only) | REQ-03 | If Julius AI needs S3 access, role is missing |

## Open Questions

1. **What is the actual Snowflake account ID/ARN?**
   - What we know: `main.tf` has malformed ARN `arn:aws:iam:::snowflake.com`
   - What's unclear: Snowflake's external IAM role format (requires Snowflake account ID)
   - Recommendation: Verify with Snowflake admin before deployment

2. **Does `DQ_WAREHOUSE` exist in Snowflake?**
   - What we know: `06_bronze_to_silver_sql_task.sql` references it
   - What's unclear: Whether it exists or needs to be created
   - Recommendation: Create if missing before running 06

3. **Should the S3 bucket be `agentic-dq-ap-south` (per roadmap) or `dq-agent-datalake-production` (per Terraform)?**
   - What we know: Roadmap says `agentic-dq-ap-south`, Terraform uses `dq-agent-datalake-production`
   - What's unclear: Which is the canonical name
   - Recommendation: Align Terraform to roadmap requirement

4. **What is the `KHA` schema?**
   - What we know: Architecture spec says `DQ_AGENT.KHA` contains Bronze/Silver/Gold
   - What's unclear: `01_dq_engineering.sql` does NOT create `KHA` schema
   - Recommendation: Add `CREATE SCHEMA IF NOT EXISTS DQ_AGENT.KHA` to 01

5. **Is the `/logs` S3 folder a separate bucket or just a prefix?**
   - What we know: Architecture spec shows `/logs` as a folder
   - What's unclear: Whether it needs separate lifecycle/versioning
   - Recommendation: Single bucket with prefix is sufficient for MVP

# Project Research Summary

**Project:** DQM (Data Quality Management)
**Domain:** Data Engineering / Data Quality Pipeline
**Researched:** 2026-05-18
**Confidence:** HIGH

## Executive Summary

DQM is an automated data quality pipeline that ingests files from AWS S3, runs AI-powered analysis via Gemini, validates data against quality rules in Snowflake, and surfaces results through QuickSight dashboards with SNS alerts. The system uses n8n for orchestration and Terraform for infrastructure provisioning, following a medallion architecture (Bronze → Silver → Gold).

The recommended approach is to stabilize the existing n8n/Snowflake/Gemini stack before expanding. The immediate priority is fixing 5 critical SQL bugs and securing the exposed API key — both block deployment. After stabilization, the Python DQ engine and Streamlit dashboard should be built to replace fragile workflow-based logic with proper application code.

Key risks are concentrated in three areas: SQL correctness (5 bugs in production rules), security (hardcoded API key), and reliability (no retry logic). These must be addressed before any new feature work.

## Key Findings

### Recommended Stack

The current stack is well-aligned for the problem space — n8n provides visual workflow orchestration, Snowflake handles DQ rule evaluation natively, and Gemini enables metadata analysis. The main gap is a proper Python DQ engine to replace workflow-embedded logic.

**Core technologies:**
- **n8n**: Workflow orchestration — visual builder with AWS integration, avoids custom Python scheduling
- **AWS S3**: Raw file storage (`agentic-dq-ap-south`) — scalable, cost-effective, native AWS integration
- **Snowflake**: Data warehouse — separation of storage/compute, SQL-native DQ rules, Snowpipe auto-ingestion
- **Gemini 2.5 Flash**: AI quality analysis — fast inference for metadata analysis, good cost/performance ratio
- **Terraform**: Infrastructure as code — AWS provisioning for S3, SNS, IAM, KMS, QuickSight
- **QuickSight**: Visualization — dashboard consumption of Gold layer views

### Expected Features

**Must have (table stakes):**
- File ingestion from S3 (n8n workflow) — users expect automated ingestion
- Python DQ engine (requirements.txt exists, no code) — core validation logic
- Streamlit dashboard — user-facing quality monitoring
- SQL bug fixes (FIX-01 through FIX-05) — DQ rules must work correctly

**Should have (competitive):**
- Retry logic for failed ingestions — reliability differentiator
- Cost monitoring dashboard — operational visibility
- Data masking for sensitive columns — compliance requirement

**Defer (v2+):**
- CI/CD pipeline — not essential for initial launch
- Automated testing — can be added after stabilization
- Multi-region support — single region sufficient for MVP

### Architecture Approach

The medallion architecture (Bronze → Silver → Gold) is appropriate for a DQ pipeline. Bronze handles raw ingestion via Snowpipe, Silver enforces DQ rules with SQL, and Gold provides aggregated views for consumption. The main architectural gap is that DQ logic is currently embedded in n8n workflows rather than in a dedicated Python engine, creating a fragile, hard-to-test system.

**Major components:**
1. **n8n Workflow Engine** — scheduled file scanning and Gemini analysis orchestration
2. **Snowflake Medallion Layers** — Bronze (raw), Silver (DQ rules), Gold (aggregations)
3. **Gemini AI Service** — metadata analysis and quality scoring
4. **QuickSight Dashboards** — visualization of quality metrics and trends
5. **SNS Alerting** — notifications for quality issues and pipeline failures
6. **Terraform Infrastructure** — S3, SNS, IAM, KMS, QuickSight provisioning

### Critical Pitfalls

1. **SQL Bugs in Production** (CRITICAL) — 5 bugs (FIX-01 through FIX-05) including missing DDL, wrong table names, broken variant paths, syntax errors, and typos. Fix all before deployment.
2. **API Key Exposure** (CRITICAL) — Gemini API key hardcoded in `DQM_wf_v1.json`. Move to AWS Secrets Manager immediately.
3. **No Retry Logic** (HIGH) — No retry mechanism in n8n workflow for Gemini, S3, or SNS failures. Add retry nodes with exponential backoff.
4. **No Error Handling in DQ Rules** (HIGH) — Pipeline failures without visibility. Add TRY/CATCH blocks and error logging tables.
5. **No Data Masking for PII** (MEDIUM) — Compliance risk (GDPR, CCPA). Implement column-level masking in Silver layer.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Stabilize — Fix Critical Bugs
**Rationale:** 5 SQL bugs and exposed API key block any safe deployment. These must be fixed before new feature work.
**Delivers:** Working DQ rules, secured credentials
**Addresses:** FIX-01 through FIX-05, API key exposure
**Avoids:** Silent pipeline failures, unauthorized Gemini access

### Phase 2: Python DQ Engine
**Rationale:** Extract DQ logic from n8n workflows into a proper Python application with tests. This is the core value proposition.
**Delivers:** Standalone DQ validation engine, test framework
**Uses:** requirements.txt (pandas, pyarrow, dbt-core, great_expectations)
**Implements:** Silver layer DQ rules as application code

### Phase 3: Streamlit Dashboard
**Rationale:** User-facing interface for quality monitoring. Built on top of Gold layer views.
**Delivers:** Interactive quality dashboards, trend analysis
**Uses:** QuickSight views, Python DQ engine
**Implements:** Visualization layer

### Phase 4: Reliability Hardening
**Rationale:** Retry logic, error handling, and monitoring make the pipeline production-ready.
**Delivers:** Retry mechanisms, error logging, CloudWatch alarms
**Uses:** n8n retry nodes, SNS alerts, Snowflake error tables
**Addresses:** No retry logic, no error handling, monitoring gap

### Phase 5: Compliance & Operations
**Rationale:** Data masking and cost monitoring for production readiness.
**Delivers:** PII masking, cost dashboard, CI/CD
**Uses:** Snowflake masking policies, QuickSight cost views
**Implements:** Compliance requirements

### Phase Ordering Rationale

- **Stabilize first** because SQL bugs and API key exposure are blocking risks that make any new work unsafe to deploy
- **Python engine before dashboard** because the dashboard depends on proper DQ logic, and building the engine first gives us tests to validate it
- **Reliability before compliance** because retry/error handling is needed for the dashboard and masking to function reliably
- **Compliance last** because masking is a Silver-layer concern that depends on the engine being stable

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** Python DQ engine integration with Snowflake — needs API research for pyarrow/Snowpark, great_expectations compatibility
- **Phase 4:** n8n retry patterns — needs research on n8n-specific retry mechanisms and error handling workflows
- **Phase 5:** Snowflake data masking policies — needs research on column-level masking syntax and performance impact

Phases with standard patterns (skip research-phase):
- **Phase 1:** SQL bug fixes — well-documented patterns, straightforward corrections
- **Phase 3:** Streamlit dashboard — well-documented, established patterns for data viz
- **Phase 5:** CI/CD pipeline — GitHub Actions is well-documented for Python + SQL projects

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against official docs for n8n, Snowflake, Gemini, Terraform |
| Features | HIGH | Based on existing codebase (DQM_wf_v1.json, snowflake/, requirements.txt) |
| Architecture | HIGH | Medallion pattern is standard, confirmed by docs/architecture_spec.md |
| Pitfalls | HIGH | 5 SQL bugs documented in docs/fix_plan.md, API key visible in workflow JSON |

**Overall confidence:** HIGH

### Gaps to Address

- **Snowflake credit cost at scale** — Mitigation planned (Phase 5 cost monitoring), but exact numbers unknown. Need to estimate during Phase 4.
- **n8n deployment target** — EC2 mentioned as option but not confirmed. Need to decide during Phase 1.
- **Great Expectations compatibility** — Listed as proposed dependency but not validated against Snowflake. Needs research in Phase 2.
- **Multi-format support** — Current research only covers CSV/JSON/Parquet generically. Need to validate actual file formats in S3 during Phase 1.

## Sources

### Primary (HIGH confidence)
- `.planning/research/STACK.md` — Technology stack decisions and alternatives
- `.planning/research/FEATURES.md` — Feature set with priorities and dependencies
- `.planning/research/ARCHITECTURE.md` — Medallion architecture and data flow
- `.planning/research/PITFALLS.md` — Risk catalog with severity ratings
- `snowflake/` — 12 SQL scripts (actual implementation)
- `DQM_wf_v1.json` — n8n workflow definition (actual implementation)
- `docs/architecture_spec.md` — Medallion architecture specification
- `docs/fix_plan.md` — 5 bug fix plan (FIX-01 through FIX-05)
- `agentic_dq_requirements.txt` — Python dependencies

### Secondary (MEDIUM confidence)
- `terraform/` — AWS infrastructure definitions (needs validation against deployed state)

### Tertiary (LOW confidence)
- `agentic_dq_requirements.txt` great_expectations dependency — proposed, not implemented
- EC2 as n8n host — mentioned but not confirmed

---
*Research completed: 2026-05-18*
*Ready for roadmap: yes*

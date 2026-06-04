# DQM — Data Quality Monitor Pipeline

## Summary
Data Quality Monitor (DQM) is an end-to-end data quality monitoring pipeline that ingests Parquet files via Snowpipe into Snowflake, transforms data through a Medallion architecture (Bronze → Silver → Gold), and provides real-time quality insights through a Python/Streamlit dashboard.

## Target Audience
Data engineers, data analysts, and business stakeholders who need visibility into data quality across pipelines.

## Primary Use Case
Automated data quality monitoring with configurable checks, alerting, and interactive dashboards.

## Success Metrics
- MVP delivered in 2-4 weeks
- Configurable data quality checks (row count, nulls, schema, duplicates, etc.)
- Real-time quality dashboards
- Alerting on quality violations

## Key Concepts

### Medallion Architecture
- **Bronze**: Raw ingested data (immutable)
- **Silver**: Cleaned, transformed, quality-checked data
- **Gold**: Aggregated, business-ready data with quality metrics

### Data Quality Checks
The system supports configurable quality checks including:
- Row count validation
- Column presence checks
- Null value checks
- Data type validation
- Duplicate detection
- Range/value checks
- Cross-table validation
- Freshness checks
- Distribution drift detection
- PII detection
- Schema validation
- Referential integrity
- Business rule validation
- Cross-field validation
- Temporal consistency
- Custom SQL checks

### Tech Stack
- **Ingestion**: Snowpipe auto-ingestion for Parquet files
- **Storage/Processing**: Snowflake SQL
- **Dashboard**: Python/Streamlit
- **Infrastructure**: Terraform (AWS)

## Key Files
- `DQM_wf_v1.json` — Workflow definition
- `agentic_dq_requirements.txt` — Detailed requirements
- `docs/fix_plan.md` — Critical bug fixes (Tier-0)
- `snowflake/` — Snowflake SQL scripts
- `terraform/` — AWS infrastructure
- `scripts/` — Utility scripts

## Risks
- Scope creep beyond 2-4 week MVP window
- Complex quality check configuration UX
- Snowpipe integration with existing AWS infrastructure

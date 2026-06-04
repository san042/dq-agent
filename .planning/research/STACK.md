# DQM Technology Stack

## Core Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| Orchestration | n8n | Latest | Workflow automation |
| Storage | AWS S3 | — | Raw file storage |
| Warehouse | Snowflake | — | Data processing |
| AI | Gemini 2.5 Flash | — | Quality analysis |
| Notification | AWS SNS | — | Alerts |
| Infrastructure | Terraform | 1.x | AWS provisioning |
| Visualization | QuickSight | — | Dashboards |

## Stack Decisions

### n8n (Orchestration)
- **Decision**: Use n8n for workflow automation
- **Rationale**: Visual workflow builder, AWS integration built-in, scheduled triggers
- **Alternatives considered**: Airflow (too heavy), Prefect (less visual), custom Python
- **Risk**: Vendor lock-in, limited error handling

### AWS S3 (Storage)
- **Decision**: S3 for raw file storage
- **Rationale**: Scalable, cost-effective, native AWS integration
- **Alternatives considered**: GCS, Azure Blob, local storage
- **Risk**: Limited to AWS region, versioning costs

### Snowflake (Warehouse)
- **Decision**: Snowflake for data processing
- **Rationale**: Separation of storage/compute, SQL-native, good for DQ rules
- **Alternatives considered**: BigQuery, Redshift, Databricks
- **Risk**: Credit-based pricing, SQL bugs in current implementation

### Gemini (AI Analysis)
- **Decision**: Gemini 2.5 Flash for quality analysis
- **Rationale**: Fast inference, good for metadata analysis
- **Alternatives considered**: GPT-4, Claude, local LLM
- **Risk**: API key exposed in workflow, cost at scale, latency

### Terraform (Infrastructure)
- **Decision**: Terraform for AWS provisioning
- **Rationale**: IaC standard, AWS-native, version control friendly
- **Alternatives considered**: CloudFormation, Pulumi, CDK
- **Risk**: State file management, drift detection

## Missing Stack Components

### Python DQ Engine
- **Status**: requirements.txt exists, no implementation
- **Purpose**: Core data quality validation logic
- **Dependencies**: pandas, pyarrow, dbt-core, great_expectations (proposed)

### Streamlit Dashboard
- **Status**: Not built
- **Purpose**: User-facing quality monitoring UI
- **Dependencies**: streamlit, plotly, pandas

### CI/CD Pipeline
- **Status**: Not defined
- **Purpose**: Automated testing and deployment
- **Options**: GitHub Actions, CircleCI, AWS CodePipeline

## Infrastructure Dependencies

### AWS Services
- S3 (bucket: `agentic-dq-ap-south`)
- SNS (topic: `dq-alerts`)
- IAM (roles for Snowflake, QuickSight, EC2)
- KMS (encryption keys)
- QuickSight (dashboards)
- EC2 (n8n host?)

### Snowflake Objects
- Database schemas (bronze, silver, gold)
- Storage integration
- Snowpipe (auto-ingestion)
- Views (quality aggregations)
- Tasks (scheduled DQ checks)
- User access roles

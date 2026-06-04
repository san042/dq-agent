# DQM Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DQM Pipeline                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │  n8n         │    │  AWS S3      │    │  Gemini AI   │                  │
│  │  Workflow    │───▶│  (Bronze)    │───▶│  Analysis    │                  │
│  │  Scheduler   │    │  agentic-dq  │    │  2.5 Flash   │                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│       │                    │                     │                          │
│       │                    ▼                     │                          │
│       │             ┌──────────────┐             │                          │
│       │             │  Snowflake   │             │                          │
│       │             │  Snowpipe    │             │                          │
│       │             │  (Ingestion) │             │                          │
│       │             └──────────────┘             │                          │
│       │                    │                     │                          │
│       │                    ▼                     │                          │
│       │             ┌──────────────┐             │                          │
│       │             │  Silver Layer│             │                          │
│       │             │  DQ Rules    │             │                          │
│       │             └──────────────┘             │                          │
│       │                    │                     │                          │
│       │                    ▼                     │                          │
│       │             ┌──────────────┐             │                          │
│       │             │  Gold Layer  │             │                          │
│       │             │  Views       │             │                          │
│       │             └──────────────┘             │                          │
│       │                    │                     │                          │
│       │                    ▼                     │                          │
│       │             ┌──────────────┐             │                          │
│       │             │  QuickSight  │             │                          │
│       │             │  Dashboards  │             │                          │
│       │             └──────────────┘             │                          │
│       │                    │                     │                          │
│       │                    ▼                     │                          │
│       │             ┌──────────────┐             │                          │
│       │             │  SNS Alerts  │             │                          │
│       │             └──────────────┘             │                          │
│       │                                          │                          │
│       └──────────────────────────────────────────┘                          │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  Terraform Infrastructure                                                │ │
│  │  ├── S3 Bucket (agentic-dq-ap-south)                                    │ │
│  │  ├── SNS Topic (dq-alerts)                                              │ │
│  │  ├── IAM Roles (Snowflake, QuickSight, EC2)                             │ │
│  │  ├── KMS Encryption Keys                                                │ │
│  │  └── QuickSight Resources                                               │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Medallion Architecture

### Bronze Layer
- **Purpose**: Raw file ingestion
- **Storage**: S3 bucket `agentic-dq-ap-south`
- **Mechanism**: Snowpipe auto-ingestion
- **Validation**: Minimal (file existence, format check)

### Silver Layer
- **Purpose**: DQ rule enforcement
- **Storage**: Snowflake tables
- **Mechanism**: SQL-based DQ rules
- **Validation**: Comprehensive (null checks, range checks, referential integrity)

### Gold Layer
- **Purpose**: Aggregated views
- **Storage**: Snowflake views
- **Mechanism**: Aggregations and joins
- **Consumers**: QuickSight, Julius AI

## Data Flow

1. **Trigger**: n8n workflow runs on schedule
2. **Scan**: Lists files in S3 bucket
3. **Analyze**: Sends file metadata to Gemini for analysis
4. **Ingest**: Snowpipe loads files into Bronze
5. **Validate**: Silver layer applies DQ rules
6. **Aggregate**: Gold layer creates views
7. **Alert**: SNS notifications for quality issues
8. **Visualize**: QuickSight dashboards

## Security Model

- **IAM**: Least-privilege roles for each service
- **Encryption**: KMS for S3 and Snowflake
- **Access**: Role-based for QuickSight and Julius AI
- **Audit**: Immutable audit trail

## Key Files

| File | Description |
|------|-------------|
| `DQM_wf_v1.json` | n8n workflow definition |
| `docs/architecture_spec.md` | Medallion architecture spec |
| `snowflake/` | 12 SQL scripts |
| `terraform/` | AWS infrastructure |
| `agentic_dq_requirements.txt` | Python dependencies |

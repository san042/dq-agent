# DQM Feature Set

## Core Features

### 1. File Ingestion
- **Description**: Automated ingestion of files from S3 bucket `agentic-dq-ap-south`
- **Current State**: n8n workflow with scheduled trigger
- **Status**: Partially implemented (workflow exists but has bugs)
- **Priority**: P0

### 2. Quality Analysis
- **Description**: AI-powered analysis of file metadata using Gemini
- **Current State**: HTTP request to Gemini API in workflow
- **Status**: Implemented but API key exposed, no retry logic
- **Priority**: P0

### 3. DQ Rule Enforcement
- **Description**: Validate data against quality rules at Silver layer
- **Current State**: SQL rules defined in `snowflake/`
- **Status**: Has 5 critical bugs (FIX-01 through FIX-05)
- **Priority**: P0

### 4. Alerting
- **Description**: Send alerts via AWS SNS when quality issues detected
- **Current State**: n8n workflow sends to SNS topic `dq-alerts`
- **Status**: Implemented but no filtering on what triggers alerts
- **Priority**: P1

### 5. Visualization
- **Description**: Quality dashboards via QuickSight
- **Current State**: Views defined in Snowflake for dashboards
- **Status**: Partially implemented
- **Priority**: P1

### 6. User Access
- **Description**: Role-based access for QuickSight and Julius AI
- **Current State**: SQL scripts for user roles
- **Status**: Implemented
- **Priority**: P2

## MVP Features (2-4 weeks)

### Must Have
1. ✅ File ingestion (n8n workflow)
2. ❌ Python DQ engine (requirements.txt exists, no code)
3. ❌ Streamlit dashboard
4. ❌ Fix SQL bugs (FIX-01 through FIX-05)

### Should Have
5. ❌ Retry logic for failed ingestions
6. ❌ Cost monitoring dashboard
7. ❌ Data masking for sensitive columns

### Nice to Have
8. ❌ CI/CD pipeline
9. ❌ Automated testing
10. ❌ Multi-region support

## Feature Dependencies

```
File Ingestion → Quality Analysis → DQ Rules → Alerting
     ↓                                              ↓
  Python DQ Engine  →  Streamlit Dashboard  ←  QuickSight Views
```

## Feature Gaps

### Missing
- Input validation before Gemini analysis
- Error handling and retry logic
- Data masking for PII
- Multi-format support (CSV, JSON, Parquet)
- Historical trend analysis
- Alert escalation policies

### Technical Debt
- API key hardcoded in workflow JSON
- No CI/CD
- No automated tests
- No monitoring of the pipeline itself

-- =============================================================
-- 12_export_dq_results.sql
-- DQ Agent — Export DQ Results to S3
-- Version: FINAL (May 20, 2026)
--
-- Adds EXPORT_DQ_RESULTS_TASK to the task chain:
--   BRONZE_TO_SILVER_TASK
--        ↓
--   RUN_DQ_CHECKS_TASK
--        ↓
--   EXPORT_DQ_RESULTS_TASK  ← this file
--
-- Exports today's DQ_AUDIT_LOG + DQ_METRICS to S3 as JSON
-- Target: s3://dq-agent-datalake-production/processed/dq_results/
-- Path structure:
--   processed/dq_results/dq_audit_log/YYYY-MM-DD/data_0_0_0.json.gz
--   processed/dq_results/dq_metrics/YYYY-MM-DD/data_0_0_0.json.gz
--
-- Key fix: EXECUTE IMMEDIATE used for dynamic S3 path construction
-- (Snowflake scripting does not resolve bound variables in
--  COPY INTO stage path literals — must be built as string)
-- =============================================================

USE ROLE SYSADMIN;
USE DATABASE DQ_AGENT;
USE SCHEMA DQ_MONITORING;
USE WAREHOUSE COMPUTE_WH;

-- =============================================================
-- STEP 1: Named stage pointing to processed/dq_results/
-- Uses existing storage integration dq_agent_s3_storage_int
-- =============================================================

CREATE OR REPLACE STAGE DQ_AGENT.DQ_MONITORING.DQ_RESULTS_STAGE
  STORAGE_INTEGRATION = dq_agent_s3_storage_int
  URL = 's3://dq-agent-datalake-production/processed/dq_results/'
  FILE_FORMAT = (
    TYPE = 'JSON'
    NULL_IF = ()
  )
  COMMENT = 'Stage for exporting DQ audit + metrics results to S3';

-- =============================================================
-- STEP 2: Export procedure
-- Exports today's rows from DQ_AUDIT_LOG + DQ_METRICS as JSON
-- Date-partitioned output path built via EXECUTE IMMEDIATE
-- =============================================================

CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.export_dq_results()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
  export_date  VARCHAR;
  audit_sql    VARCHAR;
  metrics_sql  VARCHAR;
BEGIN
  export_date := TO_VARCHAR(CURRENT_DATE(), 'YYYY-MM-DD');

  audit_sql := '
    COPY INTO @DQ_AGENT.DQ_MONITORING.DQ_RESULTS_STAGE/dq_audit_log/' || export_date || '/
    FROM (
      SELECT OBJECT_CONSTRUCT(
        ''log_id'',        LOG_ID,
        ''run_timestamp'', TO_VARCHAR(RUN_TIMESTAMP),
        ''table_name'',    TABLE_NAME,
        ''check_name'',    CHECK_NAME,
        ''status'',        STATUS,
        ''row_count'',     ROW_COUNT,
        ''issue_count'',   ISSUE_COUNT,
        ''details'',       DETAILS
      ) AS json_row
      FROM DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
      WHERE DATE(RUN_TIMESTAMP) = CURRENT_DATE()
    )
    FILE_FORMAT = (TYPE = ''JSON'')
    OVERWRITE = TRUE
    HEADER = FALSE
    SINGLE = FALSE
    MAX_FILE_SIZE = 5242880
  ';

  metrics_sql := '
    COPY INTO @DQ_AGENT.DQ_MONITORING.DQ_RESULTS_STAGE/dq_metrics/' || export_date || '/
    FROM (
      SELECT OBJECT_CONSTRUCT(
        ''metric_id'',     METRIC_ID,
        ''run_timestamp'', TO_VARCHAR(RUN_TIMESTAMP),
        ''table_name'',    TABLE_NAME,
        ''metric_name'',   METRIC_NAME,
        ''metric_value'',  METRIC_VALUE,
        ''threshold'',     THRESHOLD,
        ''passed'',        PASSED
      ) AS json_row
      FROM DQ_AGENT.DQ_MONITORING.DQ_METRICS
      WHERE DATE(RUN_TIMESTAMP) = CURRENT_DATE()
    )
    FILE_FORMAT = (TYPE = ''JSON'')
    OVERWRITE = TRUE
    HEADER = FALSE
    SINGLE = FALSE
    MAX_FILE_SIZE = 5242880
  ';

  EXECUTE IMMEDIATE audit_sql;
  EXECUTE IMMEDIATE metrics_sql;

  RETURN 'DQ results exported to S3 for ' || export_date;

EXCEPTION
  WHEN OTHER THEN
    RETURN 'Export failed: ' || SQLERRM;
END;
$$;

-- =============================================================
-- STEP 3: Suspend root task before modifying DAG
-- =============================================================

ALTER TASK DQ_AGENT.DQ_MONITORING.BRONZE_TO_SILVER_TASK SUSPEND;

-- =============================================================
-- STEP 4: Create task — runs after RUN_DQ_CHECKS_TASK
-- =============================================================

CREATE OR REPLACE TASK DQ_AGENT.DQ_MONITORING.EXPORT_DQ_RESULTS_TASK
  WAREHOUSE = COMPUTE_WH
  AFTER DQ_AGENT.DQ_MONITORING.RUN_DQ_CHECKS_TASK
AS
  CALL DQ_AGENT.DQ_MONITORING.export_dq_results();

-- =============================================================
-- STEP 5: Resume full task chain leaf → root order
-- =============================================================

ALTER TASK DQ_AGENT.DQ_MONITORING.EXPORT_DQ_RESULTS_TASK RESUME;
ALTER TASK DQ_AGENT.DQ_MONITORING.RUN_DQ_CHECKS_TASK RESUME;
ALTER TASK DQ_AGENT.DQ_MONITORING.BRONZE_TO_SILVER_TASK RESUME;

-- =============================================================
-- STEP 6: Verify
-- =============================================================

SHOW TASKS IN SCHEMA DQ_AGENT.DQ_MONITORING;

-- Manual test (uncomment to run):
-- CALL DQ_AGENT.DQ_MONITORING.export_dq_results();
-- Then verify S3:
-- aws s3 ls s3://dq-agent-datalake-production/processed/dq_results/ --recursive

-- ============================================
-- Snowflake 03: Snowpipe Auto-Ingest
-- ============================================
-- Auto-ingest from S3 /landing/ into BRONZE
-- triggered by file arrival events.
-- ============================================

USE DATABASE DQ_AGENT;

-- Bronze raw table (KHA schema)
CREATE TABLE IF NOT EXISTS DQ_AGENT.KHA.BRONZE (
  raw_data        VARIANT,
  file_name       VARCHAR(500),
  file_row_number NUMBER,
  load_timestamp  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  source_format   VARCHAR(20)
);

-- CSV stage + pipe
CREATE STAGE IF NOT EXISTS DQ_AGENT.KHA.BRONZE_STAGE_CSV
  URL = 's3://dq-agent-datalake-production/landing/'
  STORAGE_INTEGRATION = dq_agent_s3_storage_int
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);

-- JSON stage + pipe
CREATE STAGE IF NOT EXISTS DQ_AGENT.KHA.BRONZE_STAGE_JSON
  URL = 's3://dq-agent-datalake-production/landing/'
  STORAGE_INTEGRATION = dq_agent_s3_storage_int
  FILE_FORMAT = (TYPE = JSON STRIP_OUTER_ARRAY = TRUE);

-- CSV pipe
CREATE PIPE IF NOT EXISTS DQ_AGENT.KHA.BRONZE_PIPE_CSV
  AUTO_INGEST = TRUE AS
  COPY INTO DQ_AGENT.KHA.BRONZE (raw_data, file_name, file_row_number, source_format)
  FROM (SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, 'CSV'
        FROM @DQ_AGENT.KHA.BRONZE_STAGE_CSV);

-- JSON pipe
CREATE PIPE IF NOT EXISTS DQ_AGENT.KHA.BRONZE_PIPE_JSON
  AUTO_INGEST = TRUE AS
  COPY INTO DQ_AGENT.KHA.BRONZE (raw_data, file_name, file_row_number, source_format)
  FROM (SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, 'JSON'
        FROM @DQ_AGENT.KHA.BRONZE_STAGE_JSON);
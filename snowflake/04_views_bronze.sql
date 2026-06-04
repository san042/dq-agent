-- CODER FIX [2026-05-18]: Fixed stage refs — raw_data:'key' → raw_data:'key' (FIX-04)
-- ============================================
-- Snowflake 04: Bronze Simplified Views
-- ============================================
-- Simplified BRONZE views over the raw data
-- declared exactly as received (no transforms).
-- ============================================

USE DATABASE DQ_AGENT;

-- View: raw_data (all raw data loaded in BRONZE schema)
CREATE OR REPLACE VIEW DQ_AGENT.KHA.raw_data AS
SELECT
  raw_data:'pickup_datetime'::TIMESTAMP_NTZ as pickup_datetime,
  raw_data:'dropoff_datetime'::TIMESTAMP_NTZ as dropoff_datetime,
  raw_data:'passenger_count'::NUMBER as passenger_count,
  raw_data:'trip_distance'::NUMBER as trip_distance,
  raw_data:'pickup_longitude'::FLOAT as pickup_longitude,
  raw_data:'pickup_latitude'::FLOAT as pickup_latitude,
  raw_data:'rate_code'::VARCHAR as rate_code,
  raw_data:'store_and_fwd_flag'::VARCHAR as store_and_fwd_flag,
  raw_data:'dropoff_longitude'::FLOAT as dropoff_longitude,
  raw_data:'dropoff_latitude'::FLOAT as dropoff_latitude,
  raw_data:'payment_type'::VARCHAR as payment_type,
  raw_data:'fare_amount'::NUMBER as fare_amount,
  raw_data:'extra'::NUMBER as extra,
  raw_data:'mta_tax'::NUMBER as mta_tax,
  raw_data:'tip_amount'::NUMBER as tip_amount,
  raw_data:'tolls_amount'::NUMBER as tolls_amount,
  raw_data:'improvement_surcharge'::NUMBER as improvement_surcharge,
  raw_data:'total_amount'::NUMBER as total_amount,
  $1 as __raw_payload,
  METADATA$FILENAME as __ingested_file,
  METADATA$FILE_ROW_NUMBER as __row_num
FROM DQ_AGENT.KHA.BRONZE;

-- View: raw_summary (quick total records count)
CREATE OR REPLACE VIEW DQ_AGENT.KHA.raw_summary AS
SELECT
  COUNT(*) as total_raw_records,
  COUNT(DISTINCT __ingested_file) as total_files,
  MIN(ingest_timestamp) as earliest_ingest,
  MAX(ingest_timestamp) as latest_ingest
FROM DQ_AGENT.KHA.raw_data;
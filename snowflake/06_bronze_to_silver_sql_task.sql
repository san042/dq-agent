USE ROLE SYSADMIN;

-- ===========================================
-- Snowflake 06: BRONZE → SILVER SQL Task
-- ===========================================
-- MERGE BRONZE → SILVER
-- CDC: inserts new records from BRONZE to SILVER.
-- Applies DQ rules during merge. Failures logged.
-- ============================================

USE DATABASE DQ_AGENT;

-- Create SILVER table (deduplicated + schema-validated)
CREATE OR REPLACE TABLE DQ_AGENT.KHA.silver AS
SELECT
  DISTINCT
  pickup_datetime,
  dropoff_datetime,
  passenger_count,
  trip_distance,
  pickup_longitude,
  pickup_latitude,
  rate_code,
  store_and_fwd_flag,
  dropoff_longitude,
  dropoff_latitude,
  payment_type,
  fare_amount,
  extra,
  mta_tax,
  tip_amount,
  tolls_amount,
  improvement_surcharge,
  total_amount,
  __ingested_file as __source_file,
  __row_num as __row_num,
  CURRENT_TIMESTAMP() as __silver_loaded_ts
FROM DQ_AGENT.KHA.raw_data
WHERE pickup_datetime IS NOT NULL
  AND dropoff_datetime IS NOT NULL
  AND passenger_count IS NOT NULL
  AND fare_amount > 0
  AND fare_amount < 500
  AND pickup_latitude BETWEEN -90 AND 90
  AND pickup_longitude BETWEEN -180 AND 180
  AND dropoff_latitude BETWEEN -90 AND 90
  AND dropoff_longitude BETWEEN -180 AND 180
;

-- Create the SQL Task: triggers on new bronze data
CREATE OR REPLACE TASK DQ_AGENT.DQ_MONITORING.BRONZE_TO_SILVER_TASK
  WAREHOUSE = 'COMPUTE_WH'
  SCHEDULE = '5 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('DQ_AGENT.DQ_MONITORING.bronze_stream')
AS
  MERGE INTO DQ_AGENT.KHA.silver TARGET
  USING DQ_AGENT.KHA.raw_data SOURCE
  ON TARGET.pickup_datetime = SOURCE.pickup_datetime
  WHEN NOT MATCHED THEN INSERT
    (pickup_datetime, dropoff_datetime, passenger_count, trip_distance,
     pickup_longitude, pickup_latitude, rate_code, store_and_fwd_flag,
     dropoff_longitude, dropoff_latitude, payment_type, fare_amount,
     extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
     total_amount, __source_file, __row_num, __silver_loaded_ts)
  VALUES
    (SOURCE.pickup_datetime, SOURCE.dropoff_datetime, SOURCE.passenger_count, SOURCE.trip_distance,
     SOURCE.pickup_longitude, SOURCE.pickup_latitude, SOURCE.rate_code, SOURCE.store_and_fwd_flag,
     SOURCE.dropoff_longitude, SOURCE.dropoff_latitude, SOURCE.payment_type, SOURCE.fare_amount,
     SOURCE.extra, SOURCE.mta_tax, SOURCE.tip_amount, SOURCE.tolls_amount, SOURCE.improvement_surcharge,
     SOURCE.total_amount, SOURCE.__source_file, SOURCE.__row_num, CURRENT_TIMESTAMP())
  ;

-- Create branching task for DQ check (runs after BRONZE → SILVER)
CREATE OR REPLACE TASK DQ_AGENT.DQ_MONITORING.RUN_DQ_CHECKS_TASK
  WAREHOUSE = 'COMPUTE_WH'
  AFTER DQ_AGENT.DQ_MONITORING.BRONZE_TO_SILVER_TASK
AS
  CALL DQ_AGENT.DQ_MONITORING.run_all_dq_checks();

-- Enable the tasks so they are actually running
ALTER TASK DQ_AGENT.DQ_MONITORING.BRONZE_TO_SILVER_TASK RESUME;
ALTER TASK DQ_AGENT.DQ_MONITORING.RUN_DQ_CHECKS_TASK RESUME;
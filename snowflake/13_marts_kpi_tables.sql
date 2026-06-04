-- =============================================================
-- 13_marts_kpi_tables.sql
-- DQ Agent — MARTS Layer KPI Tables
-- Two datasets: NYC Taxi + OpenAQ Air Quality
-- Target schemas: DQ_AGENT.MARTS
-- Reads from: KHA.SILVER (NYC Taxi) + DQ_MONITORING (DQ results)
--             + RAW OpenAQ data loaded from S3
-- =============================================================

USE ROLE SYSADMIN;
USE DATABASE DQ_AGENT;
USE WAREHOUSE COMPUTE_WH;

-- =============================================================
-- SECTION 1: NYC TAXI KPIs
-- Source: DQ_AGENT.KHA.SILVER (20k rows, typed columns)
-- =============================================================

USE SCHEMA MARTS;

-- -----------------------------------------------------------
-- 1a. Daily Trip Volume + Revenue Summary
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW DQ_AGENT.MARTS.NYC_TAXI_DAILY_KPI AS
SELECT
  DATE(pickup_datetime)                          AS trip_date,
  COUNT(*)                                       AS total_trips,
  ROUND(AVG(fare_amount), 2)                     AS avg_fare,
  ROUND(SUM(fare_amount), 2)                     AS total_revenue,
  ROUND(AVG(trip_distance), 2)                   AS avg_distance_miles,
  ROUND(AVG(passenger_count), 1)                 AS avg_passengers,
  ROUND(AVG(tip_amount), 2)                      AS avg_tip,
  ROUND(SUM(tip_amount) / NULLIF(SUM(fare_amount), 0) * 100, 1) AS tip_pct_of_fare,
  COUNT(DISTINCT DATE(pickup_datetime))          AS active_days,
  MAX(__silver_loaded_ts)                        AS last_loaded_ts
FROM DQ_AGENT.KHA.SILVER
WHERE fare_amount > 0
GROUP BY DATE(pickup_datetime)
ORDER BY trip_date DESC;

-- -----------------------------------------------------------
-- 1b. Payment Type Breakdown
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW DQ_AGENT.MARTS.NYC_TAXI_PAYMENT_KPI AS
SELECT
  DATE(pickup_datetime)                          AS trip_date,
  payment_type,
  COUNT(*)                                       AS trip_count,
  ROUND(SUM(fare_amount), 2)                     AS total_fare,
  ROUND(AVG(fare_amount), 2)                     AS avg_fare,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER
    (PARTITION BY DATE(pickup_datetime)), 1)     AS pct_of_daily_trips
FROM DQ_AGENT.KHA.SILVER
WHERE fare_amount > 0
GROUP BY DATE(pickup_datetime), payment_type
ORDER BY trip_date DESC, trip_count DESC;

-- -----------------------------------------------------------
-- 1c. Fare Distribution Buckets (for histogram/chart)
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW DQ_AGENT.MARTS.NYC_TAXI_FARE_DISTRIBUTION AS
SELECT
  CASE
    WHEN fare_amount < 5    THEN '< $5'
    WHEN fare_amount < 10   THEN '$5–$10'
    WHEN fare_amount < 20   THEN '$10–$20'
    WHEN fare_amount < 50   THEN '$20–$50'
    WHEN fare_amount < 100  THEN '$50–$100'
    ELSE '> $100'
  END                                            AS fare_bucket,
  COUNT(*)                                       AS trip_count,
  ROUND(AVG(fare_amount), 2)                     AS avg_fare_in_bucket,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM DQ_AGENT.KHA.SILVER WHERE fare_amount > 0), 1) AS pct_of_total
FROM DQ_AGENT.KHA.SILVER
WHERE fare_amount > 0
GROUP BY fare_bucket
ORDER BY MIN(fare_amount);

-- -----------------------------------------------------------
-- 1d. DQ Health Summary for NYC Taxi
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW DQ_AGENT.MARTS.NYC_TAXI_DQ_HEALTH AS
SELECT
  DATE(RUN_TIMESTAMP)                            AS check_date,
  CHECK_NAME,
  STATUS,
  ROW_COUNT,
  ISSUE_COUNT,
  ROUND(ISSUE_COUNT * 100.0 / NULLIF(ROW_COUNT, 0), 2) AS issue_pct,
  CASE
    WHEN STATUS = 'PASS' THEN '🟢 PASS'
    WHEN STATUS = 'FAIL' AND ISSUE_COUNT > 100 THEN '🔴 CRITICAL'
    ELSE '🟡 WARNING'
  END                                            AS health_label,
  RUN_TIMESTAMP
FROM DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
WHERE TABLE_NAME ILIKE '%SILVER%'
   OR TABLE_NAME ILIKE '%BRONZE%'
   OR TABLE_NAME ILIKE '%taxi%'
ORDER BY RUN_TIMESTAMP DESC;

-- =============================================================
-- SECTION 2: OpenAQ Air Quality KPIs
-- Source: RAW JSON loaded from S3 landing/openaq/
-- Strategy: Load into RAW schema first, then build MARTS views
-- =============================================================

USE SCHEMA RAW;

-- -----------------------------------------------------------
-- 2a. Raw OpenAQ table (VARIANT — stores JSON as-is)
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS DQ_AGENT.RAW.OPENAQ_RAW (
  ingest_ts       TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  source_file     VARCHAR,
  raw_data        VARIANT
);

-- -----------------------------------------------------------
-- 2b. Stage pointing to landing/openaq/
-- -----------------------------------------------------------
CREATE OR REPLACE STAGE DQ_AGENT.RAW.OPENAQ_STAGE
  STORAGE_INTEGRATION = dq_agent_s3_storage_int
  URL = 's3://dq-agent-datalake-production/landing/openaq/'
  FILE_FORMAT = (
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = FALSE
  )
  COMMENT = 'Stage for OpenAQ raw JSON files';

-- -----------------------------------------------------------
-- 2c. Load OpenAQ data from S3 into RAW table
-- -----------------------------------------------------------
COPY INTO DQ_AGENT.RAW.OPENAQ_RAW (source_file, raw_data)
FROM (
  SELECT
    METADATA$FILENAME,
    $1
  FROM @DQ_AGENT.RAW.OPENAQ_STAGE
)
FILE_FORMAT = (TYPE = 'JSON' STRIP_OUTER_ARRAY = FALSE)
ON_ERROR = CONTINUE;

-- -----------------------------------------------------------
-- 2d. Flattened OpenAQ view — one row per sensor reading
-- -----------------------------------------------------------
USE SCHEMA STAGING;

CREATE OR REPLACE VIEW DQ_AGENT.STAGING.OPENAQ_FLATTENED AS
SELECT
  r.ingest_ts,
  r.source_file,
  f.value:location_id::INTEGER         AS location_id,
  f.value:sensor_id::INTEGER           AS sensor_id,
  f.value:parameter::VARCHAR           AS parameter,
  f.value:unit::VARCHAR                AS unit,
  f.value:latest_value::FLOAT          AS pm25_value,
  TRY_TO_TIMESTAMP(
    f.value:latest_time::VARCHAR
  )                                    AS reading_time,
  f.value:coverage_pct::FLOAT          AS coverage_pct,
  CASE
    WHEN f.value:latest_value IS NULL  THEN 'NO_DATA'
    WHEN f.value:latest_value::FLOAT > 250 THEN 'HAZARDOUS'
    WHEN f.value:latest_value::FLOAT > 150 THEN 'VERY_UNHEALTHY'
    WHEN f.value:latest_value::FLOAT > 55  THEN 'UNHEALTHY'
    WHEN f.value:latest_value::FLOAT > 35  THEN 'UNHEALTHY_SENSITIVE'
    WHEN f.value:latest_value::FLOAT > 15  THEN 'MODERATE'
    ELSE 'GOOD'
  END                                  AS who_category
FROM DQ_AGENT.RAW.OPENAQ_RAW r,
LATERAL FLATTEN(INPUT => r.raw_data:results) f;

-- =============================================================
-- SECTION 3: OpenAQ MARTS KPI Views
-- =============================================================

USE SCHEMA MARTS;

-- -----------------------------------------------------------
-- 3a. PM2.5 Summary by Location
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW DQ_AGENT.MARTS.OPENAQ_LOCATION_KPI AS
SELECT
  location_id,
  parameter,
  unit,
  COUNT(*)                                       AS sensor_count,
  ROUND(AVG(pm25_value), 1)                      AS avg_pm25,
  ROUND(MAX(pm25_value), 1)                      AS max_pm25,
  ROUND(MIN(pm25_value), 1)                      AS min_pm25,
  MAX(reading_time)                              AS latest_reading,
  COUNT(CASE WHEN pm25_value IS NULL THEN 1 END) AS null_count,
  COUNT(CASE WHEN pm25_value > 15 THEN 1 END)    AS above_who_threshold,
  COUNT(CASE WHEN pm25_value > 250 THEN 1 END)   AS hazardous_count,
  MAX(who_category)                              AS worst_category,
  DATEDIFF('day', MAX(reading_time), CURRENT_TIMESTAMP()) AS days_since_last_reading
FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
WHERE pm25_value IS NOT NULL
GROUP BY location_id, parameter, unit
ORDER BY avg_pm25 DESC NULLS LAST;

-- -----------------------------------------------------------
-- 3b. AQI Category Distribution (for pie/donut chart)
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW DQ_AGENT.MARTS.OPENAQ_CATEGORY_DISTRIBUTION AS
SELECT
  who_category,
  COUNT(*)                                       AS sensor_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total,
  ROUND(AVG(pm25_value), 1)                      AS avg_pm25_in_category
FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
GROUP BY who_category
ORDER BY avg_pm25_in_category DESC NULLS LAST;

-- -----------------------------------------------------------
-- 3c. Data Freshness — how stale is each sensor
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW DQ_AGENT.MARTS.OPENAQ_FRESHNESS AS
SELECT
  location_id,
  sensor_id,
  pm25_value,
  reading_time,
  who_category,
  DATEDIFF('day', reading_time, CURRENT_TIMESTAMP())   AS days_stale,
  CASE
    WHEN reading_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())  THEN '✅ Fresh'
    WHEN reading_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())  THEN '🟡 Week old'
    WHEN reading_time >= DATEADD('day', -30, CURRENT_TIMESTAMP()) THEN '🟠 Month old'
    ELSE '🔴 Stale (> 30 days)'
  END                                                  AS freshness_label
FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
ORDER BY reading_time DESC NULLS LAST;

-- -----------------------------------------------------------
-- 3d. WHO Threshold Breach Summary (for SNS alert trigger)
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW DQ_AGENT.MARTS.OPENAQ_WHO_BREACHES AS
SELECT
  COUNT(*)                                       AS total_sensors,
  COUNT(CASE WHEN pm25_value IS NOT NULL THEN 1 END)    AS sensors_with_data,
  COUNT(CASE WHEN pm25_value > 15 THEN 1 END)           AS above_who_threshold,
  COUNT(CASE WHEN pm25_value > 250 THEN 1 END)          AS hazardous_readings,
  ROUND(AVG(CASE WHEN pm25_value IS NOT NULL
    THEN pm25_value END), 1)                     AS overall_avg_pm25,
  ROUND(COUNT(CASE WHEN pm25_value > 15 THEN 1 END) * 100.0
    / NULLIF(COUNT(CASE WHEN pm25_value IS NOT NULL THEN 1 END), 0), 1) AS pct_above_who,
  CURRENT_TIMESTAMP()                            AS summary_ts
FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED;

-- =============================================================
-- SECTION 4: Combined DQ Health Dashboard View
-- Used by QuickSight + Google Sheets
-- =============================================================

USE SCHEMA MARTS;

CREATE OR REPLACE VIEW DQ_AGENT.MARTS.PIPELINE_HEALTH_SUMMARY AS
SELECT
  'NYC_TAXI'                                     AS dataset,
  COUNT(*)                                       AS total_checks,
  COUNT(CASE WHEN STATUS = 'PASS' THEN 1 END)    AS passed,
  COUNT(CASE WHEN STATUS = 'FAIL' THEN 1 END)    AS failed,
  ROUND(COUNT(CASE WHEN STATUS = 'PASS' THEN 1 END) * 100.0
    / NULLIF(COUNT(*), 0), 1)                    AS pass_rate_pct,
  MAX(RUN_TIMESTAMP)                             AS last_run_ts,
  DATEDIFF('minute', MAX(RUN_TIMESTAMP),
    CURRENT_TIMESTAMP())                         AS minutes_since_last_run
FROM DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG

UNION ALL

SELECT
  'OPENAQ'                                       AS dataset,
  1                                              AS total_checks,
  CASE WHEN pct_above_who < 50 THEN 1 ELSE 0 END AS passed,
  CASE WHEN pct_above_who >= 50 THEN 1 ELSE 0 END AS failed,
  ROUND(100 - pct_above_who, 1)                  AS pass_rate_pct,
  summary_ts                                     AS last_run_ts,
  DATEDIFF('minute', summary_ts,
    CURRENT_TIMESTAMP())                         AS minutes_since_last_run
FROM DQ_AGENT.MARTS.OPENAQ_WHO_BREACHES;

-- =============================================================
-- SECTION 5: Verify all MARTS views created
-- =============================================================

SHOW VIEWS IN SCHEMA DQ_AGENT.MARTS;

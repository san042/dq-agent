-- =============================================================
-- 14_openaq_dq_checks.sql
-- DQ Agent — OpenAQ Air Quality DQ Check Procedures
-- Version: FINAL (May 20, 2026)
--
-- Adds 3 OpenAQ DQ checks to existing pipeline:
--   check_openaq_nulls()          → null % on pm25_value
--   check_openaq_freshness()      → readings older than 30 days
--   check_openaq_who_threshold()  → PM2.5 WHO limit breaches
--
-- Updates run_all_dq_checks() to include all 7 checks:
--   NYC Taxi (4): check_nulls, check_fare_range,
--                 check_schema, check_geo_bounds
--   OpenAQ  (3): check_openaq_nulls, check_openaq_freshness,
--                check_openaq_who_threshold
--
-- Source:  DQ_AGENT.STAGING.OPENAQ_FLATTENED
-- Output:  DQ_MONITORING.DQ_AUDIT_LOG
--          DQ_MONITORING.DQ_METRICS
--          DQ_MONITORING.DQ_VIOLATIONS
-- Auto-exported to S3 via EXPORT_DQ_RESULTS_TASK
--
-- Key syntax rules (Snowflake scripting):
--   - Use LET RESULTSET + CURSOR for all variable assignments
--   - Use lowercase column names in INSERT target list
--   - Use SELECT (not VALUES) for OBJECT_CONSTRUCT with bound vars
--   - DQ_VIOLATIONS columns: run_id, rule_name, violation_details
-- =============================================================

USE ROLE SYSADMIN;
USE DATABASE DQ_AGENT;
USE SCHEMA DQ_MONITORING;
USE WAREHOUSE COMPUTE_WH;

-- =============================================================
-- PROCEDURE 1: check_openaq_nulls()
-- Checks null % on pm25_value, location_id, sensor_id
-- FAIL threshold: pm25_value null % > 30%
-- =============================================================

CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.check_openaq_nulls()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
  total_rows    NUMBER DEFAULT 0;
  null_pm25     NUMBER DEFAULT 0;
  null_location NUMBER DEFAULT 0;
  null_sensor   NUMBER DEFAULT 0;
  null_pct      FLOAT  DEFAULT 0;
BEGIN
  LET r1 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED);
  LET c1 CURSOR FOR r1;
  OPEN c1; FETCH c1 INTO total_rows; CLOSE c1;

  LET r2 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE pm25_value IS NULL);
  LET c2 CURSOR FOR r2;
  OPEN c2; FETCH c2 INTO null_pm25; CLOSE c2;

  LET r3 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE location_id IS NULL);
  LET c3 CURSOR FOR r3;
  OPEN c3; FETCH c3 INTO null_location; CLOSE c3;

  LET r4 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE sensor_id IS NULL);
  LET c4 CURSOR FOR r4;
  OPEN c4; FETCH c4 INTO null_sensor; CLOSE c4;

  null_pct := COALESCE((:null_pm25 / NULLIF(:total_rows, 0)) * 100, 0);

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
    (table_name, check_name, status, row_count, issue_count, details)
  SELECT
    'OPENAQ_FLATTENED', 'check_openaq_nulls',
    CASE WHEN :null_pct > 30 THEN 'FAIL' ELSE 'PASS' END,
    :total_rows, :null_pm25,
    OBJECT_CONSTRUCT(
      'null_pm25_count',     :null_pm25,
      'null_location_count', :null_location,
      'null_sensor_count',   :null_sensor,
      'null_pm25_pct',       ROUND(:null_pct, 2),
      'threshold_pct',       30
    );

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_METRICS
    (table_name, metric_name, metric_value, threshold, passed)
  SELECT 'OPENAQ_FLATTENED', 'null_pm25_pct',
    ROUND(:null_pct, 2), 30, (:null_pct <= 30)
  UNION ALL
  SELECT 'OPENAQ_FLATTENED', 'null_location_pct',
    ROUND(COALESCE(:null_location / NULLIF(:total_rows, 0) * 100, 0), 2), 5, (:null_location = 0)
  UNION ALL
  SELECT 'OPENAQ_FLATTENED', 'null_sensor_pct',
    ROUND(COALESCE(:null_sensor / NULLIF(:total_rows, 0) * 100, 0), 2), 5, (:null_sensor = 0);

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS
    (run_id, rule_name, violation_details)
  SELECT
    'check_openaq_nulls', 'null_pm25_check',
    OBJECT_CONSTRUCT(
      'location_id', location_id,
      'sensor_id',   sensor_id,
      'issue',       'pm25_value is null'
    )
  FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
  WHERE pm25_value IS NULL;

  RETURN 'check_openaq_nulls: ' ||
    CASE WHEN :null_pct > 30 THEN 'FAIL' ELSE 'PASS' END ||
    ' | null_pm25=' || :null_pm25 || '/' || :total_rows ||
    ' (' || ROUND(:null_pct, 1) || '%)';
END;
$$;

-- =============================================================
-- PROCEDURE 2: check_openaq_freshness()
-- Checks: readings older than 30 days (stale)
-- FAIL threshold: > 50% of readings are stale
-- =============================================================

CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.check_openaq_freshness()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
  total_rows  NUMBER DEFAULT 0;
  stale_count NUMBER DEFAULT 0;
  fresh_count NUMBER DEFAULT 0;
  null_time   NUMBER DEFAULT 0;
  stale_pct   FLOAT  DEFAULT 0;
BEGIN
  LET r1 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED);
  LET c1 CURSOR FOR r1;
  OPEN c1; FETCH c1 INTO total_rows; CLOSE c1;

  LET r2 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE reading_time < DATEADD('day', -30, CURRENT_TIMESTAMP())
       OR reading_time IS NULL);
  LET c2 CURSOR FOR r2;
  OPEN c2; FETCH c2 INTO stale_count; CLOSE c2;

  LET r3 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE reading_time >= DATEADD('day', -30, CURRENT_TIMESTAMP()));
  LET c3 CURSOR FOR r3;
  OPEN c3; FETCH c3 INTO fresh_count; CLOSE c3;

  LET r4 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE reading_time IS NULL);
  LET c4 CURSOR FOR r4;
  OPEN c4; FETCH c4 INTO null_time; CLOSE c4;

  stale_pct := COALESCE((:stale_count / NULLIF(:total_rows, 0)) * 100, 0);

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
    (table_name, check_name, status, row_count, issue_count, details)
  SELECT
    'OPENAQ_FLATTENED', 'check_openaq_freshness',
    CASE WHEN :stale_pct > 50 THEN 'FAIL' ELSE 'PASS' END,
    :total_rows, :stale_count,
    OBJECT_CONSTRUCT(
      'stale_count',      :stale_count,
      'fresh_count',      :fresh_count,
      'null_time',        :null_time,
      'stale_pct',        ROUND(:stale_pct, 2),
      'threshold_pct',    50,
      'stale_after_days', 30
    );

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_METRICS
    (table_name, metric_name, metric_value, threshold, passed)
  SELECT 'OPENAQ_FLATTENED', 'stale_reading_pct',
    ROUND(:stale_pct, 2), 50, (:stale_pct <= 50)
  UNION ALL
  SELECT 'OPENAQ_FLATTENED', 'fresh_sensor_count',
    :fresh_count, 1, (:fresh_count >= 1)
  UNION ALL
  SELECT 'OPENAQ_FLATTENED', 'null_reading_time',
    :null_time, 0, (:null_time = 0);

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS
    (run_id, rule_name, violation_details)
  SELECT
    'check_openaq_freshness', 'freshness_check',
    OBJECT_CONSTRUCT(
      'location_id',  location_id,
      'sensor_id',    sensor_id,
      'reading_time', TO_VARCHAR(reading_time),
      'days_stale',   DATEDIFF('day', reading_time, CURRENT_TIMESTAMP()),
      'issue',        'reading older than 30 days'
    )
  FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
  WHERE reading_time < DATEADD('day', -30, CURRENT_TIMESTAMP())
     OR reading_time IS NULL;

  RETURN 'check_openaq_freshness: ' ||
    CASE WHEN :stale_pct > 50 THEN 'FAIL' ELSE 'PASS' END ||
    ' | stale=' || :stale_count || '/' || :total_rows ||
    ' (' || ROUND(:stale_pct, 1) || '%)';
END;
$$;

-- =============================================================
-- PROCEDURE 3: check_openaq_who_threshold()
-- Checks: PM2.5 > 15 µg/m³ (WHO annual mean limit)
--         PM2.5 > 250 µg/m³ (hazardous)
-- FAIL threshold: > 50% of readings breach WHO limit
-- =============================================================

CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.check_openaq_who_threshold()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
  total_readings NUMBER DEFAULT 0;
  above_who      NUMBER DEFAULT 0;
  hazardous      NUMBER DEFAULT 0;
  breach_pct     FLOAT  DEFAULT 0;
  avg_pm25       FLOAT  DEFAULT 0;
BEGIN
  LET r1 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE pm25_value IS NOT NULL);
  LET c1 CURSOR FOR r1;
  OPEN c1; FETCH c1 INTO total_readings; CLOSE c1;

  LET r2 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE pm25_value > 15);
  LET c2 CURSOR FOR r2;
  OPEN c2; FETCH c2 INTO above_who; CLOSE c2;

  LET r3 RESULTSET := (SELECT COUNT(*) AS cnt FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
    WHERE pm25_value > 250);
  LET c3 CURSOR FOR r3;
  OPEN c3; FETCH c3 INTO hazardous; CLOSE c3;

  LET r4 RESULTSET := (SELECT ROUND(AVG(pm25_value), 2) AS avg_val
    FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED WHERE pm25_value IS NOT NULL);
  LET c4 CURSOR FOR r4;
  OPEN c4; FETCH c4 INTO avg_pm25; CLOSE c4;

  breach_pct := COALESCE((:above_who / NULLIF(:total_readings, 0)) * 100, 0);

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
    (table_name, check_name, status, row_count, issue_count, details)
  SELECT
    'OPENAQ_FLATTENED', 'check_openaq_who_threshold',
    CASE WHEN :breach_pct > 50 THEN 'FAIL' ELSE 'PASS' END,
    :total_readings, :above_who,
    OBJECT_CONSTRUCT(
      'above_who_threshold', :above_who,
      'hazardous_count',     :hazardous,
      'breach_pct',          ROUND(:breach_pct, 2),
      'avg_pm25',            :avg_pm25,
      'who_threshold',       15,
      'hazardous_threshold', 250
    );

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_METRICS
    (table_name, metric_name, metric_value, threshold, passed)
  SELECT 'OPENAQ_FLATTENED', 'who_breach_pct',
    ROUND(:breach_pct, 2), 80, (:breach_pct <= 80)
  UNION ALL
  SELECT 'OPENAQ_FLATTENED', 'hazardous_count',
    :hazardous, 0, (:hazardous = 0)
  UNION ALL
  SELECT 'OPENAQ_FLATTENED', 'avg_pm25_ug_m3',
    :avg_pm25, 15, (:avg_pm25 <= 15);

  INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS
    (run_id, rule_name, violation_details)
  SELECT
    'check_openaq_who_threshold', 'who_threshold_check',
    OBJECT_CONSTRUCT(
      'location_id',  location_id,
      'sensor_id',    sensor_id,
      'pm25_value',   pm25_value,
      'who_category', who_category,
      'reading_time', TO_VARCHAR(reading_time),
      'issue',        'PM2.5 exceeds WHO threshold of 15'
    )
  FROM DQ_AGENT.STAGING.OPENAQ_FLATTENED
  WHERE pm25_value > 15;

  RETURN 'check_openaq_who_threshold: ' ||
    CASE WHEN :breach_pct > 50 THEN 'FAIL' ELSE 'PASS' END ||
    ' | above_who=' || :above_who || '/' || :total_readings ||
    ' (' || ROUND(:breach_pct, 1) || '%)' ||
    ' | hazardous=' || :hazardous ||
    ' | avg_pm25=' || :avg_pm25;
END;
$$;

-- =============================================================
-- UPDATE run_all_dq_checks() — 7 total checks
-- NYC Taxi (4) + OpenAQ (3)
-- =============================================================

CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.run_all_dq_checks()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
  -- NYC Taxi checks
  CALL DQ_AGENT.DQ_MONITORING.check_nulls();
  CALL DQ_AGENT.DQ_MONITORING.check_fare_range();
  CALL DQ_AGENT.DQ_MONITORING.check_schema();
  CALL DQ_AGENT.DQ_MONITORING.check_geo_bounds();
  -- OpenAQ checks
  CALL DQ_AGENT.DQ_MONITORING.check_openaq_nulls();
  CALL DQ_AGENT.DQ_MONITORING.check_openaq_freshness();
  CALL DQ_AGENT.DQ_MONITORING.check_openaq_who_threshold();
  RETURN 'All DQ checks complete — NYC Taxi (4) + OpenAQ (3).';
END;
$$;

-- =============================================================
-- VERIFY
-- =============================================================

SHOW PROCEDURES IN SCHEMA DQ_AGENT.DQ_MONITORING;

-- Manual test (uncomment to run):
-- CALL DQ_AGENT.DQ_MONITORING.run_all_dq_checks();

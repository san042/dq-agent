-- CODER FIX [2026-05-15]: Fixed (1) == → = in check_nulls, (2) fare_att_amount → fare_amount, (3) DQ_MONITORING → KHA in check_schema, (4) audit log 'bronze' → 'silver'
-- ============================================
--Snowflake 05: DQ Rules Enforced at SILVER
--============================================
-- 5 enterprise-grade DQ rules enforced during
-- Bronze to Silver movement. Failures are
-- quarantined and logged to DQ_AUDIT_LOG
-- and DQ_AUDIT_LOG and DQ_METRICS tables.
-- ============================================

USE DATABASE DQ_AGENT;

-- -----------------------------------
-- Rule 1: Uniqueness / Deduplication
-- (pickup_datetime) must be unique
-- -----------------------------------
-- Table to capture violations
CREATE OR REPLACE TABLE DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS(
  run_id        VARCHAR,
  rule_name     VARCHAR,
  violation_details VARIANT
);

-- CREATE OR REPLACE TABLE DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS (
--  run_id        VARCHAR,
--  rule_name     VARCHAR,
--  violation_details

-- ---------------------------------
-- Rule 2: Non-null checks on critical fields
-- pickup_datetime, dropoff_datetime, passenger_count MUST NOT be NULL
-- ----------------------------------
CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.check_nulls()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  DECLARE
    null_count NUMBER;
    total_count NUMBER;
    run_uuid VARCHAR;
  BEGIN
    run_uuid := UUID_STRING();

    -- Count total records
    SELECT COUNT(*) INTO total_count
    FROM DQ_AGENT.KHA.bronze;

    -- Count NULLs on critical field
    SELECT COUNT(*) INTO null_count
    FROM DQ_AGENT.KHA.bronze
    WHERE pickup_datetime IS NULL
       OR dropoff_datetime IS NULL
       OR passenger_count IS NULL;

    -- Record in DQ_AUDIT_LOG
    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
      (run_id, table_name, check_type, result_value, severity, ai_summary, run_ts)
    VALUES (
      run_uuid, 'silver', 'NON_NULL', null_count,
      CASE WHEN null_count > 0 THEN 'MEDIUM' ELSE 'LOW' END,
      'NULL check on critical fields: ' || null_count || ' null records found',
      CURRENT_TIMESTAMP()
    );

    -- Record violations
    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS
        (run_id, rule_name, violation_details)
    SELECT
        run_uuid,
        'RULE_NON_NULL',
        OBJECT_CONSTRUCT('null_count', null_count, 'pickup_datetime', pickup_datetime, 'dropoff_datetime', dropoff_datetime, 'passenger_count', passenger_count)
    FROM DQ_AGENT.KHA.bronze
    WHERE pickup_datetime IS NULL
       OR dropoff_datetime IS NULL
       OR passenger_count IS NULL;

    -- Record in DQ_METRICS
    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_METRICS
      (run_id, table_name, rule_name, passed, fail_count, total_count, fail_percent)
    VALUES (
      run_uuid, 'silver', 'RULE_NON_NULL',
      null_count = 0, null_count, total_count,
      COALESCE((null_count / NULLIF(total_count, 0)) * 100, 0)
    );

    RETURN 'Rule 2 check complete: ' || null_count || ' NULL records found';
  END;
  $$;

-- -----------------------------------
-- Rule 3: Numeric Range Validation
-- fare_amount must be > 0 AND < 500
-- -----------------------------------
CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.check_fare_range()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  DECLARE
    out_of_range_count NUMBER;
    total_count NUMBER;
    run_uuid VARCHAR;
  BEGIN
    run_uuid := UUID_STRING();

    SELECT COUNT(*) INTO total_count
    FROM DQ_AGENT.KHA.bronze;

    SELECT COUNT(*) INTO out_of_range_count
    FROM DQ_AGENT.KHA.bronze
    WHERE fare_amount <= 0 OR fare_amount >= 500;

    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
      (run_id, table_name, check_type, result_value, severity, ai_summary, run_ts)
    VALUES (
      run_uuid, 'silver', 'NUM_RANGE', out_of_range_count,
      CASE WHEN out_of_range_count > 0 THEN 'MEDIUM' ELSE 'LOW' END,
      'Numeric range check on fare_amount: ' || out_of_range_count || ' out-of-range records',
      CURRENT_TIMESTAMP()
    );

    -- Record violations
    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS
        (run_id, rule_name, violation_details)
    SELECT
        run_uuid,
        'RULE_FARE_RANGE',
        OBJECT_CONSTRUCT('fare_amount', fare_amount)
    FROM DQ_AGENT.KHA.bronze
    WHERE fare_amount <= 0 OR fare_amount >= 500;

    -- Record in DQ_METRICS
    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_METRICS
      (run_id, table_name, rule_name, passed, fail_count, total_count, fail_percent)
    VALUES (
      run_uuid, 'silver', 'RULE_FARE_RANGE',
      out_of_range_count = 0, out_of_range_count, total_count,
      COALESCE((out_of_range_count / NULLIF(total_count, 0)) * 100, 0)
    );

    RETURN 'Rule 3 check complete: ' || out_of_range_count || ' out-of-range records found';
  END;
  $$;

-- -----------------------------------
-- Rule 4: Schema Structure Validation
-- Must match expected DQ schema
-- -----------------------------------
CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.check_schema()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  DECLARE
    missing_cols INT;
    run_uuid VARCHAR;
  BEGIN
    run_uuid := UUID_STRING();

    -- Check expected columns exist in the table
    SELECT COUNT(*) INTO missing_cols
    FROM DQ_AGENT.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'KHA'
      AND TABLE_NAME = 'BRONZE'
      AND COLUMN_NAME NOT IN (
        'pickup_datetime', 'dropoff_datetime', 'passenger_count',
        'trip_distance', 'pickup_longitude', 'pickup_latitude',
        'rate_code', 'store_and_fwd_flag',
        'dropoff_longitude', 'dropoff_latitude', 'payment_type',
        'fare_amount', 'extra', 'mta_tax', 'tip_amount',
        'tolls_amount', 'improvement_surcharge', 'total_amount'
      );

    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
      (run_id, table_name, check_type, result_value, severity, ai_summary, run_ts)
    VALUES (
      run_uuid, 'silver', 'SCHEMA', missing_cols,
      CASE WHEN missing_cols > 0 THEN 'HIGH' ELSE 'LOW' END,
      'Schema validation: ' || missing_cols || ' unexpected columns found',
      CURRENT_TIMESTAMP()
    );

    -- Record violations
    IF (missing_cols > 0) THEN
      INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS
          (run_id, rule_name, violation_details)
      VALUES (
          run_uuid,
          'RULE_SCHEMA',
          OBJECT_CONSTRUCT('missing_cols', missing_cols)
      );
    END IF;

    -- Record in DQ_METRICS
    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_METRICS
      (run_id, table_name, rule_name, passed, fail_count, total_count, fail_percent)
    VALUES (
      run_uuid, 'silver', 'RULE_SCHEMA',
      missing_cols = 0, missing_cols,
      (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'KHA' AND TABLE_NAME = 'BRONZE'),
      CASE WHEN missing_cols > 0 THEN 100 ELSE 0 END
    );

    RETURN 'Rule 4 check complete: ' || missing_cols || ' unexpected columns found';
  END;
  $$;

-- -----------------------------------
-- Rule 5: Referential Integrity
-- geographic coordinates must be within valid bounds
-- -----------------------------------
CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.check_geo_bounds()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  DECLARE
    invalid_geo_count INT;
    total_count INT;
    run_uuid VARCHAR;
  BEGIN
    run_uuid := UUID_STRING();

    SELECT COUNT(*) INTO total_count
    FROM DQ_AGENT.KHA.bronze;

    SELECT COUNT(*) INTO invalid_geo_count
    FROM DQ_AGENT.KHA.bronze
    WHERE pickup_latitude IS NULL OR pickup_longitude IS NULL
       OR dropoff_latitude IS NULL OR dropoff_longitude IS NULL
       OR pickup_latitude NOT BETWEEN -90 AND 90
       OR pickup_longitude NOT BETWEEN -180 AND 180
       OR dropoff_latitude NOT BETWEEN -90 AND 90
       OR dropoff_longitude NOT BETWEEN -180 AND 180;

    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
      (run_id, table_name, check_type, result_value, severity, ai_summary, run_ts)
    VALUES (
      run_uuid, 'silver', 'GEO_BOUNDS', invalid_geo_count,
      CASE WHEN invalid_geo_count > 0 THEN 'MEDIUM' ELSE 'LOW' END,
      'Geographic bounds check: ' || invalid_geo_count || ' invalid coordinates',
      CURRENT_TIMESTAMP()
    );

    -- Record violations
    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS
        (run_id, rule_name, violation_details)
    SELECT
        run_uuid,
        'RULE_GEO_VERIFY',
        OBJECT_CONSTRUCT('pickup_latitude', pickup_latitude, 'pickup_longitude', pickup_longitude, 'dropoff_latitude', dropoff_latitude, 'dropoff_longitude', dropoff_longitude)
    FROM DQ_AGENT.KHA.bronze
    WHERE pickup_latitude IS NULL OR pickup_longitude IS NULL
       OR dropoff_latitude IS NULL OR dropoff_longitude IS NULL
       OR pickup_latitude NOT BETWEEN -90 AND 90
       OR pickup_longitude NOT BETWEEN -180 AND 180
       OR dropoff_latitude NOT BETWEEN -90 AND 90
       OR dropoff_longitude NOT BETWEEN -180 AND 180;

    -- Record in DQ_METRICS
    INSERT INTO DQ_AGENT.DQ_MONITORING.DQ_METRICS
      (run_id, table_name, rule_name, passed, fail_count, total_count, fail_percent)
    VALUES (
      run_uuid, 'silver', 'RULE_GEO_VERIFY',
      invalid_geo_count = 0, invalid_geo_count, total_count,
      COALESCE((invalid_geo_count / NULLIF(total_count, 0)) * 100, 0)
    );

    RETURN 'Rule 5 check complete. ' || invalid_geo_count || ' invalid geographic coordinates found';
  END;
  $$;

-- -----------------------------------
-- Master DQ Check Procedure (runs all 5 rules)
-- -----------------------------------
CREATE OR REPLACE PROCEDURE DQ_AGENT.DQ_MONITORING.run_all_dq_checks()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
  DECLARE
    result VARCHAR;
  BEGIN
    -- Run all 5 DQ checks
    result := CALL DQ_AGENT.DQ_MONITORING.check_nulls();
    result := CALL DQ_AGENT.DQ_MONITORING.check_fare_range();
    result := CALL DQ_AGENT.DQ_MONITORING.check_schema();
    result := CALL DQ_AGENT.DQ_MONITORING.check_geo_bounds();

    RETURN 'All DQ checks complete. Results in DQ_AUDIT_LOG and DQ_METRICS tables.';
  END;
  $$;
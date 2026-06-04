-- ===========================================
-- Snowflake 08: QuickSight DQ Chart Source
-- ===========================================
USE DATABASE DQ_AGENT;

-- View: Daily DQ Health Score
CREATE OR REPLACE VIEW DQ_AGENT.KHA.dq_health_score AS
SELECT
  TO_CHAR(run_timestamp, 'YYYY-MM-DD') as metric_date,
  run_timestamp,
  table_name,
  metric_name,
  COUNT(*) as total_checks,
  SUM(CASE WHEN passed = TRUE THEN 1 ELSE 0 END) as passed_checks,
  SUM(CASE WHEN passed = FALSE THEN 1 ELSE 0 END) as failed_checks,
  AVG(CASE WHEN passed = TRUE THEN 100 ELSE 0 END) as aggregate_dq_score,
  ROUND(SUM(CASE WHEN passed = FALSE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as fail_percent
FROM DQ_AGENT.DQ_MONITORING.DQ_METRICS
GROUP BY TO_CHAR(run_timestamp, 'YYYY-MM-DD'), run_timestamp, table_name, metric_name;

-- View: DQ Violations by Type
CREATE OR REPLACE VIEW DQ_AGENT.KHA.dq_violations_by_type AS
SELECT
  check_name,
  status as severity,
  COUNT(*) as violation_count,
  SUM(issue_count) as total_failed_records,
  MAX(run_timestamp) as last_violation
FROM DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG
WHERE status = 'FAIL'
GROUP BY check_name, status;

-- View: QuickSight Gold Summary Table
CREATE OR REPLACE VIEW DQ_AGENT.KHA.qs_gold_summary AS
SELECT
  pickup_datetime, dropoff_datetime, passenger_count,
  trip_distance, pickup_longitude, pickup_latitude,
  rate_code, dropoff_longitude, dropoff_latitude,
  payment_type, fare_amount, extra, mta_tax,
  tip_amount, tolls_amount, improvement_surcharge, total_amount
FROM DQ_AGENT.KHA.silver;

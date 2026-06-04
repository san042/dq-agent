-- ===========================================
-- Snowflake 11: QuickSight Matrix Template
-- ===========================================
-- Matrix template for QuickSight charts
-- (row-level DQ breakdown per table)
-- ===========================================

USE DATABASE DQ_AGENT;

-- View: qs_gold_matrix (single-row DQ summary for QuickSight)
CREATE OR REPLACE VIEW DQ_AGENT.KHA.qs_gold_matrix AS
SELECT
  'DQ Score' as metric_category,
  SUM(CASE WHEN passed = TRUE THEN 1 ELSE 0 END) / COUNT(*)::FLOAT as pass_rate,
  (1 - (SUM(CASE WHEN passed = TRUE THEN 1 ELSE 0 END) / COUNT(*)::FLOAT))::FLOAT as fail_rate,
  COUNT(*) as total_rules
FROM DQ_AGENT.DQ_MONITORING.DQ_METRICS
WHERE run_timestamp >= CURRENT_DATE() - INTERVAL '7 DAYS';

-- View: dq_trend_7d (hourly DQ trend for QuickSight time series)
CREATE OR REPLACE VIEW DQ_AGENT.KHA.dq_trend_7d AS
SELECT
  TO_CHAR(run_timestamp, 'YYYY-MM-DD HH:00') as time_bucket,
  table_name,
  metric_name,
  COUNT(*) as total_checks,
  SUM(CASE WHEN passed = TRUE THEN 1 ELSE 0 END) as pass_count,
  SUM(CASE WHEN passed = FALSE THEN 1 ELSE 0 END) as fail_count,
  ROUND(SUM(CASE WHEN passed = FALSE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as avg_fail_percent
FROM DQ_AGENT.DQ_MONITORING.DQ_METRICS
WHERE run_timestamp >= CURRENT_DATE() - INTERVAL '7 DAYS'
GROUP BY TO_CHAR(run_timestamp, 'YYYY-MM-DD HH:00'), table_name, metric_name;

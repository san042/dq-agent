-- ===========================================
-- Snowflake 07: Billing & Operational DTL Views
-- ===========================================
-- Silver Layer Views created for operational reporting
-- ===========================================
USE DATABASE DQ_AGENT;

-- View: billing_summary (monthly aggregated billing reports)
CREATE OR REPLACE VIEW DQ_AGENT.KHA.billing_summary AS
SELECT
  TO_CHAR(pickup_datetime, 'YYYY-MM') as billing_month,
  COUNT(*) as total_trips,
  SUM(fare_amount) as total_fare,
  SUM(extra) as total_extras,
  SUM(mta_tax) as total_mta_tax,
  SUM(tip_amount) as total_tips,
  SUM(tolls_amount) as total_tolls,
  SUM(improvement_surcharge) as total_improvements,
  SUM(total_amount) as grand_total,
  AVG(fare_amount) as avg_fare,
  AVG(total_amount) as avg_total
FROM DQ_AGENT.KHA.silver
GROUP BY TO_CHAR(pickup_datetime, 'YYYY-MM');

-- View: operational_reporting (daily summary with metrics)
CREATE OR REPLACE VIEW DQ_AGENT.KHA.operational_reporting AS
SELECT
  TO_CHAR(pickup_datetime, 'YYYY-MM-DD') as reporting_date,
  COUNT(*) as daily_trips,
  SUM(fare_amount) as daily_fare,
  AVG(passenger_count) as avg_passengers,
  AVG(trip_distance) as avg_trip_distance,
  MAX(total_amount) as max_fare,
  MIN(total_amount) AS min_fare,
  SUM(CASE WHEN payment_type = 'CARD' THEN 1 ELSE 0 END) as card_payments,
  SUM(CASE WHEN payment_type = 'CASH' THEN 1 ELSE 0 END) as cash_payments
FROM DQ_AGENT.KHA.silver
GROUP BY TO_CHAR(pickup_datetime, 'YYYY-MM-DD');
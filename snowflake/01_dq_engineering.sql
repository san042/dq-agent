-- ============================================
-- Snowflake 01: DQ Engineering — DB + Schemas + DQ Tables
-- ============================================
-- Creates DQ_AGENT database, KHA + DQ_MONITORING schemas,
-- and DQ_AUDIT_LOG + DQ_METRICS + DQ_VIOLATIONS tables.
-- ============================================

-- Step 1: Create Database + Schemas
CREATE DATABASE IF NOT EXISTS DQ_AGENT;
CREATE SCHEMA IF NOT EXISTS DQ_AGENT.KHA;
CREATE SCHEMA IF NOT EXISTS DQ_AGENT.DQ_MONITORING;

-- Step 2: DQ_AUDIT_LOG Table
CREATE TABLE IF NOT EXISTS DQ_AGENT.DQ_MONITORING.DQ_AUDIT_LOG (
  log_id        NUMBER AUTOINCREMENT PRIMARY KEY,
  run_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  table_name    VARCHAR(100),
  check_name    VARCHAR(100),
  status        VARCHAR(10),
  row_count     NUMBER,
  issue_count   NUMBER,
  details       VARIANT
);

-- Step 3: DQ_METRICS Table
CREATE TABLE IF NOT EXISTS DQ_AGENT.DQ_MONITORING.DQ_METRICS (
  metric_id     NUMBER AUTOINCREMENT PRIMARY KEY,
  run_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  table_name    VARCHAR(100),
  metric_name   VARCHAR(100),
  metric_value  FLOAT,
  threshold     FLOAT,
  passed        BOOLEAN
);

-- Step 4: DQ_VIOLATIONS Table
CREATE TABLE IF NOT EXISTS DQ_AGENT.DQ_MONITORING.DQ_VIOLATIONS (
  violation_id      NUMBER AUTOINCREMENT PRIMARY KEY,
  detected_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  table_name        VARCHAR(100),
  check_name        VARCHAR(100),
  violation_details VARIANT
);

-- Confirm tables created
SELECT TABLE_SCHEMA, TABLE_NAME
FROM DQ_AGENT.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'DQ_MONITORING'
ORDER BY TABLE_NAME;

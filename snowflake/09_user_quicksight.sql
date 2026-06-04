-- ===========================================
-- Snowflake 09: QuickSight BI_USER (RSA Key Pair Auth)
-- STATUS: DEFERRED
-- Reason: Requires ACCOUNTADMIN role for CREATE ROLE/USER.
--         PAT connection (dq-agent-pat) is restricted session.
--         Run manually via Snowflake UI or ACCOUNTADMIN session.
-- Pending:
--   1. Generate RSA key pair via scripts/openssl_gen_keys.sh
--   2. Replace YOUR_RSA_PUBLIC_KEY_HERE with actual public key
--   3. Fix schemas: DQ_AGENT.GOLD → DQ_AGENT.KHA
--   4. Run via Snowflake worksheet as ACCOUNTADMIN
-- ===========================================
USE ROLE ACCOUNTADMIN;
USE DATABASE DQ_AGENT;

CREATE OR REPLACE USER quicksight_bi_user
  LOGIN_NAME = 'quicksight_bi_user'
  DISPLAY_NAME = 'QuickSight BI User'
  MUST_CHANGE_PASSWORD = FALSE
  DISABLED = FALSE
  RSA_PUBLIC_KEY = 'YOUR_RSA_PUBLIC_KEY_HERE';

CREATE OR REPLACE ROLE quicksight_bi_role;

GRANT USAGE ON DATABASE DQ_AGENT TO ROLE quicksight_bi_role;
GRANT USAGE ON SCHEMA DQ_AGENT.KHA TO ROLE quicksight_bi_role;
GRANT USAGE ON SCHEMA DQ_AGENT.DQ_MONITORING TO ROLE quicksight_bi_role;
GRANT SELECT ON ALL TABLES IN SCHEMA DQ_AGENT.KHA TO ROLE quicksight_bi_role;
GRANT SELECT ON ALL VIEWS IN SCHEMA DQ_AGENT.KHA TO ROLE quicksight_bi_role;
GRANT ROLE quicksight_bi_role TO USER quicksight_bi_user;
ALTER USER quicksight_bi_user SET DEFAULT_ROLE = quicksight_bi_role;

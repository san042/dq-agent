-- ===========================================
-- Snowflake 10: Julius AI USER (Gold Only)
-- STATUS: DEFERRED
-- Reason: Requires ACCOUNTADMIN role for CREATE ROLE/USER.
--         PAT connection (dq-agent-pat) is restricted session.
--         Run manually via Snowflake UI or ACCOUNTADMIN session.
-- Pending:
--   1. Fix schemas: DQ_AGENT.GOLD → DQ_AGENT.KHA
--   2. Fix views grant: DQ_MONITORING → DQ_AGENT.KHA
--   3. Run via Snowflake worksheet as ACCOUNTADMIN
-- ===========================================
USE ROLE ACCOUNTADMIN;
USE DATABASE DQ_AGENT;

CREATE OR REPLACE USER julius_ai_user
  LOGIN_NAME = 'julius_ai_user'
  DISPLAY_NAME = 'Julius AI User'
  MUST_CHANGE_PASSWORD = FALSE
  DISABLED = FALSE;

CREATE OR REPLACE ROLE julius_ai_role;

GRANT USAGE ON DATABASE DQ_AGENT TO ROLE julius_ai_role;
GRANT USAGE ON SCHEMA DQ_AGENT.KHA TO ROLE julius_ai_role;
GRANT USAGE ON SCHEMA DQ_AGENT.DQ_MONITORING TO ROLE julius_ai_role;
GRANT SELECT ON ALL TABLES IN SCHEMA DQ_AGENT.KHA TO ROLE julius_ai_role;
GRANT SELECT ON ALL VIEWS IN SCHEMA DQ_AGENT.KHA TO ROLE julius_ai_role;
GRANT ROLE julius_ai_role TO USER julius_ai_user;
ALTER USER julius_ai_user SET DEFAULT_ROLE = julius_ai_role;

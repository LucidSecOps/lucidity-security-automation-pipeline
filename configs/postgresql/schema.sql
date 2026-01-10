-- =============================================================================
-- Security Automation Pipeline - PostgreSQL Schema
-- =============================================================================
-- 
-- This schema creates the necessary tables for storing enriched Wazuh alerts
-- with MISP threat intelligence data.
--
-- Usage:
--   sudo -u postgres psql -c "CREATE DATABASE security_intel;"
--   sudo -u postgres psql -c "CREATE USER n8n_user WITH PASSWORD 'your_password';"
--   sudo -u postgres psql -d security_intel -f schema.sql
--
-- =============================================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS security;

-- Grant schema usage
GRANT USAGE ON SCHEMA security TO n8n_user;

-- =============================================================================
-- Main alerts table
-- =============================================================================
CREATE TABLE IF NOT EXISTS security.wazuh_misp_alerts (
    id              SERIAL PRIMARY KEY,
    alert_id        VARCHAR(100) NOT NULL UNIQUE,
    timestamp       TIMESTAMPTZ NOT NULL,
    
    -- Agent information
    agent_name      VARCHAR(255),
    agent_ip        INET,
    
    -- Rule information
    rule_id         VARCHAR(50),
    rule_level      INTEGER,
    rule_description TEXT,
    
    -- MISP enrichment results
    threat_level    VARCHAR(20) DEFAULT 'NONE',
    misp_matches    INTEGER DEFAULT 0,
    auto_blocked    BOOLEAN DEFAULT FALSE,
    
    -- Full alert data for forensics
    raw_data        JSONB,
    
    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- Blocked IOCs tracking table
-- =============================================================================
CREATE TABLE IF NOT EXISTS security.blocked_iocs (
    id              SERIAL PRIMARY KEY,
    ioc_type        VARCHAR(50) NOT NULL,
    ioc_value       VARCHAR(500) NOT NULL,
    source_alert_id VARCHAR(100) REFERENCES security.wazuh_misp_alerts(alert_id),
    blocked_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,
    firewall_response JSONB,
    
    UNIQUE(ioc_type, ioc_value)
);

-- =============================================================================
-- Indexes for query performance
-- =============================================================================

-- Time-based queries
CREATE INDEX IF NOT EXISTS idx_alerts_timestamp 
    ON security.wazuh_misp_alerts(timestamp DESC);

-- Threat level filtering
CREATE INDEX IF NOT EXISTS idx_alerts_threat_level 
    ON security.wazuh_misp_alerts(threat_level);

-- Agent-based analysis
CREATE INDEX IF NOT EXISTS idx_alerts_agent 
    ON security.wazuh_misp_alerts(agent_name);

-- Rule-based reporting
CREATE INDEX IF NOT EXISTS idx_alerts_rule 
    ON security.wazuh_misp_alerts(rule_id);

-- Auto-blocked queries
CREATE INDEX IF NOT EXISTS idx_alerts_blocked 
    ON security.wazuh_misp_alerts(auto_blocked) 
    WHERE auto_blocked = TRUE;

-- JSONB search on raw data
CREATE INDEX IF NOT EXISTS idx_alerts_raw_gin 
    ON security.wazuh_misp_alerts USING GIN(raw_data);

-- Blocked IOCs indexes
CREATE INDEX IF NOT EXISTS idx_blocked_iocs_type 
    ON security.blocked_iocs(ioc_type);

CREATE INDEX IF NOT EXISTS idx_blocked_iocs_value 
    ON security.blocked_iocs(ioc_value);

-- =============================================================================
-- Utility function for updated_at trigger
-- =============================================================================
CREATE OR REPLACE FUNCTION security.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger
DROP TRIGGER IF EXISTS update_alerts_modtime ON security.wazuh_misp_alerts;
CREATE TRIGGER update_alerts_modtime
    BEFORE UPDATE ON security.wazuh_misp_alerts
    FOR EACH ROW
    EXECUTE FUNCTION security.update_modified_column();

-- =============================================================================
-- Useful views
-- =============================================================================

-- Daily alert summary
CREATE OR REPLACE VIEW security.daily_alert_summary AS
SELECT 
    DATE(timestamp) as alert_date,
    threat_level,
    COUNT(*) as alert_count,
    COUNT(*) FILTER (WHERE auto_blocked) as blocked_count
FROM security.wazuh_misp_alerts
GROUP BY DATE(timestamp), threat_level
ORDER BY alert_date DESC, threat_level;

-- Top matched IOCs
CREATE OR REPLACE VIEW security.top_matched_iocs AS
SELECT 
    raw_data->'misp_enrichment'->'matched_iocs' as matched_iocs,
    threat_level,
    COUNT(*) as occurrence_count
FROM security.wazuh_misp_alerts
WHERE misp_matches > 0
GROUP BY raw_data->'misp_enrichment'->'matched_iocs', threat_level
ORDER BY occurrence_count DESC
LIMIT 100;

-- Alerts by agent (last 7 days)
CREATE OR REPLACE VIEW security.alerts_by_agent AS
SELECT 
    agent_name,
    agent_ip,
    COUNT(*) as total_alerts,
    COUNT(*) FILTER (WHERE threat_level = 'CRITICAL') as critical_count,
    COUNT(*) FILTER (WHERE threat_level = 'HIGH') as high_count,
    MAX(timestamp) as last_alert
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY agent_name, agent_ip
ORDER BY total_alerts DESC;

-- =============================================================================
-- Grant permissions
-- =============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA security TO n8n_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA security TO n8n_user;

-- =============================================================================
-- Sample queries (for reference)
-- =============================================================================

-- Get recent critical alerts
-- SELECT * FROM security.wazuh_misp_alerts 
-- WHERE threat_level = 'CRITICAL' 
-- ORDER BY timestamp DESC LIMIT 20;

-- Get alerts with MISP matches
-- SELECT alert_id, timestamp, agent_name, threat_level, misp_matches,
--        raw_data->'misp_enrichment'->'matched_iocs' as iocs
-- FROM security.wazuh_misp_alerts 
-- WHERE misp_matches > 0;

-- Count alerts by hour (last 24h)
-- SELECT date_trunc('hour', timestamp) as hour, COUNT(*) 
-- FROM security.wazuh_misp_alerts 
-- WHERE timestamp > NOW() - INTERVAL '24 hours'
-- GROUP BY 1 ORDER BY 1;

-- =============================================================================
-- Security Automation Pipeline - Example SQL Queries
-- =============================================================================
--
-- Useful queries for analyzing alert data stored in PostgreSQL.
-- Connect with: psql -h HOST -U n8n_user -d security_intel
--
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Recent Alerts
-- -----------------------------------------------------------------------------

-- Last 10 alerts
SELECT 
    alert_id,
    timestamp,
    agent_name,
    rule_id,
    rule_description,
    threat_level,
    misp_matches
FROM security.wazuh_misp_alerts
ORDER BY timestamp DESC
LIMIT 10;

-- Critical alerts only
SELECT 
    alert_id,
    timestamp,
    agent_name,
    rule_description,
    misp_matches,
    raw_data->'misp_enrichment'->'matched_iocs' as matched_iocs
FROM security.wazuh_misp_alerts
WHERE threat_level = 'CRITICAL'
ORDER BY timestamp DESC
LIMIT 20;

-- Alerts with MISP matches
SELECT 
    alert_id,
    timestamp,
    agent_name,
    threat_level,
    misp_matches,
    raw_data->'extracted_iocs' as extracted_iocs
FROM security.wazuh_misp_alerts
WHERE misp_matches > 0
ORDER BY timestamp DESC
LIMIT 50;

-- -----------------------------------------------------------------------------
-- Alert Statistics
-- -----------------------------------------------------------------------------

-- Alerts by threat level (last 24 hours)
SELECT 
    threat_level,
    COUNT(*) as count,
    COUNT(*) FILTER (WHERE auto_blocked) as blocked_count
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY threat_level
ORDER BY 
    CASE threat_level 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        WHEN 'LOW' THEN 4 
        ELSE 5 
    END;

-- Alerts by hour (last 24 hours)
SELECT 
    date_trunc('hour', timestamp) as hour,
    COUNT(*) as alert_count,
    COUNT(*) FILTER (WHERE threat_level IN ('CRITICAL', 'HIGH')) as high_priority
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY 1
ORDER BY 1;

-- Alerts by day (last 30 days)
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE threat_level = 'CRITICAL') as critical,
    COUNT(*) FILTER (WHERE threat_level = 'HIGH') as high,
    COUNT(*) FILTER (WHERE misp_matches > 0) as with_matches
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- -----------------------------------------------------------------------------
-- Agent Analysis
-- -----------------------------------------------------------------------------

-- Alerts by agent (last 7 days)
SELECT 
    agent_name,
    agent_ip,
    COUNT(*) as total_alerts,
    COUNT(*) FILTER (WHERE threat_level = 'CRITICAL') as critical,
    COUNT(*) FILTER (WHERE threat_level = 'HIGH') as high,
    MAX(timestamp) as last_alert
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY agent_name, agent_ip
ORDER BY total_alerts DESC;

-- Most active agents today
SELECT 
    agent_name,
    COUNT(*) as alert_count
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY agent_name
ORDER BY alert_count DESC
LIMIT 10;

-- -----------------------------------------------------------------------------
-- Rule Analysis
-- -----------------------------------------------------------------------------

-- Top triggered rules (last 7 days)
SELECT 
    rule_id,
    rule_description,
    COUNT(*) as occurrences,
    COUNT(DISTINCT agent_name) as affected_agents,
    AVG(rule_level) as avg_level
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY rule_id, rule_description
ORDER BY occurrences DESC
LIMIT 20;

-- Rules with MISP matches
SELECT 
    rule_id,
    rule_description,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE misp_matches > 0) as with_matches,
    ROUND(100.0 * COUNT(*) FILTER (WHERE misp_matches > 0) / COUNT(*), 2) as match_rate
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY rule_id, rule_description
HAVING COUNT(*) > 5
ORDER BY match_rate DESC;

-- -----------------------------------------------------------------------------
-- IOC Analysis
-- -----------------------------------------------------------------------------

-- Extract and count source IPs from alerts
SELECT 
    raw_data->'extracted_iocs'->'source_ips' as source_ips,
    COUNT(*) as occurrences
FROM security.wazuh_misp_alerts
WHERE raw_data->'extracted_iocs'->'source_ips' != '[]'::jsonb
  AND timestamp > NOW() - INTERVAL '7 days'
GROUP BY raw_data->'extracted_iocs'->'source_ips'
ORDER BY occurrences DESC
LIMIT 20;

-- Auto-blocked IOCs
SELECT 
    timestamp,
    alert_id,
    agent_name,
    raw_data->'misp_enrichment'->'matched_iocs' as blocked_iocs
FROM security.wazuh_misp_alerts
WHERE auto_blocked = true
ORDER BY timestamp DESC
LIMIT 50;

-- -----------------------------------------------------------------------------
-- Threat Intelligence Effectiveness
-- -----------------------------------------------------------------------------

-- MISP match rate over time
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as total_alerts,
    COUNT(*) FILTER (WHERE misp_matches > 0) as with_matches,
    ROUND(100.0 * COUNT(*) FILTER (WHERE misp_matches > 0) / COUNT(*), 2) as match_rate_pct
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- Average MISP matches per matched alert
SELECT 
    AVG(misp_matches) as avg_matches,
    MAX(misp_matches) as max_matches,
    MIN(misp_matches) FILTER (WHERE misp_matches > 0) as min_matches
FROM security.wazuh_misp_alerts
WHERE misp_matches > 0;

-- -----------------------------------------------------------------------------
-- Operational Queries
-- -----------------------------------------------------------------------------

-- Recent errors (alerts without agent info)
SELECT *
FROM security.wazuh_misp_alerts
WHERE agent_name IS NULL
  AND timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

-- Alerts per minute (detect spikes)
SELECT 
    date_trunc('minute', timestamp) as minute,
    COUNT(*) as count
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '1 hour'
GROUP BY 1
ORDER BY count DESC
LIMIT 10;

-- Database size check
SELECT 
    pg_size_pretty(pg_total_relation_size('security.wazuh_misp_alerts')) as table_size,
    COUNT(*) as total_rows,
    MIN(timestamp) as oldest_alert,
    MAX(timestamp) as newest_alert
FROM security.wazuh_misp_alerts;

-- -----------------------------------------------------------------------------
-- Cleanup Queries (USE WITH CAUTION)
-- -----------------------------------------------------------------------------

-- Delete alerts older than 90 days (uncomment to use)
-- DELETE FROM security.wazuh_misp_alerts
-- WHERE timestamp < NOW() - INTERVAL '90 days';

-- Vacuum table after large delete
-- VACUUM ANALYZE security.wazuh_misp_alerts;

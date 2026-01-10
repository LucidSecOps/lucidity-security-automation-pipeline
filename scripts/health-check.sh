#!/bin/bash
# =============================================================================
# Security Automation Pipeline - Health Check Script
# =============================================================================
#
# Usage: ./health-check.sh
#
# Environment variables (optional):
#   N8N_HOST        - n8n hostname/IP (default: localhost)
#   N8N_PORT        - n8n port (default: 5678)
#   MISP_HOST       - MISP hostname/IP
#   MISP_API_KEY    - MISP API key
#   PG_HOST         - PostgreSQL hostname/IP
#   PG_USER         - PostgreSQL user
#   PG_DB           - PostgreSQL database
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration with defaults
N8N_HOST="${N8N_HOST:-localhost}"
N8N_PORT="${N8N_PORT:-5678}"
MISP_HOST="${MISP_HOST:-}"
MISP_API_KEY="${MISP_API_KEY:-}"
PG_HOST="${PG_HOST:-localhost}"
PG_USER="${PG_USER:-n8n_user}"
PG_DB="${PG_DB:-security_intel}"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

print_header() {
    echo ""
    echo "=============================================="
    echo "  Security Automation Pipeline Health Check"
    echo "=============================================="
    echo ""
}

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

check_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1 - not configured"
}

# =============================================================================
# Health Checks
# =============================================================================

check_n8n() {
    echo "--- n8n Workflow Engine ---"
    
    if curl -s "http://${N8N_HOST}:${N8N_PORT}/healthz" > /dev/null 2>&1; then
        check_pass "n8n is running on ${N8N_HOST}:${N8N_PORT}"
    else
        check_fail "n8n is not responding on ${N8N_HOST}:${N8N_PORT}"
    fi
    
    # Check webhook endpoint
    WEBHOOK_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "http://${N8N_HOST}:${N8N_PORT}/webhook/wazuh-alert" \
        -H "Content-Type: application/json" \
        -d '{"health_check": true}' 2>/dev/null || echo "000")
    
    if [[ "$WEBHOOK_RESPONSE" == "200" || "$WEBHOOK_RESPONSE" == "404" ]]; then
        check_pass "Webhook endpoint responding"
    else
        check_warn "Webhook returned HTTP $WEBHOOK_RESPONSE (may be inactive)"
    fi
}

check_misp() {
    echo ""
    echo "--- MISP Threat Intelligence ---"
    
    if [[ -z "$MISP_HOST" ]]; then
        check_skip "MISP"
        return
    fi
    
    # Basic connectivity
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
        "https://${MISP_HOST}/users/login" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        check_pass "MISP web interface accessible"
    else
        check_fail "MISP not responding (HTTP $HTTP_CODE)"
        return
    fi
    
    # API check (if key provided)
    if [[ -n "$MISP_API_KEY" ]]; then
        API_RESPONSE=$(curl -sk -o /dev/null -w "%{http_code}" \
            -H "Authorization: ${MISP_API_KEY}" \
            -H "Accept: application/json" \
            "https://${MISP_HOST}/servers/getPyMISPVersion" 2>/dev/null || echo "000")
        
        if [[ "$API_RESPONSE" == "200" ]]; then
            check_pass "MISP API key valid"
        else
            check_fail "MISP API returned HTTP $API_RESPONSE"
        fi
    else
        check_skip "MISP API key"
    fi
}

check_postgresql() {
    echo ""
    echo "--- PostgreSQL Database ---"
    
    if command -v psql &> /dev/null; then
        if psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1" > /dev/null 2>&1; then
            check_pass "PostgreSQL connection successful"
            
            # Check table exists
            TABLE_EXISTS=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -t -c \
                "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'security' AND table_name = 'wazuh_misp_alerts');" 2>/dev/null | tr -d ' ')
            
            if [[ "$TABLE_EXISTS" == "t" ]]; then
                check_pass "Alert table exists"
                
                # Get recent alert count
                ALERT_COUNT=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -t -c \
                    "SELECT COUNT(*) FROM security.wazuh_misp_alerts WHERE timestamp > NOW() - INTERVAL '24 hours';" 2>/dev/null | tr -d ' ')
                echo "       Alerts in last 24h: $ALERT_COUNT"
            else
                check_fail "Alert table not found"
            fi
        else
            check_fail "PostgreSQL connection failed"
        fi
    else
        if nc -zv "$PG_HOST" 5432 2>&1 | grep -q "succeeded"; then
            check_pass "PostgreSQL port open (psql not installed for detailed check)"
        else
            check_fail "PostgreSQL port 5432 not accessible"
        fi
    fi
}

check_wazuh() {
    echo ""
    echo "--- Wazuh Manager ---"
    
    if [[ -f /var/ossec/bin/ossec-control ]]; then
        if sudo /var/ossec/bin/ossec-control status 2>/dev/null | grep -q "is running"; then
            check_pass "Wazuh Manager is running"
        else
            check_fail "Wazuh Manager is not running"
        fi
        
        # Check integration
        if sudo grep -q "custom-n8n-webhook" /var/ossec/etc/ossec.conf 2>/dev/null; then
            check_pass "n8n integration configured in ossec.conf"
        else
            check_warn "n8n integration not found in ossec.conf"
        fi
        
        # Check integration script
        if [[ -x /var/ossec/integrations/custom-n8n-webhook.py ]]; then
            check_pass "Integration script exists and is executable"
        else
            check_fail "Integration script missing or not executable"
        fi
    else
        check_skip "Wazuh Manager (not installed on this host)"
    fi
}

check_firewall() {
    echo ""
    echo "--- Firewall (OPNsense/pfSense) ---"
    
    FIREWALL_HOST="${FIREWALL_HOST:-}"
    
    if [[ -z "$FIREWALL_HOST" ]]; then
        check_skip "Firewall"
        return
    fi
    
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
        "https://${FIREWALL_HOST}" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" ]]; then
        check_pass "Firewall web interface accessible"
    else
        check_fail "Firewall not responding (HTTP $HTTP_CODE)"
    fi
}

print_summary() {
    echo ""
    echo "=============================================="
    echo "  Summary"
    echo "=============================================="
    echo -e "  ${GREEN}Passed:${NC}   $PASSED"
    echo -e "  ${RED}Failed:${NC}   $FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
    echo "=============================================="
    
    if [[ $FAILED -gt 0 ]]; then
        echo ""
        echo "Some checks failed. See TROUBLESHOOTING.md for help."
        exit 1
    fi
}

# =============================================================================
# Main
# =============================================================================

print_header
check_n8n
check_misp
check_postgresql
check_wazuh
check_firewall
print_summary

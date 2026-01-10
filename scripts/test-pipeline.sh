#!/bin/bash
# =============================================================================
# Security Automation Pipeline - Test Script
# =============================================================================
#
# Usage: ./test-pipeline.sh [webhook_url]
#
# This script sends test alerts to the n8n webhook to verify the pipeline.
#
# =============================================================================

set -e

# Configuration
WEBHOOK_URL="${1:-http://localhost:5678/webhook/wazuh-alert}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "  Security Pipeline Test"
echo "=============================================="
echo ""
echo "Webhook URL: $WEBHOOK_URL"
echo ""

# Test 1: Simple connectivity test
echo "--- Test 1: Connectivity ---"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d '{"test": true}' 2>/dev/null || echo "000")

if [[ "$RESPONSE" == "200" ]]; then
    echo -e "${GREEN}[PASS]${NC} Webhook is responding"
else
    echo -e "${RED}[FAIL]${NC} Webhook returned HTTP $RESPONSE"
    exit 1
fi

# Test 2: Alert without IOCs (should log but not enrich)
echo ""
echo "--- Test 2: Alert without IOCs ---"
ALERT_NO_IOC=$(cat <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "id": "test-no-ioc-$(date +%s)",
    "rule": {
        "id": "100001",
        "level": 7,
        "description": "Test alert - no IOCs",
        "groups": ["test"]
    },
    "agent": {
        "id": "000",
        "name": "test-agent",
        "ip": "127.0.0.1"
    },
    "data": {
        "message": "This is a test alert with no extractable IOCs"
    }
}
EOF
)

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$ALERT_NO_IOC")

if [[ "$RESPONSE" == "200" ]]; then
    echo -e "${GREEN}[PASS]${NC} Alert without IOCs accepted"
else
    echo -e "${RED}[FAIL]${NC} Alert rejected (HTTP $RESPONSE)"
fi

# Test 3: Alert with public IP (should trigger MISP lookup)
echo ""
echo "--- Test 3: Alert with Public IP ---"
ALERT_WITH_IP=$(cat <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "id": "test-with-ip-$(date +%s)",
    "rule": {
        "id": "100002",
        "level": 10,
        "description": "Test alert - with public IP",
        "groups": ["test", "authentication_failed"]
    },
    "agent": {
        "id": "001",
        "name": "test-server",
        "ip": "192.168.1.100"
    },
    "data": {
        "srcip": "185.220.101.1"
    }
}
EOF
)

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$ALERT_WITH_IP")

if [[ "$RESPONSE" == "200" ]]; then
    echo -e "${GREEN}[PASS]${NC} Alert with public IP accepted"
    echo "       IP 185.220.101.1 (Tor exit) should trigger MISP lookup"
else
    echo -e "${RED}[FAIL]${NC} Alert rejected (HTTP $RESPONSE)"
fi

# Test 4: Alert with domain
echo ""
echo "--- Test 4: Alert with Domain ---"
ALERT_WITH_DOMAIN=$(cat <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "id": "test-domain-$(date +%s)",
    "rule": {
        "id": "100003",
        "level": 8,
        "description": "Test alert - DNS query",
        "groups": ["test", "dns"]
    },
    "agent": {
        "id": "002",
        "name": "dns-server",
        "ip": "192.168.1.50"
    },
    "data": {
        "query": "malware-test.example.com"
    }
}
EOF
)

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$ALERT_WITH_DOMAIN")

if [[ "$RESPONSE" == "200" ]]; then
    echo -e "${GREEN}[PASS]${NC} Alert with domain accepted"
else
    echo -e "${RED}[FAIL]${NC} Alert rejected (HTTP $RESPONSE)"
fi

# Test 5: Alert with file hash (syscheck)
echo ""
echo "--- Test 5: Alert with File Hash ---"
ALERT_WITH_HASH=$(cat <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "id": "test-hash-$(date +%s)",
    "rule": {
        "id": "550",
        "level": 7,
        "description": "File modified in system directory",
        "groups": ["syscheck", "fim"]
    },
    "agent": {
        "id": "003",
        "name": "webserver",
        "ip": "192.168.1.20"
    },
    "syscheck": {
        "path": "/usr/bin/suspicious",
        "md5_after": "44d88612fea8a8f36de82e1278abb02f",
        "sha256_after": "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f"
    }
}
EOF
)

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$ALERT_WITH_HASH")

if [[ "$RESPONSE" == "200" ]]; then
    echo -e "${GREEN}[PASS]${NC} Alert with file hash accepted"
    echo "       Hash (EICAR test) may trigger MISP match"
else
    echo -e "${RED}[FAIL]${NC} Alert rejected (HTTP $RESPONSE)"
fi

# Summary
echo ""
echo "=============================================="
echo "  Test Complete"
echo "=============================================="
echo ""
echo "Check n8n Executions tab to verify workflow processed alerts."
echo "Check PostgreSQL for logged entries:"
echo "  SELECT * FROM security.wazuh_misp_alerts ORDER BY created_at DESC LIMIT 5;"
echo ""

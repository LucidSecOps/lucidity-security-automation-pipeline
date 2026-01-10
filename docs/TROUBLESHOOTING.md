# Troubleshooting Guide

This guide covers common issues and their solutions.

## Quick Diagnostics

Run the health check script:
```bash
./scripts/health-check.sh
```

---

## Wazuh Integration Issues

### Integration Not Loading

**Symptom:** No alerts reaching n8n

**Check:**
```bash
sudo grep "Enabling integration" /var/ossec/logs/ossec.log | grep n8n
```

**Solutions:**
1. Verify script exists and has correct permissions:
   ```bash
   ls -la /var/ossec/integrations/custom-n8n-webhook.py
   # Should show: -rwxr-x--- root wazuh
   ```

2. Check for Python errors:
   ```bash
   sudo tail -f /var/ossec/logs/integrations.log
   ```

3. Test script manually:
   ```bash
   echo '{"test":true}' > /tmp/test.json
   sudo -u wazuh python3 /var/ossec/integrations/custom-n8n-webhook.py \
     /tmp/test.json "-" "http://YOUR_N8N:5678/webhook/wazuh-alert"
   echo $?  # Should be 0
   ```

4. Restart Wazuh Manager:
   ```bash
   sudo systemctl restart wazuh-manager
   ```

### Alerts Not Forwarding

**Symptom:** Integration loads but no alerts sent

**Check:**
```bash
# Are alerts being generated?
sudo tail -f /var/ossec/logs/alerts/alerts.json | jq .

# Check alert levels
sudo cat /var/ossec/logs/alerts/alerts.json | jq '.rule.level' | sort | uniq -c
```

**Solutions:**
1. Lower the alert threshold in ossec.conf:
   ```xml
   <level>5</level>  <!-- Try lower value -->
   ```

2. Verify n8n is reachable from Wazuh server:
   ```bash
   curl -v http://YOUR_N8N:5678/webhook/wazuh-alert
   ```

---

## n8n Workflow Issues

### Webhook Not Receiving

**Symptom:** Workflow never triggers

**Check:**
```bash
# Test webhook directly
curl -X POST http://YOUR_N8N:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

**Solutions:**
1. Ensure workflow is **Active** (toggle in top-right)
2. Check n8n is running:
   ```bash
   sudo systemctl status n8n
   ```
3. Verify webhook path matches integration config

### MISP Connection Failed

**Symptom:** "SSL Issue" or "Connection refused"

**Check:**
```bash
# From n8n server
curl -sk https://YOUR_MISP/users/login -w "%{http_code}"
# Should return 200
```

**Solutions:**
1. Use internal IP instead of hostname (DNS issues)
2. Enable "Ignore SSL Issues" in MISP node
3. Verify MISP API key is valid:
   ```bash
   curl -sk -H "Authorization: YOUR_KEY" \
     -H "Accept: application/json" \
     https://YOUR_MISP/servers/getPyMISPVersion
   ```

### MISP Returns 403 Forbidden

**Symptom:** HTTP 403 from MISP API

**Cause:** Invalid or expired API key

**Solutions:**
1. Verify API key in MISP UI (Administration → List Users)
2. Ensure user has API access enabled
3. Regenerate API key if needed
4. Update credential in n8n

### MISP Returns 302 Redirect

**Symptom:** HTTP 302, redirects to login

**Cause:** Missing `Accept: application/json` header

**Solutions:**
1. Ensure MISP node has headers configured:
   - `Accept: application/json`
   - `Content-Type: application/json`

### PostgreSQL Connection Failed

**Symptom:** "Connection refused" or timeout

**Check:**
```bash
# From n8n server
nc -zv YOUR_POSTGRES 5432
```

**Solutions:**
1. Open firewall:
   ```bash
   sudo ufw allow from N8N_IP to any port 5432
   ```

2. Configure PostgreSQL for remote connections:
   ```bash
   # postgresql.conf
   listen_addresses = '*'
   
   # pg_hba.conf
   host security_intel n8n_user N8N_IP/32 scram-sha-256
   ```

3. Restart PostgreSQL:
   ```bash
   sudo systemctl restart postgresql
   ```

### PostgreSQL "Table Not Found"

**Symptom:** Relation does not exist

**Solutions:**
1. Verify schema was created:
   ```bash
   psql -h HOST -U n8n_user -d security_intel -c "\dt security.*"
   ```

2. Check credential database name matches
3. Re-run schema:
   ```bash
   sudo -u postgres psql -d security_intel -f schema.sql
   ```

### PostgreSQL "Column Mismatch"

**Symptom:** Column type errors

**Solutions:**
1. Use "Prepare DB Record" node before PostgreSQL node
2. Set PostgreSQL node to "Auto-Map Input Data to Columns"
3. Ensure node order: ... → Prepare DB Record → PostgreSQL

---

## Firewall Issues

### OPNsense API Connection Failed

**Symptom:** Connection timeout or refused

**Check:**
```bash
curl -sk -u "KEY:SECRET" https://YOUR_FIREWALL/api/core/firmware/status
```

**Solutions:**
1. Verify API is enabled in OPNsense
2. Check API key credentials
3. Enable "Ignore SSL Issues" in n8n node
4. Use internal IP instead of hostname

### Alias Not Updating

**Symptom:** IPs not appearing in blocklist

**Solutions:**
1. Verify alias exists: Firewall → Aliases → MISP_Blocklist
2. Check API response in n8n execution
3. Ensure "Apply Changes" node runs after "Add to Blocklist"

---

## Jenkins Issues

### Pipeline Fails at Connectivity Check

**Symptom:** MISP connectivity check fails

**Solutions:**
1. Use internal IP instead of hostname in Jenkinsfile
2. Verify Jenkins server can reach MISP:
   ```bash
   curl -sk https://YOUR_MISP/users/login
   ```
3. Check credential ID matches: `misp-api-key`

### "No Executors Available"

**Symptom:** Build stuck waiting

**Solutions:**
1. Enable executors on built-in node:
   - Manage Jenkins → Nodes → Built-In Node → Configure
   - Set "Number of executors" to 2+

---

## Common Error Codes

| Error | Meaning | Solution |
|-------|---------|----------|
| HTTP 200 | Success | None needed |
| HTTP 302 | Redirect | Add Accept header |
| HTTP 400 | Bad request | Check JSON payload |
| HTTP 401 | Unauthorized | Check API key |
| HTTP 403 | Forbidden | Check permissions |
| HTTP 404 | Not found | Check URL/endpoint |
| HTTP 500 | Server error | Check target service logs |
| Curl 6 | DNS resolution failed | Use IP instead of hostname |
| Curl 7 | Connection refused | Check service running, firewall |
| Curl 28 | Timeout | Network issue, firewall |
| Curl 35 | SSL handshake failed | Enable ignore SSL or fix cert |

---

## Log Locations

| Component | Log Location |
|-----------|--------------|
| Wazuh Manager | `/var/ossec/logs/ossec.log` |
| Wazuh Integrations | `/var/ossec/logs/integrations.log` |
| Wazuh Alerts | `/var/ossec/logs/alerts/alerts.json` |
| n8n | `docker logs n8n` or systemd journal |
| MISP | `/var/www/MISP/app/tmp/logs/` |
| PostgreSQL | `/var/log/postgresql/` |
| OPNsense | System → Log Files |
| Jenkins | Build Console Output |

---

## Getting Help

1. Check this troubleshooting guide
2. Review component logs
3. Open GitHub Issue with:
   - Error message
   - Relevant log excerpts
   - Configuration (sanitized)
   - Steps to reproduce

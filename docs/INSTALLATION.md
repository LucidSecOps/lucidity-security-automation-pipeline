# Installation Guide

This guide walks through installing and configuring the Security Automation Pipeline.

## Prerequisites

### Required Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Wazuh Manager | 4.x | SIEM and alerting |
| n8n | 1.x | Workflow automation |
| MISP | 2.4+ | Threat intelligence |
| PostgreSQL | 14+ | Alert logging |
| Firewall | OPNsense/pfSense | Active response |

### Optional Components

| Component | Purpose |
|-----------|---------|
| Jenkins | Scheduled automation |
| CrowdSec | Community threat intelligence |

### Network Requirements

Ensure the following connectivity:

| From | To | Port | Protocol |
|------|-----|------|----------|
| Wazuh Manager | n8n | 5678 | HTTP |
| n8n | MISP | 443 | HTTPS |
| n8n | PostgreSQL | 5432 | TCP |
| n8n | Firewall | 443 | HTTPS |
| n8n | Slack | 443 | HTTPS |
| Jenkins | MISP | 443 | HTTPS |

---

## Step 1: PostgreSQL Setup

### Create Database and User

```bash
# Connect as postgres superuser
sudo -u postgres psql

# Create database
CREATE DATABASE security_intel;

# Create user with password
CREATE USER n8n_user WITH PASSWORD 'your_secure_password_here';

# Exit psql
\q
```

### Deploy Schema

```bash
# Apply schema from repository
sudo -u postgres psql -d security_intel -f configs/postgresql/schema.sql
```

### Configure Remote Access (if needed)

```bash
# Edit postgresql.conf
sudo nano /etc/postgresql/14/main/postgresql.conf

# Change listen_addresses
listen_addresses = '*'

# Edit pg_hba.conf
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Add line for n8n server
host    security_intel    n8n_user    YOUR_N8N_IP/32    scram-sha-256

# Restart PostgreSQL
sudo systemctl restart postgresql

# Open firewall
sudo ufw allow from YOUR_N8N_IP to any port 5432
```

### Verify Connection

```bash
# From n8n server
psql -h POSTGRES_HOST -U n8n_user -d security_intel -c "SELECT 1;"
```

---

## Step 2: Wazuh Integration Setup

### Install Integration Script

```bash
# Copy script to Wazuh integrations directory
sudo cp scripts/custom-n8n-webhook.py /var/ossec/integrations/

# Set permissions
sudo chmod 750 /var/ossec/integrations/custom-n8n-webhook.py
sudo chown root:wazuh /var/ossec/integrations/custom-n8n-webhook.py

# Install Python dependencies (if not present)
sudo /var/ossec/framework/python/bin/pip3 install requests
```

### Configure Integration

Edit `/var/ossec/etc/ossec.conf` and add inside `<ossec_config>`:

```xml
<integration>
  <n>custom-n8n-webhook.py</n>
  <hook_url>http://YOUR_N8N_HOST:5678/webhook/wazuh-alert</hook_url>
  <level>7</level>
  <alert_format>json</alert_format>
</integration>
```

### Restart Wazuh Manager

```bash
sudo systemctl restart wazuh-manager

# Verify integration loaded
sudo grep "Enabling integration" /var/ossec/logs/ossec.log | grep n8n
```

---

## Step 3: n8n Workflow Setup

### Import Workflow

1. Open n8n web interface
2. Navigate to **Workflows → Import from File**
3. Select `configs/n8n/workflow.example.json`
4. Click **Import**

### Configure Credentials

Create the following credentials in n8n (**Settings → Credentials**):

#### MISP API
- **Type:** Header Auth
- **Name:** `Authorization`
- **Value:** Your MISP API key

#### PostgreSQL
- **Type:** Postgres
- **Host:** Your PostgreSQL host
- **Database:** `security_intel`
- **User:** `n8n_user`
- **Password:** Your password
- **Port:** 5432

#### Firewall API
- **Type:** HTTP Basic Auth
- **User:** API key
- **Password:** API secret

#### Slack Webhook (optional)
- **Type:** Slack Webhook URL
- **URL:** Your Slack webhook URL

### Update Workflow Nodes

Open the imported workflow and update:

1. **MISP Attribute Search** - Update URL to your MISP host
2. **Slack Alert** - Update webhook URL
3. **Slack Info** - Update webhook URL
4. **Firewall Add to Blocklist** - Update URL to your firewall
5. **Firewall Apply Changes** - Update URL to your firewall
6. Assign credentials to each node

### Activate Workflow

1. Click the **Active** toggle in the top-right
2. Verify webhook is listening:
   ```bash
   curl -X POST http://YOUR_N8N:5678/webhook/wazuh-alert \
     -H "Content-Type: application/json" \
     -d '{"test": true}'
   ```

---

## Step 4: MISP Configuration

### Enable API Access

1. Log into MISP web interface
2. Go to **Administration → List Users**
3. Select your user
4. Note or regenerate the **Auth Key**

### Enable Threat Intel Feeds

1. Go to **Sync Actions → List Feeds**
2. Enable desired feeds (e.g., CIRCL OSINT)
3. Click **Fetch and store all feed data**

### Configure Warning Lists

1. Go to **Input Filters → Warning Lists**
2. Enable lists to reduce false positives:
   - Public DNS resolvers
   - Known Microsoft IPs
   - CDN IP ranges
   - RFC 5735 special-use addresses

---

## Step 5: Firewall Configuration

### OPNsense

#### Create Blocklist Alias
1. Navigate to **Firewall → Aliases**
2. Click **Add**
3. Configure:
   - **Name:** `MISP_Blocklist`
   - **Type:** Host(s)
   - **Content:** (leave empty - populated by automation)
4. Click **Save**

#### Create Firewall Rule
1. Navigate to **Firewall → Rules → WAN** (or appropriate interface)
2. Click **Add**
3. Configure:
   - **Action:** Block
   - **Interface:** WAN
   - **Source:** `MISP_Blocklist`
   - **Destination:** Any
   - **Log:** Enable
4. Click **Save**
5. Click **Apply Changes**

#### Create API Key
1. Navigate to **System → Access → Users**
2. Edit your admin user (or create dedicated API user)
3. Scroll to **API Keys**
4. Click **+** to add new key
5. Note the **Key** and **Secret**

### pfSense

Similar process - create alias, create rule, generate API key via pfSense API package.

---

## Step 6: Jenkins Setup (Optional)

### Create MISP API Credential

1. Go to **Manage Jenkins → Credentials**
2. Click **Add Credentials**
3. Configure:
   - **Kind:** Secret text
   - **Secret:** Your MISP API key
   - **ID:** `misp-api-key`

### Create Pipelines

#### MISP Feed Sync
1. Click **New Item**
2. Name: `MISP-Feed-Sync`
3. Select **Pipeline**
4. Configure:
   - Build Triggers: `H */6 * * *`
   - Pipeline script: Copy from `configs/jenkins/Jenkinsfile-feed-sync`
   - Update `MISP_URL` to your host
5. Click **Save**

#### MISP Maintenance
1. Click **New Item**
2. Name: `MISP-Maintenance`
3. Select **Pipeline**
4. Configure:
   - Build Triggers: `H 3 * * 0`
   - Pipeline script: Copy from `configs/jenkins/Jenkinsfile-maintenance`
   - Update `MISP_URL` to your host
5. Click **Save**

---

## Step 7: Verification

### Test End-to-End Flow

```bash
# Generate test alert on Wazuh Manager
for i in {1..8}; do ssh invalid_user@localhost 2>/dev/null; done

# Check integration log
sudo tail -f /var/ossec/logs/integrations.log

# Check n8n executions
# Open n8n → Executions tab

# Verify PostgreSQL logging
psql -h POSTGRES_HOST -U n8n_user -d security_intel \
  -c "SELECT * FROM security.wazuh_misp_alerts ORDER BY created_at DESC LIMIT 5;"
```

### Health Check Script

```bash
./scripts/health-check.sh
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

---

## Next Steps

1. **Tune alert threshold** - Adjust level based on alert volume
2. **Add more MISP feeds** - Expand threat intelligence coverage
3. **Configure additional notifications** - Email, Teams, PagerDuty
4. **Set up Grafana dashboards** - Visualize security metrics
5. **Enable CrowdSec** - Add community-based threat blocking

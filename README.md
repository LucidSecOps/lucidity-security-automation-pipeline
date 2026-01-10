# Security Automation Pipeline

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Wazuh](https://img.shields.io/badge/Wazuh-4.x-blue)](https://wazuh.com)
[![MISP](https://img.shields.io/badge/MISP-2.4+-green)](https://www.misp-project.org)
[![n8n](https://img.shields.io/badge/n8n-1.x-orange)](https://n8n.io)

An open-source Security Orchestration, Automation, and Response (SOAR) pipeline integrating Wazuh SIEM, MISP Threat Intelligence, n8n workflow automation, and firewall active response.

## 🎯 What This Does

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    Wazuh     │────▶│     n8n      │────▶│     MISP     │────▶│   Firewall   │
│    SIEM      │     │  Automation  │     │  Threat Intel│     │   Blocking   │
└──────────────┘     └──────┬───────┘     └──────────────┘     └──────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  Slack   │ │ PostgreSQL│ │  Email   │
        │  Alerts  │ │  Logging  │ │ (opt.)   │
        └──────────┘ └──────────┘ └──────────┘
```

**Automated threat detection → enrichment → response in seconds, not hours.**

## ✨ Features

- **Real-time IOC Extraction** - Automatically extracts IPs, domains, hashes from Wazuh alerts
- **MISP Enrichment** - Queries threat intelligence for context on detected indicators
- **Automated Blocking** - Critical threats auto-blocked on OPNsense/pfSense firewall
- **Multi-channel Alerting** - Slack notifications with threat context
- **Full Audit Trail** - PostgreSQL logging for compliance and forensics
- **Self-maintaining** - Jenkins pipelines keep threat intel fresh

## 🏗️ Architecture

### Components

| Component | Role | Alternatives |
|-----------|------|--------------|
| [Wazuh](https://wazuh.com) | SIEM, Log Analysis, Alerting | OSSEC, Elastic SIEM |
| [n8n](https://n8n.io) | Workflow Automation | Shuffle SOAR, TheHive Cortex |
| [MISP](https://www.misp-project.org) | Threat Intelligence Platform | OpenCTI, ThreatConnect |
| [PostgreSQL](https://postgresql.org) | Alert Logging & Analytics | MySQL, TimescaleDB |
| [OPNsense](https://opnsense.org) | Firewall Active Response | pfSense, FortiGate |
| [Jenkins](https://jenkins.io) | Scheduled Automation | GitHub Actions, Cron |

### Data Flow

1. **Detection** - Wazuh agents detect security events across your infrastructure
2. **Forwarding** - Alerts level ≥7 sent to n8n webhook
3. **Extraction** - IOCs (IPs, domains, hashes) extracted from alert data
4. **Enrichment** - Each IOC queried against MISP threat intelligence
5. **Classification** - Threat level assigned based on MISP matches
6. **Response** - Actions taken based on severity:
   - **CRITICAL**: Slack alert + Auto-block on firewall
   - **HIGH/MEDIUM**: Slack notification
   - **ALL**: PostgreSQL logging

## 📋 Prerequisites

- Wazuh Manager 4.x
- MISP 2.4+
- n8n 1.x (self-hosted)
- PostgreSQL 14+
- OPNsense/pfSense (or other firewall with API)
- Jenkins (optional, for scheduled maintenance)

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/teknikscsl/lucidity-security-automation-pipeline.git
cd security-automation-pipeline
```

### 2. Configure Components

Copy example configs and customize:

```bash
cp configs/wazuh/integration.example.conf configs/wazuh/integration.conf
cp configs/n8n/workflow.example.json configs/n8n/workflow.json
cp configs/postgresql/schema.sql /tmp/
```

Edit each file with your environment details (IPs, credentials, etc.)

### 3. Deploy PostgreSQL Schema

```bash
sudo -u postgres psql -c "CREATE DATABASE security_intel;"
sudo -u postgres psql -c "CREATE USER n8n_user WITH PASSWORD 'your_secure_password';"
sudo -u postgres psql -d security_intel -f configs/postgresql/schema.sql
```

### 4. Configure Wazuh Integration

```bash
# Copy integration script
sudo cp scripts/custom-n8n-webhook.py /var/ossec/integrations/
sudo chmod 750 /var/ossec/integrations/custom-n8n-webhook.py
sudo chown root:wazuh /var/ossec/integrations/custom-n8n-webhook.py

# Add integration config to ossec.conf
sudo nano /var/ossec/etc/ossec.conf
# Add contents from configs/wazuh/integration.conf

# Restart Wazuh
sudo systemctl restart wazuh-manager
```

### 5. Import n8n Workflow

1. Open n8n UI
2. Go to **Workflows → Import from File**
3. Import `configs/n8n/workflow.json`
4. Configure credentials (MISP API, PostgreSQL, Slack, Firewall)
5. Activate the workflow

### 6. (Optional) Setup Jenkins Pipelines

Import the Jenkinsfiles for automated maintenance:
- `configs/jenkins/Jenkinsfile-feed-sync` - Every 6 hours
- `configs/jenkins/Jenkinsfile-maintenance` - Weekly

## 📁 Project Structure

```
lucidity-security-automation-pipeline/
├── README.md
├── LICENSE
├── docs/
│   ├── ARCHITECTURE.md
│   ├── INSTALLATION.md
│   ├── CONFIGURATION.md
│   ├── TROUBLESHOOTING.md
│   └── CONTRIBUTING.md
├── configs/
│   ├── wazuh/
│   │   ├── integration.example.conf
│   │   └── rules.example.xml
│   ├── n8n/
│   │   └── workflow.example.json
│   ├── postgresql/
│   │   └── schema.sql
│   ├── jenkins/
│   │   ├── Jenkinsfile-feed-sync
│   │   └── Jenkinsfile-maintenance
│   └── crowdsec/
│       └── wazuh-bouncer.example.yaml
├── scripts/
│   ├── custom-n8n-webhook.py
│   ├── test-pipeline.sh
│   └── health-check.sh
└── examples/
    ├── sample-alerts/
    └── queries/
```

## ⚙️ Configuration

### Environment Variables

Create a `.env` file (never commit this):

```bash
# MISP
MISP_URL=https://your-misp-server
MISP_API_KEY=your-api-key

# PostgreSQL
PG_HOST=your-postgres-server
PG_DATABASE=security_intel
PG_USER=n8n_user
PG_PASSWORD=your-secure-password

# Slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx/xxx/xxx

# Firewall
FIREWALL_HOST=your-firewall
FIREWALL_API_KEY=your-api-key
FIREWALL_API_SECRET=your-api-secret

# n8n
N8N_WEBHOOK_URL=http://your-n8n-server:5678/webhook/wazuh-alert
```

### Threat Level Matrix

| Level | MISP Criteria | Auto-Block | Alert |
|-------|---------------|------------|-------|
| CRITICAL | threat_level=1 OR to_ids=true | ✅ | Slack |
| HIGH | threat_level=2 | ❌ | Slack |
| MEDIUM | threat_level=3 | ❌ | Slack |
| LOW | threat_level=4 | ❌ | Log only |
| NONE | No match | ❌ | Log only |

### IOC Types Supported

| Type | MISP Attribute | Wazuh Source |
|------|----------------|--------------|
| Source IP | ip-src | srcip, data.srcip |
| Destination IP | ip-dst | dstip, data.dstip |
| Domain | domain | data.query, dns.question.name |
| MD5 | md5 | syscheck.md5_after |
| SHA1 | sha1 | syscheck.sha1_after |
| SHA256 | sha256 | syscheck.sha256_after |

## 🔧 Customization

### Adding New IOC Types

Edit the "Extract IOCs" node in n8n to parse additional fields from Wazuh alerts.

### Changing Alert Threshold

Modify the Wazuh integration config:

```xml
<integration>
  <name>custom-n8n-webhook.py</name>
  <hook_url>http://your-n8n:5678/webhook/wazuh-alert</hook_url>
  <level>7</level>  <!-- Change this value -->
  <alert_format>json</alert_format>
</integration>
```

### Adding Notification Channels

The n8n workflow can be extended with additional nodes:
- Email (SMTP)
- Microsoft Teams
- PagerDuty
- Telegram
- Custom webhooks

### Supporting Other Firewalls

Replace the OPNsense nodes with HTTP Request nodes for your firewall's API:
- **FortiGate**: REST API for address objects
- **Palo Alto**: XML API
- **pfSense**: pfSense API package
- **iptables**: SSH command execution

## 📊 Monitoring & Metrics

### Useful PostgreSQL Queries

```sql
-- Alerts by threat level (last 24h)
SELECT threat_level, COUNT(*) 
FROM security.wazuh_misp_alerts 
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY threat_level;

-- Top triggered rules (last 7 days)
SELECT rule_id, rule_description, COUNT(*) as hits
FROM security.wazuh_misp_alerts
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY rule_id, rule_description
ORDER BY hits DESC LIMIT 10;

-- Auto-blocked IOCs
SELECT timestamp, alert_id, raw_data->'misp_enrichment'->'matched_iocs'
FROM security.wazuh_misp_alerts
WHERE auto_blocked = true
ORDER BY timestamp DESC;
```

### Health Checks

```bash
# Run health check script
./scripts/health-check.sh

# Manual checks
curl -s http://n8n-server:5678/healthz
curl -sk https://misp-server/users/login -w "%{http_code}"
sudo grep "Enabling integration" /var/ossec/logs/ossec.log | grep n8n
```

## 🛡️ Security Considerations

- **API Keys**: Store in environment variables or secrets manager, never in code
- **Network Segmentation**: Keep security components on isolated management network
- **TLS**: Enable HTTPS for all API communications
- **Least Privilege**: Use dedicated service accounts with minimal permissions
- **Audit Logging**: All actions logged to PostgreSQL for forensic analysis
- **Input Validation**: IOCs validated before firewall API calls

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

### Areas for Contribution

- Additional firewall integrations
- New notification channels
- Dashboard templates (Grafana, Kibana)
- Additional MISP feed configurations
- Documentation improvements
- Bug fixes and optimizations

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [Wazuh](https://wazuh.com) - Open source security monitoring
- [MISP Project](https://www.misp-project.org) - Threat intelligence platform
- [n8n](https://n8n.io) - Workflow automation
- [CrowdSec](https://crowdsec.net) - Collaborative security engine
- [OPNsense](https://opnsense.org) - Open source firewall

## 📬 Support

- **Issues**: [GitHub Issues](https://github.com/teknikscsl/security-automation-pipeline/issues)
- **Discussions**: [GitHub Discussions](https://github.com/teknikscsl/security-automation-pipeline/discussions)
- **Security**: For security issues, please email security@lucidityconsult.net

---

**⭐ If this project helps secure your infrastructure, consider giving it a star!**

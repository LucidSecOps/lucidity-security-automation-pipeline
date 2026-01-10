# Architecture Documentation

## Overview

This document describes the architecture of the Security Automation Pipeline, a SOAR (Security Orchestration, Automation, and Response) solution that integrates multiple security tools for automated threat detection and response.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY AUTOMATION PIPELINE                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐                                                                │
│  │  Endpoints  │  Servers, workstations, network devices                        │
│  │  (Agents)   │  running Wazuh agents                                          │
│  └──────┬──────┘                                                                │
│         │ Events & Logs                                                         │
│         ▼                                                                       │
│  ┌─────────────────┐                                                            │
│  │  Wazuh Manager  │  Log analysis, correlation, alerting                       │
│  │    (SIEM)       │  Rule matching, threat detection                           │
│  └────────┬────────┘                                                            │
│           │ Level 7+ Alerts (JSON)                                              │
│           ▼                                                                     │
│  ┌─────────────────┐                                                            │
│  │  n8n Workflow   │  Automation orchestration                                  │
│  │   (Webhook)     │  IOC extraction, routing                                   │
│  └────────┬────────┘                                                            │
│           │                                                                     │
│     ┌─────┴─────┬─────────────┬─────────────┐                                  │
│     ▼           ▼             ▼             ▼                                  │
│  ┌───────┐  ┌───────┐   ┌──────────┐  ┌──────────┐                             │
│  │ MISP  │  │ Slack │   │PostgreSQL│  │ Firewall │                             │
│  │ TIP   │  │ Alert │   │ Logging  │  │ Blocking │                             │
│  └───────┘  └───────┘   └──────────┘  └──────────┘                             │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐       │
│  │                         JENKINS AUTOMATION                           │       │
│  │  Feed Sync (6h) │ Maintenance (Weekly) │ Health Checks              │       │
│  └─────────────────────────────────────────────────────────────────────┘       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Wazuh Manager

**Role:** Security Information and Event Management (SIEM)

**Responsibilities:**
- Collect logs from agents
- Analyze events against detection rules
- Generate alerts based on rule matches
- Forward high-priority alerts to n8n

**Key Configuration:**
- Integration script: `custom-n8n-webhook.py`
- Alert threshold: Level 7+
- Output format: JSON

### 2. n8n Workflow Engine

**Role:** Security Orchestration and Automation

**Responsibilities:**
- Receive alerts via webhook
- Extract IOCs (IPs, domains, hashes)
- Orchestrate enrichment and response
- Route data to appropriate destinations

**Workflow Nodes:**
1. Webhook receiver
2. IOC extraction
3. MISP enrichment
4. Threat classification
5. Slack notification
6. Firewall blocking
7. PostgreSQL logging

### 3. MISP (Threat Intelligence Platform)

**Role:** Threat Intelligence Enrichment

**Responsibilities:**
- Store threat intelligence feeds
- Provide IOC lookup API
- Return threat context and attribution
- Maintain warning lists (false positive filtering)

**Integration Method:** REST API
- Endpoint: `/attributes/restSearch`
- Authentication: API key header

### 4. PostgreSQL

**Role:** Alert Logging and Analytics

**Responsibilities:**
- Store all enriched alerts
- Provide audit trail for compliance
- Enable historical analysis and reporting
- Support forensic investigations

**Schema:**
- Database: `security_intel`
- Schema: `security`
- Main table: `wazuh_misp_alerts`

### 5. Firewall (OPNsense/pfSense)

**Role:** Active Response

**Responsibilities:**
- Receive blocking commands via API
- Maintain dynamic blocklist
- Block traffic from malicious IPs

**Integration Method:** REST API
- Add to alias: `/api/firewall/alias_util/add/{alias_name}`
- Apply changes: `/api/firewall/alias/reconfigure`

### 6. Jenkins

**Role:** Scheduled Automation

**Responsibilities:**
- Sync MISP feeds on schedule
- Run maintenance tasks
- Generate health reports

## Data Flow

### Alert Processing

```
1. Security Event Detected
   └─▶ Wazuh Agent captures event
   
2. Log Analysis
   └─▶ Wazuh Manager analyzes against rules
   └─▶ Alert generated if rule matches
   
3. Alert Forwarding (Level ≥7)
   └─▶ Integration script triggered
   └─▶ JSON payload sent to n8n webhook
   
4. IOC Extraction
   └─▶ Parse alert for indicators
   └─▶ Filter private/internal IPs
   └─▶ Build IOC list
   
5. MISP Enrichment
   └─▶ Query each IOC against MISP
   └─▶ Retrieve threat context
   └─▶ Determine threat level
   
6. Response Actions
   └─▶ CRITICAL: Slack + Block + Log
   └─▶ HIGH/MEDIUM: Slack + Log
   └─▶ LOW/NONE: Log only
```

### Threat Classification

| Threat Level | Criteria | Actions |
|--------------|----------|---------|
| CRITICAL | MISP threat_level=1 OR to_ids=true | Slack, Auto-block, Log |
| HIGH | MISP threat_level=2 | Slack, Log |
| MEDIUM | MISP threat_level=3 | Slack, Log |
| LOW | MISP threat_level=4 | Log |
| NONE | No MISP match | Log |

## Security Considerations

### Network Segmentation
- Keep security tools on isolated management network
- Use firewall rules to restrict access
- Consider VPN for remote management

### Authentication
- Use API keys for all integrations
- Store credentials in secrets manager
- Rotate keys quarterly

### Encryption
- Enable TLS for all API communications
- Use self-signed certificates internally if needed
- Validate certificates where possible

### Least Privilege
- Create dedicated service accounts
- Grant minimal required permissions
- Audit access regularly

## Scalability

### Horizontal Scaling
- n8n: Multiple workers
- PostgreSQL: Read replicas
- MISP: Sync servers

### Performance Tuning
- Adjust alert threshold based on volume
- Tune PostgreSQL indexes
- Configure connection pooling

## High Availability

For production deployments, consider:
- Wazuh cluster mode
- PostgreSQL replication
- n8n queue persistence
- Multiple MISP sync servers

## Monitoring

### Health Checks
- Wazuh: `ossec-control status`
- n8n: `/healthz` endpoint
- MISP: `/users/login` (200 = healthy)
- PostgreSQL: Connection test

### Metrics to Watch
- Alert volume per hour
- MISP match rate
- Auto-block count
- Response latency

## Disaster Recovery

### Backup Priorities
1. PostgreSQL database (alerts and audit trail)
2. MISP database (threat intelligence)
3. n8n workflows (automation logic)
4. Wazuh rules and config

### Recovery Procedures
1. Restore databases from backup
2. Verify API connectivity
3. Test alert flow end-to-end
4. Validate blocking functionality

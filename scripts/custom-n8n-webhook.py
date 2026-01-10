#!/usr/bin/env python3
"""
Wazuh to n8n Webhook Integration Script
========================================

This script forwards Wazuh alerts to an n8n webhook for processing,
enrichment, and automated response.

Installation:
    1. Copy to /var/ossec/integrations/custom-n8n-webhook.py
    2. chmod 750 /var/ossec/integrations/custom-n8n-webhook.py
    3. chown root:wazuh /var/ossec/integrations/custom-n8n-webhook.py
    4. Add integration config to ossec.conf
    5. Restart wazuh-manager

Author: Security Automation Pipeline Project
License: MIT
"""

import sys
import json
import requests
from datetime import datetime

# Configuration
TIMEOUT_SECONDS = 30
DEBUG = False

def log_message(message: str, level: str = "INFO") -> None:
    """Log message to stderr for Wazuh integration logging."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{timestamp} - {level} - n8n-webhook: {message}", file=sys.stderr)

def read_alert_file(alert_file: str) -> dict:
    """Read and parse the alert JSON file."""
    try:
        with open(alert_file, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        log_message(f"Failed to parse alert JSON: {e}", "ERROR")
        raise
    except FileNotFoundError:
        log_message(f"Alert file not found: {alert_file}", "ERROR")
        raise

def send_to_webhook(webhook_url: str, alert_data: dict) -> bool:
    """Send alert data to n8n webhook."""
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    try:
        response = requests.post(
            webhook_url,
            json=alert_data,
            headers=headers,
            timeout=TIMEOUT_SECONDS,
            verify=True  # Set to False if using self-signed certs
        )
        
        if response.status_code in (200, 201, 204):
            log_message(f"Alert sent successfully. Status: {response.status_code}")
            return True
        else:
            log_message(
                f"Webhook returned unexpected status: {response.status_code}", 
                "WARNING"
            )
            return False
            
    except requests.exceptions.Timeout:
        log_message(f"Webhook request timed out after {TIMEOUT_SECONDS}s", "ERROR")
        return False
    except requests.exceptions.ConnectionError as e:
        log_message(f"Connection error: {e}", "ERROR")
        return False
    except requests.exceptions.RequestException as e:
        log_message(f"Request failed: {e}", "ERROR")
        return False

def main():
    """
    Main entry point.
    
    Wazuh passes arguments as:
        sys.argv[1] = alert file path
        sys.argv[2] = api_key (may be '-' if not configured)
        sys.argv[3] = hook_url
    """
    if DEBUG:
        log_message(f"Script called with args: {sys.argv}")
    
    # Validate arguments
    if len(sys.argv) < 4:
        log_message(
            f"Insufficient arguments. Expected 3, got {len(sys.argv) - 1}", 
            "ERROR"
        )
        sys.exit(1)
    
    alert_file = sys.argv[1]
    # api_key = sys.argv[2]  # Not used for webhook auth in this implementation
    webhook_url = sys.argv[3]
    
    if DEBUG:
        log_message(f"Alert file: {alert_file}")
        log_message(f"Webhook URL: {webhook_url}")
    
    # Read and send alert
    try:
        alert_data = read_alert_file(alert_file)
        success = send_to_webhook(webhook_url, alert_data)
        sys.exit(0 if success else 1)
    except Exception as e:
        log_message(f"Unhandled exception: {e}", "ERROR")
        sys.exit(1)

if __name__ == "__main__":
    main()

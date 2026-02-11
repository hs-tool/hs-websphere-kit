#!/bin/bash
# Audit logger — auto-logs every script execution
# Source this from config.sh for automatic coverage

AUDIT_LOG="/opt/was/audit.log"

_audit_log() {
    local script_name="${BASH_SOURCE[2]:-unknown}"
    script_name=$(basename "$script_name")
    local user
    user=$(whoami 2>/dev/null || echo "unknown")
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local server="${SERVER_NAME:-unknown}"

    # Append to audit log (create if missing, ignore errors)
    echo "$timestamp | $server | $user | $script_name" >> "$AUDIT_LOG" 2>/dev/null || true
}

# Auto-log on source
_audit_log

#!/bin/bash
# ============================================================
# Server Configuration — Single Source of Truth
# ============================================================
# SERVER_NAME is auto-detected from the machine hostname.
# All paths and identifiers are derived from this value.
# ============================================================

TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVER_NAME="$(hostname)"

# --- Derived paths (no need to edit below this line) ---
WAS_BASE="/opt/was/profiles"
NDM_PROFILE="${WAS_BASE}/${SERVER_NAME}_NDM"
NODE_PROFILE="${WAS_BASE}/${SERVER_NAME}_NODE01"

CELL_NAME="BS_Cell"
APP_SERVER="BS_APPSRV_01"

MQ_QM="INT_QM"
MQ_USER="mqmuser"

WAS_USER="wasadmin"
WAS_GROUP="wasadmin"

DEPLOY_PATH="/pcms/beanstore/util/deploy/server"
DEPLOY_OVERRIDE="$DEPLOY_PATH/override.properties"
DEPLOY_BUILD_XML="$DEPLOY_PATH/upgrade.xml"

# WebSphere deploy scripts (from release package, not WAS install)
WS_ADMIN_BIN="/home/wasadmin/pcms/release/server/websphere/bin"
WS_ENV_NAME="D"

HOME_DIR="$TOOLKIT_ROOT"

# Runs an original AutoSIAN deploy script (upgrade.sh, getbuild.sh, etc.)
# These scripts set up their own SUPERROOT, CLASSPATH, and invoke Ant.
run_deploy_script() {
    local script="$1"
    local script_path="$DEPLOY_PATH/$script"
    if [[ ! -f "$script_path" ]]; then
        echo "ERROR: Deploy script not found: $script_path"
        return 1
    fi
    (
        cd "$DEPLOY_PATH" || return 1
        bash "$script"
    )
}

# --- Config validation ---
validate_config() {
    local errors=0
    for dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
        if [[ ! -d "$dir" ]]; then
            echo "ERROR: Directory not found: $dir"
            ((errors++))
        fi
    done
    if ((errors > 0)); then
        echo "Config validation failed. Check SERVER_NAME='$SERVER_NAME' in config.sh"
        exit 1
    fi
}

validate_config

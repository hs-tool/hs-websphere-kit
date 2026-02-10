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

# SUPERROOT = 3 levels up from deploy/server (matches upgrade.sh logic)
BEANSTORE_ROOT="/pcms/beanstore"

# WebSphere deploy scripts (from release package, not WAS install)
WS_ADMIN_BIN="/home/wasadmin/pcms/release/server/websphere/bin"
WS_ENV_NAME="D"

HOME_DIR="$TOOLKIT_ROOT"

# --- Ant runner (matches upgrade.sh pattern exactly) ---
# Each server script does the same thing: setup classpath, then:
#   java -ms64m -mx512m org.apache.tools.ant.Main -buildfile upgrade.xml <TARGET> 2> errlog.out
# This function replicates that pattern with any target.
run_ant_target() {
    local target="$1"

    if [[ -z "${JAVA_HOME:-}" ]]; then
        echo "ERROR: JAVA_HOME is not set. Cannot run Ant."
        return 1
    fi

    local ant_cp="."
    for jar in "$BEANSTORE_ROOT"/3rdlibs/ant/*.jar; do
        [[ -f "$jar" ]] && ant_cp="$ant_cp:$jar"
    done
    ant_cp="$ant_cp:$BEANSTORE_ROOT/3rdlibs/commons-net-1.4.1.jar"
    ant_cp="$ant_cp:$BEANSTORE_ROOT/3rdlibs/jakarta-oro-2.0.8.jar"

    (
        cd "$DEPLOY_PATH" || { echo "ERROR: Cannot cd to $DEPLOY_PATH"; return 1; }
        export CLASSPATH="$ant_cp"
        "$JAVA_HOME/bin/java" -ms64m -mx512m \
            org.apache.tools.ant.Main \
            -buildfile upgrade.xml \
            -Dsilent.install=true \
            "$target" 2> errlog.out
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

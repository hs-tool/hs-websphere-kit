#!/bin/bash
# ============================================================
# Server Configuration — Single Source of Truth
# ============================================================
# Change SERVER_NAME to match your target server.
# All paths and identifiers are derived from this value.
# ============================================================

SERVER_NAME="JLUKCNDWASBS01"

# --- Derived paths (no need to edit below this line) ---
WAS_BASE="/opt/was/profiles"
NDM_PROFILE="${WAS_BASE}/${SERVER_NAME}_NDM"
NODE_PROFILE="${WAS_BASE}/${SERVER_NAME}_NODE01"

CELL_NAME="BS_Cell"
APP_SERVER="BS_APPSRV_01"

MQ_QM="INT_QM"
MQ_USER="mqmuser"

DEPLOY_PATH="/pcms/beanstore/util/deploy/server"
HOME_DIR="/home/wasadmin/DCT"

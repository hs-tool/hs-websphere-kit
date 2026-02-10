#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

sudo rm -rf "$NDM_PROFILE/config/temp/download/"*
sudo rm -rf "$NDM_PROFILE/wstemp/"*
sudo rm -rf "$NODE_PROFILE/wstemp/"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/applications/wtr"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/applications/ESI"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/applications/ESP"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/applications/JLP"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/cus/JLP"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/cus/ESP"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/cus/ESI"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/cus/wtr"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/blas/wtr"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/blas/ESI"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/blas/ESP"*
rm -rf "$NDM_PROFILE/config/cells/$CELL_NAME/blas/JLP"*
df -h
cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }

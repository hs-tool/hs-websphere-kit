#!/bin/bash
source "$(dirname "$0")/../config.sh"

sudo rm -r "$NDM_PROFILE/config/temp/download/"*
sudo rm -r "$NDM_PROFILE/wstemp/"*
sudo rm -r "$NODE_PROFILE/wstemp/"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/applications/wtr"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/applications/ESI"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/applications/ESP"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/applications/JLP"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/cus/JLP"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/cus/ESP"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/cus/ESI"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/cus/wtr"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/blas/wtr"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/blas/ESI"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/blas/ESP"*
  rm -r "$NDM_PROFILE/config/cells/$CELL_NAME/blas/JLP"*
df -h
cd "$HOME_DIR"

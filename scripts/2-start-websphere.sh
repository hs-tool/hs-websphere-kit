#!/bin/bash
source "$(dirname "$0")/../config.sh"

cd "$NDM_PROFILE/bin"
./startManager.sh
cd "$NODE_PROFILE/bin"
./startNode.sh
cd "$HOME_DIR"

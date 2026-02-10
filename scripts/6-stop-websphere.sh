#!/bin/bash
source "$(dirname "$0")/../config.sh"

cd "$NDM_PROFILE/bin"
./stopManager.sh
cd "$NODE_PROFILE/bin"
./stopNode.sh
cd "$HOME_DIR"

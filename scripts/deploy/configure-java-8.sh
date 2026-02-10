#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
sudo ./managesdk.sh -setNewProfileDefault -sdkname 1.8_64
sudo ./managesdk.sh -enableProfileAll -sdkname 1.8_64 -enableServers
cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }

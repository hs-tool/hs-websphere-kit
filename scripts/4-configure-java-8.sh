#!/bin/bash
source "$(dirname "$0")/../config.sh"

cd "$NODE_PROFILE/bin"
  sudo ./managesdk.sh -setNewProfileDefault -sdkname 1.8_64
  sudo ./managesdk.sh -enableProfileAll -sdkname 1.8_64 -enableServers
cd "$HOME_DIR"

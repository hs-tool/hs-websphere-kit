#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

echo "Starting application server: $APP_SERVER"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
./startServer.sh "$APP_SERVER"
echo "$APP_SERVER started."
cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }

#!/bin/bash
source "$(dirname "$0")/../config.sh"

cd "$DEPLOY_PATH"
./upgrade.sh
cd "$HOME_DIR"

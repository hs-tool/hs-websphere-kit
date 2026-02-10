#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

df -h
cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }

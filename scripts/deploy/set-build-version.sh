#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Set Build Version ===${NC}"
echo ""

# Read current project.name from override.properties
if [[ ! -f "$DEPLOY_OVERRIDE" ]]; then
    echo -e "${YELLOW}WARNING: override.properties not found at $DEPLOY_OVERRIDE${NC}"
    echo "Cannot read current build version."
    exit 1
fi

current_name=$(grep -E "^project\.name=" "$DEPLOY_OVERRIDE" | tail -1 | cut -d'=' -f2)
current_env=$(grep -E "^websphere\.environment\.name=" "$DEPLOY_OVERRIDE" | tail -1 | cut -d'=' -f2)

echo -e "  Override file:  ${DIM}$DEPLOY_OVERRIDE${NC}"
echo -e "  Current build:  ${BOLD}${YELLOW}${current_name:-<not set>}${NC}"
echo -e "  WAS environment: ${BOLD}${current_env:-<not set>}${NC}"
echo ""

# Show commented-out versions as recent history
echo -e "${DIM}  Recent versions in file:${NC}"
grep -E "^#?project\.name=" "$DEPLOY_OVERRIDE" | while read -r line; do
    echo -e "    ${DIM}$line${NC}"
done
echo ""

read -p "  Enter new build name (blank to keep current): " new_name

if [[ -z "$new_name" ]]; then
    echo "  Keeping current: $current_name"
    exit 0
fi

# Comment out the current active line and add the new one
cd "$DEPLOY_PATH" || { echo "ERROR: Cannot cd to $DEPLOY_PATH"; exit 1; }

# Comment out current active project.name line
sed -i "s/^project\.name=/#project.name=/" override.properties

# Append new active line after the last project.name block
sed -i "/^#*project\.name=/{
    # hold pattern, keep reading
}" override.properties

# Add the new project.name at the end of the project.name block
# Find the last line matching #project.name and insert after it
last_line=$(grep -n "^#*project\.name=" override.properties | tail -1 | cut -d: -f1)
sed -i "${last_line}a project.name=${new_name}" override.properties

echo ""
echo -e "${GREEN}${BOLD}  Build version set to: ${new_name}${NC}"

# Verify
echo ""
echo -e "${DIM}  Updated override.properties:${NC}"
grep -E "^#?project\.name=" override.properties | while read -r line; do
    echo -e "    ${DIM}$line${NC}"
done
echo ""

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }

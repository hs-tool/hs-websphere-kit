#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


BACKUP_DIR="/opt/was/backups"

echo ""
echo -e "${BOLD}${CYAN}=== Backup WAS Configuration ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# Create backup directory
sudo mkdir -p "$BACKUP_DIR" 2>/dev/null || true

# List existing backups
existing=$(find "$BACKUP_DIR" -name "config_*.tar.gz" -type f 2>/dev/null | sort -r)
if [[ -n "$existing" ]]; then
    count=$(echo "$existing" | wc -l)
    latest=$(echo "$existing" | head -1)
    latest_size=$(du -sh "$latest" 2>/dev/null | cut -f1)
    latest_date=$(basename "$latest" | sed 's/config_//;s/\.tar\.gz//')
    echo -e "  ${DIM}Existing backups: $count (latest: $latest_date, $latest_size)${NC}"
else
    echo -e "  ${DIM}No existing backups${NC}"
fi
echo ""

timestamp=$(date +%Y%m%d_%H%M%S)
backup_file="$BACKUP_DIR/config_${timestamp}.tar.gz"

# What we're backing up
echo -e "  ${BOLD}Will backup:${NC}"
echo -e "    ${DIM}$NDM_PROFILE/config/${NC}"
echo -e "    ${DIM}$NODE_PROFILE/config/${NC}"
echo -e "    ${DIM}$NODE_PROFILE/properties/${NC}"
echo ""

read -p "  Create backup? (Y/n): " confirm
confirm="${confirm:-Y}"
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Skipped."
    exit 0
fi

echo -e "  ${BOLD}Creating backup...${NC}"

start_time=$SECONDS

sudo tar czf "$backup_file" \
    --ignore-failed-read \
    -C "$WAS_BASE" \
    "$(basename "$NDM_PROFILE")/config" \
    "$(basename "$NODE_PROFILE")/config" \
    "$(basename "$NODE_PROFILE")/properties" \
    2>/dev/null

elapsed=$(( SECONDS - start_time ))
backup_size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)

echo ""
echo -e "${GREEN}${BOLD}  Backup created: $backup_file${NC}"
echo -e "  ${DIM}Size: $backup_size | Time: ${elapsed}s${NC}"

# Cleanup: keep last 5 backups
backup_count=$(find "$BACKUP_DIR" -name "config_*.tar.gz" -type f 2>/dev/null | wc -l)
if (( backup_count > 5 )); then
    old_backups=$(find "$BACKUP_DIR" -name "config_*.tar.gz" -type f 2>/dev/null | sort | head -n -5)
    while IFS= read -r old; do
        sudo rm -f "$old"
        echo -e "  ${DIM}Pruned old backup: $(basename "$old")${NC}"
    done <<< "$old_backups"
fi
echo ""

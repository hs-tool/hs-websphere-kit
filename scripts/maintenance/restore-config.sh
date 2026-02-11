#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


BACKUP_DIR="/opt/was/backups"

echo ""
echo -e "${BOLD}${CYAN}=== Restore WAS Configuration ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# List available backups
backups=()
while IFS= read -r f; do
    [[ -n "$f" ]] && backups+=("$f")
done < <(find "$BACKUP_DIR" -name "config_*.tar.gz" -type f 2>/dev/null | sort -r)

if (( ${#backups[@]} == 0 )); then
    echo -e "  ${YELLOW}No backups found in $BACKUP_DIR${NC}"
    echo -e "  ${DIM}Run 'Backup Config' first.${NC}"
    exit 1
fi

echo -e "  ${BOLD}Available backups:${NC}"
echo ""
for i in "${!backups[@]}"; do
    b="${backups[$i]}"
    bname=$(basename "$b")
    bsize=$(du -sh "$b" 2>/dev/null | cut -f1)
    bdate=$(echo "$bname" | sed 's/config_//;s/\.tar\.gz//' | sed 's/_/ /')
    printf "    ${BOLD}%d${NC}  %-25s  ${DIM}%s${NC}\n" $((i+1)) "$bdate" "$bsize"
done
echo ""

read -p "  Select backup to restore (1-${#backups[@]}): " choice
if [[ -z "$choice" ]] || (( choice < 1 || choice > ${#backups[@]} )); then
    echo -e "  ${RED}Invalid selection.${NC}"
    exit 1
fi

selected="${backups[$((choice-1))]}"
echo ""
echo -e "  ${RED}${BOLD}WARNING: This will overwrite current WAS config!${NC}"
echo -e "  ${DIM}Restoring: $(basename "$selected")${NC}"
echo -e "  ${DIM}Target:    $WAS_BASE${NC}"
echo ""

# Check if servers are running
ps_snap=$(ps -ef 2>/dev/null)
if echo "$ps_snap" | grep -v grep | grep -q "$APP_SERVER\|dmgr\|nodeagent"; then
    echo -e "  ${RED}WARNING: WebSphere processes are still running!${NC}"
    echo -e "  ${YELLOW}Stop all WAS processes before restoring config.${NC}"
    echo ""
    read -p "  Continue anyway? (y/N): " force
    if [[ ! "$force" =~ ^[Yy]$ ]]; then
        echo "  Aborted."
        exit 0
    fi
fi

read -p "  Type 'RESTORE' to confirm: " confirm
if [[ "$confirm" != "RESTORE" ]]; then
    echo "  Aborted."
    exit 0
fi

echo ""
echo -e "  ${BOLD}Restoring configuration...${NC}"

start_time=$SECONDS
sudo tar xzf "$selected" -C "$WAS_BASE" 2>/dev/null

elapsed=$(( SECONDS - start_time ))

echo ""
echo -e "${GREEN}${BOLD}  Configuration restored from: $(basename "$selected")${NC}"
echo -e "  ${DIM}Time: ${elapsed}s${NC}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "    1. Start Deployment Manager"
echo -e "    2. Sync Node"
echo -e "    3. Start Node Agent and App Server"
echo ""

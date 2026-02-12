#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -uo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Disk Usage ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo -e "${BOLD}Filesystem overview:${NC}"
df -h
echo ""

echo -e "${BOLD}WAS profile sizes:${NC}"
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    if [[ -d "$profile_dir" ]]; then
        label=$(basename "$profile_dir")
        size=$(du -sh "$profile_dir" 2>/dev/null | cut -f1)
        echo -e "  ${BOLD}$label${NC}  ${DIM}$size${NC}"

        # Show largest subdirectories
        echo -e "    ${DIM}Top directories:${NC}"
        du -sh "$profile_dir"/*/ 2>/dev/null | sort -rh | head -5 | while read -r sz dir; do
            dirname=$(basename "$dir")
            echo -e "    ${DIM}  $sz  $dirname${NC}"
        done
    fi
    echo ""
done

# Check for large log files
echo -e "${BOLD}Largest log files:${NC}"
find "$NDM_PROFILE/logs" "$NODE_PROFILE/logs" -type f -size +1M 2>/dev/null | while read -r f; do
    sz=$(du -sh "$f" 2>/dev/null | cut -f1)
    relpath="${f#$WAS_BASE/}"
    echo -e "  ${YELLOW}$sz${NC}  ${DIM}$relpath${NC}"
done
echo ""

# Check for heap dumps / javacores
dumps_count=0
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    count=$(find "$profile_dir" -maxdepth 1 \( -name "heapdump.*.phd" -o -name "javacore.*.txt" -o -name "Snap.*.trc" -o -name "core.*.dmp" \) 2>/dev/null | wc -l)
    ((dumps_count += count)) || true
done
if (( dumps_count > 0 )); then
    echo -e "${RED}${BOLD}Found $dumps_count heap dump/javacore files. Run 'Clear Logs' to remove.${NC}"
else
    echo -e "${GREEN}No heap dumps or javacores found.${NC}"
fi
echo ""

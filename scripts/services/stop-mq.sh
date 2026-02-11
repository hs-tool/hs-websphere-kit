#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Stop MQ Queue Manager ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo -e "  QM:     ${BOLD}$MQ_QM${NC}"
echo ""

echo -e "  ${BOLD}Stopping $MQ_QM...${NC}"

# -w: wait for all apps to disconnect (controlled shutdown)
# Use -i for immediate if controlled fails
if sudo -u "$MQ_USER" /opt/mqm/bin/endmqm -w "$MQ_QM" 2>/dev/null; then
    echo -e "  ${RED}MQ Queue Manager $MQ_QM stopped${NC}"
elif sudo -u "$MQ_USER" /opt/mqm/bin/endmqm -i "$MQ_QM" 2>/dev/null; then
    echo -e "  ${YELLOW}MQ Queue Manager $MQ_QM stopped (immediate — controlled shutdown timed out)${NC}"
else
    echo -e "  ${YELLOW}WARNING: endmqm exited with non-zero status (QM may already be stopped)${NC}"
fi
echo ""

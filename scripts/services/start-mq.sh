#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Start MQ Queue Manager ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo -e "  QM:     ${BOLD}$MQ_QM${NC}"
echo ""

echo -e "  ${BOLD}Starting $MQ_QM...${NC}"

if sudo -u "$MQ_USER" /opt/mqm/bin/strmqm "$MQ_QM"; then
    echo -e "  ${GREEN}MQ Queue Manager $MQ_QM started${NC}"
else
    echo -e "  ${YELLOW}WARNING: strmqm exited with non-zero status (QM may already be running)${NC}"
fi
echo ""

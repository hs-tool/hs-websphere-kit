#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[92m'
YELLOW='\033[93m'
CYAN='\033[96m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Start MQ Queue Manager ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo -e "  QM:     ${BOLD}$MQ_QM${NC}"
echo ""

echo -e "  ${BOLD}Starting $MQ_QM...${NC}"

password="$MQ_USER"
su -c "cd /opt/mqm/bin/ && ./strmqm $MQ_QM" "$MQ_USER" <<EOF
$password
EOF

echo -e "  ${GREEN}MQ Queue Manager $MQ_QM start command issued${NC}"
echo ""

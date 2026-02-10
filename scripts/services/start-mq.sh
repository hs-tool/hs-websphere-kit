#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

echo "Starting MQ Queue Manager: $MQ_QM"

password="$MQ_USER"
su -c "cd /opt/mqm/bin/ && ./strmqm $MQ_QM" "$MQ_USER" <<EOF
$password
EOF

echo "MQ Queue Manager $MQ_QM start command issued."

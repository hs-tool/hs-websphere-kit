#!/bin/bash
source "$(dirname "$0")/../config.sh"

# Define the log files to empty
LOG_FILES=(
"$NDM_PROFILE/logs/dmgr/SystemOut.log"
"$NDM_PROFILE/logs/dmgr/SystemErr.log"
"$NDM_PROFILE/logs/dmgr/StartServer.log"
"$NODE_PROFILE/logs/$APP_SERVER/SystemOut.log"
"$NODE_PROFILE/logs/$APP_SERVER/SystemErr.log"
"$NODE_PROFILE/logs/$APP_SERVER/startServer.log"
"$NODE_PROFILE/logs/nodeagent/SystemOut.log"
"$NODE_PROFILE/logs/nodeagent/SystemErr.log"
"$NODE_PROFILE/logs/nodeagent/startServer.log"
)

# Loop through the files and truncate them
for LOG_FILE in "${LOG_FILES[@]}"; do
    echo "Emptying $LOG_FILE..."
    truncate -s 0 "$LOG_FILE"
done

echo "All specified log files have been emptied."

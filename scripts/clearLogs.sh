#!/bin/bash

# Define the log files to empty
LOG_FILES=(
"/opt/was/profiles/JLUKCNDWASBS01_NDM/logs/dmgr/SystemOut.log"
"/opt/was/profiles/JLUKCNDWASBS01_NDM/logs/dmgr/SystemErr.log"
"/opt/was/profiles/JLUKCNDWASBS01_NDM/logs/dmgr/StartServer.log"
"/opt/was/profiles/JLUKCNDWASBS01_NODE01/logs/BS_APPSRV_01/SystemOut.log"
"/opt/was/profiles/JLUKCNDWASBS01_NODE01/logs/BS_APPSRV_01/SystemErr.log"
"/opt/was/profiles/JLUKCNDWASBS01_NODE01/logs/BS_APPSRV_01/startServer.log"
"/opt/was/profiles/JLUKCNDWASBS01_NODE01/logs/nodeagent/SystemOut.log"
"/opt/was/profiles/JLUKCNDWASBS01_NODE01/logs/nodeagent/SystemErr.log"
"/opt/was/profiles/JLUKCNDWASBS01_NODE01/logs/nodeagent/startServer.log"
)

# Loop through the files and truncate them
for LOG_FILE in "${LOG_FILES[@]}"; do
    echo "Emptying $LOG_FILE..."
    truncate -s 0 "$LOG_FILE"
done

echo "All specified log files have been emptied."

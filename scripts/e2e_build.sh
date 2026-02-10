#!/bin/bash
source "$(dirname "$0")/../config.sh"

SCRIPT_DIR="$(dirname "$0")"

"$SCRIPT_DIR/1-start-mq.sh"
if [ $? -eq 0 ]; then
    echo "1-start-mq.sh executed successfully"
else
    echo "1-start-mq.sh failed. Exiting."
    exit 1
fi
"$SCRIPT_DIR/2-start-websphere.sh"
if [ $? -eq 0 ]; then
    echo "2-start-websphere.sh executed successfully"
else
    echo "2-start-websphere.sh failed. Exiting."
    exit 1
fi
"$SCRIPT_DIR/5-remove-temp-files.sh"
if [ $? -eq 0 ]; then
    echo "5-remove-temp-files.sh executed successfully"
else
    echo "5-remove-temp-files.sh failed. Exiting."
    exit 1
fi
"$SCRIPT_DIR/7-upgrade-build.sh"
if [ $? -eq 0 ]; then
    echo "7-upgrade-build.sh executed successfully"
else
    echo "7-upgrade-build.sh failed. Exiting."
    exit 1
fi
"$SCRIPT_DIR/4-configure-java-8.sh"
"$SCRIPT_DIR/6-stop-websphere.sh"
if [ $? -eq 0 ]; then
    echo "6-stop-websphere.sh executed successfully"
else
    echo "6-stop-websphere.sh failed. Exiting."
    exit 1
fi
"$SCRIPT_DIR/5-remove-temp-files.sh"
if [ $? -eq 0 ]; then
    echo "5-remove-temp-files.sh executed successfully"
else
    echo "5-remove-temp-files.sh failed. Exiting."
    exit 1
fi
"$SCRIPT_DIR/2-start-websphere.sh"
if [ $? -eq 0 ]; then
    echo "2-start-websphere.sh executed successfully"
else
    echo "2-start-websphere.sh failed. Exiting."
    exit 1
fi
echo "All scripts executed successfully"

#!/bin/bash
source "$(dirname "$0")/../config.sh"

password="$MQ_USER"
su -c "cd /opt/mqm/bin/ && ./strmqm $MQ_QM" "$MQ_USER" <<EOF
$password
EOF
ps -ef | grep websphere
read -p "Enter First port number to kill: " portNumber

if [[ $portNumber =~ ^[0-9]+$ ]]; then
    ps -ef | grep websphere | grep $portNumber | awk '{print $2}' | xargs kill -9
    echo "Process using port $portNumber killed."
else
    echo "Invalid port number. Please enter a valid numeric port number."
fi
read -p "Enter Second port number to kill: " portNumber

if [[ $portNumber =~ ^[0-9]+$ ]]; then
    ps -ef | grep websphere | grep $portNumber | awk '{print $2}' | xargs kill -9
    echo "Process using port $portNumber killed."
else
    echo "Invalid port number. Please enter a valid numeric port number."
fi
cd "$HOME_DIR"

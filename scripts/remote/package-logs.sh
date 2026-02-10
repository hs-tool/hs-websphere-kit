#!/bin/bash
# package-logs.sh — Runs on remote server to package logs for download
# Creates /tmp/was-logs.tar.gz with all WAS profile logs + beanstore
set +e

WAS_BASE="/opt/was/profiles"
TARBALL="/tmp/was-logs.tar"

# Tar all profile logs directories
cd "$WAS_BASE" 2>/dev/null
tar cf "$TARBALL" --ignore-failed-read */logs 2>/dev/null

# Find and append beanstore
BS=$(find /wasappdata /home /opt -maxdepth 5 -type d -name beanstore 2>/dev/null | head -1)
if [ -n "$BS" ]; then
    tar rf "$TARBALL" -C "$(dirname "$BS")" beanstore 2>/dev/null
fi

# Compress
gzip -f "$TARBALL" 2>/dev/null
echo "PACKAGED"

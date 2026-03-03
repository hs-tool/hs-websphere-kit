#!/bin/bash
# package-logs.sh — Runs on remote server to package logs for download
# Creates /tmp/was-logs.tar.gz with all WAS profile logs + beanstore
# Runs as wasadmin via sudo from downloadLogs.cmd
set +e

WAS_BASE="/opt/was/profiles"
TARBALL="/tmp/was-logs.tar"
ERRORS=0

# Tar all profile logs directories
if cd "$WAS_BASE" 2>/dev/null; then
    tar cf "$TARBALL" --ignore-failed-read */logs 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "WARN: Some profile logs could not be read"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "WARN: Cannot access $WAS_BASE"
    # Create empty tarball so append works
    tar cf "$TARBALL" --files-from /dev/null 2>/dev/null
    ERRORS=$((ERRORS + 1))
fi

# Append /beanstore directory (ServerErrlogs, datadist, etc.)
if [ -d "/beanstore" ]; then
    tar rf "$TARBALL" --dereference -C / beanstore 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "WARN: Some beanstore files could not be read"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "WARN: /beanstore directory not found"
fi

# Compress
gzip -f "$TARBALL" 2>/dev/null

# Make tarball readable by the SSH user for SCP download
chmod 644 "${TARBALL}.gz" 2>/dev/null

if [ $ERRORS -gt 0 ]; then
    echo "PACKAGED (with $ERRORS warnings)"
else
    echo "PACKAGED"
fi

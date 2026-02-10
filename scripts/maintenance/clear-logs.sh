#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

truncated=0
deleted=0

# --- Truncate base log files (keeps file handles valid for running servers) ---
BASE_LOGS=(
    "$NDM_PROFILE/logs/dmgr/SystemOut.log"
    "$NDM_PROFILE/logs/dmgr/SystemErr.log"
    "$NDM_PROFILE/logs/dmgr/StartServer.log"
    "$NDM_PROFILE/logs/dmgr/native_stderr.log"
    "$NDM_PROFILE/logs/dmgr/native_stdout.log"
    "$NODE_PROFILE/logs/$APP_SERVER/SystemOut.log"
    "$NODE_PROFILE/logs/$APP_SERVER/SystemErr.log"
    "$NODE_PROFILE/logs/$APP_SERVER/startServer.log"
    "$NODE_PROFILE/logs/$APP_SERVER/native_stderr.log"
    "$NODE_PROFILE/logs/$APP_SERVER/native_stdout.log"
    "$NODE_PROFILE/logs/nodeagent/SystemOut.log"
    "$NODE_PROFILE/logs/nodeagent/SystemErr.log"
    "$NODE_PROFILE/logs/nodeagent/startServer.log"
    "$NODE_PROFILE/logs/nodeagent/native_stderr.log"
    "$NODE_PROFILE/logs/nodeagent/native_stdout.log"
)

for log_file in "${BASE_LOGS[@]}"; do
    if [[ -f "$log_file" ]]; then
        truncate -s 0 "$log_file"
        ((truncated++))
    fi
done

# --- Delete rotated/timestamped log copies ---
for log_dir in \
    "$NDM_PROFILE/logs/dmgr" \
    "$NODE_PROFILE/logs/$APP_SERVER" \
    "$NODE_PROFILE/logs/nodeagent"; do

    if [[ -d "$log_dir" ]]; then
        while IFS= read -r -d '' f; do
            rm -f "$f"
            ((deleted++))
        done < <(find "$log_dir" -maxdepth 1 \( \
            -name "SystemOut_*.log" -o \
            -name "SystemErr_*.log" -o \
            -name "StartServer_*.log" -o \
            -name "startServer_*.log" \
        \) -print0 2>/dev/null)
    fi
done

# --- Delete FFDC files ---
for ffdc_dir in \
    "$NDM_PROFILE/logs/ffdc" \
    "$NODE_PROFILE/logs/ffdc"; do

    if [[ -d "$ffdc_dir" ]]; then
        while IFS= read -r -d '' f; do
            rm -f "$f"
            ((deleted++))
        done < <(find "$ffdc_dir" -type f -print0 2>/dev/null)
    fi
done

# --- Delete heap dumps, javacores, snap traces ---
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    if [[ -d "$profile_dir" ]]; then
        while IFS= read -r -d '' f; do
            rm -f "$f"
            ((deleted++))
        done < <(find "$profile_dir" -maxdepth 1 \( \
            -name "heapdump.*.phd" -o \
            -name "javacore.*.txt" -o \
            -name "Snap.*.trc" -o \
            -name "core.*.dmp" \
        \) -print0 2>/dev/null)
    fi
done

# --- Delete trace logs ---
for trace_dir in \
    "$NODE_PROFILE/logs/trace" \
    "$NDM_PROFILE/logs/trace"; do

    if [[ -d "$trace_dir" ]]; then
        while IFS= read -r -d '' f; do
            rm -f "$f"
            ((deleted++))
        done < <(find "$trace_dir" -type f -print0 2>/dev/null)
    fi
done

echo "Log cleanup complete: $truncated files truncated, $deleted files deleted."

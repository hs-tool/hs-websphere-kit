#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[92m'
RED='\033[91m'
YELLOW='\033[93m'
CYAN='\033[96m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

truncated=0
deleted=0

echo ""
echo -e "${BOLD}${CYAN}=== Clear Logs ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

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

echo -e "${BOLD}Truncating active logs...${NC}"
for log_file in "${BASE_LOGS[@]}"; do
    if [[ -f "$log_file" ]]; then
        size=$(stat -c '%s' "$log_file" 2>/dev/null || echo 0)
        truncate -s 0 "$log_file"
        echo -e "  ${GREEN}TRUNCATED${NC}  ${DIM}$(basename "$log_file")${NC}  ${DIM}(was ${size} bytes)${NC}"
        ((truncated++)) || true
    fi
done

# --- Delete rotated/timestamped log copies ---
echo ""
echo -e "${BOLD}Deleting rotated logs...${NC}"
for log_dir in \
    "$NDM_PROFILE/logs/dmgr" \
    "$NODE_PROFILE/logs/$APP_SERVER" \
    "$NODE_PROFILE/logs/nodeagent"; do

    if [[ -d "$log_dir" ]]; then
        label=$(basename "$log_dir")
        while IFS= read -r -d '' f; do
            echo -e "  ${RED}DELETE${NC}  ${DIM}$label/$(basename "$f")${NC}"
            rm -f "$f"
            ((deleted++)) || true
        done < <(find "$log_dir" -maxdepth 1 \( \
            -name "SystemOut_*.log" -o \
            -name "SystemErr_*.log" -o \
            -name "StartServer_*.log" -o \
            -name "startServer_*.log" \
        \) -print0 2>/dev/null)
    fi
done

# --- Delete FFDC files ---
echo ""
echo -e "${BOLD}Deleting FFDC files...${NC}"
ffdc_found=0
for ffdc_dir in \
    "$NDM_PROFILE/logs/ffdc" \
    "$NODE_PROFILE/logs/ffdc"; do

    if [[ -d "$ffdc_dir" ]]; then
        label=$(basename "$(dirname "$ffdc_dir")")
        while IFS= read -r -d '' f; do
            echo -e "  ${RED}DELETE${NC}  ${DIM}$label/ffdc/$(basename "$f")${NC}"
            rm -f "$f"
            ((deleted++)) || true
            ffdc_found=1
        done < <(find "$ffdc_dir" -type f -print0 2>/dev/null)
    fi
done
if [[ $ffdc_found -eq 0 ]]; then
    echo -e "  ${DIM}(none found)${NC}"
fi

# --- Delete heap dumps, javacores, snap traces ---
echo ""
echo -e "${BOLD}Deleting heap dumps, javacores, snap traces...${NC}"
dumps_found=0
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    if [[ -d "$profile_dir" ]]; then
        label=$(basename "$profile_dir")
        while IFS= read -r -d '' f; do
            echo -e "  ${RED}DELETE${NC}  ${DIM}$label/$(basename "$f")${NC}"
            rm -f "$f"
            ((deleted++)) || true
            dumps_found=1
        done < <(find "$profile_dir" -maxdepth 1 \( \
            -name "heapdump.*.phd" -o \
            -name "javacore.*.txt" -o \
            -name "Snap.*.trc" -o \
            -name "core.*.dmp" \
        \) -print0 2>/dev/null)
    fi
done
if [[ $dumps_found -eq 0 ]]; then
    echo -e "  ${DIM}(none found)${NC}"
fi

# --- Delete trace logs ---
echo ""
echo -e "${BOLD}Deleting trace logs...${NC}"
traces_found=0
for trace_dir in \
    "$NODE_PROFILE/logs/trace" \
    "$NDM_PROFILE/logs/trace"; do

    if [[ -d "$trace_dir" ]]; then
        label=$(basename "$(dirname "$(dirname "$trace_dir")")")
        while IFS= read -r -d '' f; do
            echo -e "  ${RED}DELETE${NC}  ${DIM}$label/trace/$(basename "$f")${NC}"
            rm -f "$f"
            ((deleted++)) || true
            traces_found=1
        done < <(find "$trace_dir" -type f -print0 2>/dev/null)
    fi
done
if [[ $traces_found -eq 0 ]]; then
    echo -e "  ${DIM}(none found)${NC}"
fi

# --- Summary ---
echo ""
echo -e "${BOLD}----------------------------------------${NC}"
echo -e "${GREEN}${BOLD}Log cleanup complete: $truncated files truncated, $deleted files deleted.${NC}"
echo ""

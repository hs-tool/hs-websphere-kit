#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
source "$SCRIPT_DIR/config.sh"

# --- Colors (inline defaults, before set -u) ---
GREEN='\033[92m'
RED='\033[91m'
YELLOW='\033[93m'
CYAN='\033[96m'
BLUE='\033[94m'
MAGENTA='\033[95m'
WHITE='\033[97m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
BRIGHT_BLACK='\033[0;90m'
BRIGHT_RED='\033[0;91m'
BRIGHT_GREEN='\033[0;92m'
BRIGHT_YELLOW='\033[0;93m'
BRIGHT_BLUE='\033[0;94m'
BRIGHT_MAGENTA='\033[0;95m'
BRIGHT_CYAN='\033[0;96m'
BRIGHT_WHITE='\033[0;97m'
# Override with shared lib if available
source "$SCRIPT_DIR/lib/colors.sh" 2>/dev/null || true

set -uo pipefail

# --- Cursor safety & cleanup ---
_SB_CACHE_FILE="/tmp/.hs_status_cache_$$"
restore_cursor() {
    tput cnorm 2>/dev/null
}
_cleanup() {
    restore_cursor
    rm -f "$_SB_CACHE_FILE" "${_SB_CACHE_FILE}.tmp" 2>/dev/null
}
trap _cleanup EXIT INT TERM

# --- Helpers ---

get_build_version() {
    if [[ -f "$DEPLOY_OVERRIDE" ]]; then
        grep -E "^project\.name=" "$DEPLOY_OVERRIDE" 2>/dev/null | tail -1 | cut -d'=' -f2
    else
        echo "?"
    fi
}

run_script() {
    local script="$SCRIPT_DIR/scripts/$1"
    if [[ ! -f "$script" ]]; then
        echo -e "\n  ${RED}Script not found: $script${NC}"
        return 0
    fi
    echo ""
    restore_cursor
    "$script" || echo -e "\n  ${RED}Script exited with error.${NC}"
}

get_toolkit_version() {
    if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
        cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]'
    else
        echo "?"
    fi
}

# Status bar — async file-based cache for instant menu rendering
_SB_CACHE_TTL=15  # seconds

_refresh_status_cache() {
    local dmgr_st node_st app_st mq_st
    local dmgr_color node_color app_color mq_color

    # Single ps snapshot for all process checks
    local ps_snap
    ps_snap=$(ps -ef 2>/dev/null)

    if echo "$ps_snap" | grep -v grep | grep -q "dmgr"; then
        dmgr_st="UP"; dmgr_color="$GREEN"
    else
        dmgr_st="DOWN"; dmgr_color="$RED"
    fi

    if echo "$ps_snap" | grep -v grep | grep -q "nodeagent"; then
        node_st="UP"; node_color="$GREEN"
    else
        node_st="DOWN"; node_color="$RED"
    fi

    if echo "$ps_snap" | grep -v grep | grep -q "$APP_SERVER"; then
        app_st="UP"; app_color="$GREEN"
    else
        app_st="DOWN"; app_color="$RED"
    fi

    # MQ — slowest check, uses sudo with timeout
    if command -v dspmq &>/dev/null || [[ -d /opt/mqm/bin ]]; then
        local dspmq_cmd="dspmq"
        command -v dspmq &>/dev/null || dspmq_cmd="/opt/mqm/bin/dspmq"
        local mq_out
        mq_out=$(timeout 10 sudo -u "$MQ_USER" "$dspmq_cmd" 2>/dev/null || true)
        if echo "$mq_out" | grep -qi "Running"; then
            mq_st="UP"; mq_color="$GREEN"
        else
            mq_st="DOWN"; mq_color="$RED"
        fi
    else
        mq_st="N/A"; mq_color="$YELLOW"
    fi

    # Disk usage
    local disk_used disk_total disk_pct disk_color disk_label
    if df -h "$WAS_BASE" &>/dev/null; then
        read -r disk_used disk_total disk_pct < <(df -h "$WAS_BASE" | awk 'NR==2{print $3, $2, $5}')
        disk_pct="${disk_pct%\%}"
        if (( disk_pct >= 85 )); then
            disk_color="$RED"
        elif (( disk_pct >= 70 )); then
            disk_color="$YELLOW"
        else
            disk_color="$GREEN"
        fi
        disk_label="${disk_used}/${disk_total} (${disk_pct}%)"
    else
        disk_color="$YELLOW"; disk_label="N/A"
    fi

    # Write rendered output to cache file (atomic via temp + mv)
    local tmp="${_SB_CACHE_FILE}.tmp"
    {
        echo -e "  ${DIM}┌─ Status ─────────────────────────────────────────────────┐${NC}"
        printf "  ${DIM}│${NC}  Dmgr ${dmgr_color}●${NC} %-4s  Node ${node_color}●${NC} %-4s  App ${app_color}●${NC} %-6s  MQ ${mq_color}●${NC} %-4s  ${DIM}│${NC}\n" \
            "$dmgr_st" "$node_st" "$app_st" "$mq_st"
        echo -e "  ${DIM}│${NC}                                                          ${DIM}│${NC}"
        printf "  ${DIM}│${NC}  Disk ${disk_color}●${NC} %-51s${DIM}│${NC}\n" \
            "$disk_label  $WAS_BASE"
        echo -e "  ${DIM}└──────────────────────────────────────────────────────────┘${NC}"
    } > "$tmp"
    mv -f "$tmp" "$_SB_CACHE_FILE"
}

_render_status_placeholder() {
    echo -e "  ${DIM}┌─ Status ─────────────────────────────────────────────────┐${NC}"
    printf "  ${DIM}│${NC}  Dmgr ${DIM}●${NC} --    Node ${DIM}●${NC} --    App ${DIM}●${NC} --      MQ ${DIM}●${NC} --    ${DIM}│${NC}\n"
    echo -e "  ${DIM}│${NC}                                                          ${DIM}│${NC}"
    printf "  ${DIM}│${NC}  Disk ${DIM}●${NC} %-51s${DIM}│${NC}\n" "checking..."
    echo -e "  ${DIM}└──────────────────────────────────────────────────────────┘${NC}"
}

render_status_bar() {
    # Cache file exists and is fresh — instant render
    if [[ -f "$_SB_CACHE_FILE" ]]; then
        local file_age=$(( $(date +%s) - $(stat -c %Y "$_SB_CACHE_FILE" 2>/dev/null || echo 0) ))
        if (( file_age < _SB_CACHE_TTL )); then
            cat "$_SB_CACHE_FILE"
            return
        fi
    fi

    # No cache yet — show placeholder, kick off background refresh
    _render_status_placeholder
    _refresh_status_cache &
}

# Kick off first status check immediately in background
_refresh_status_cache &

show_banner() {
    clear
    BUILD_VER=$(get_build_version)
    TK_VER=$(get_toolkit_version)
    echo ""
    echo -en "${BOLD}${CYAN}"
    sed -n '1,6s/^/  /p' "$SCRIPT_DIR/banner.txt"
    echo -en "${GREEN}"
    sed -n '7,12s/^/  /p' "$SCRIPT_DIR/banner.txt"
    echo -e "${NC}"
    echo -e "  ${DIM}Developed by Hafiz Syed Muhammad Usman${NC}"
    echo -e "  ${BOLD}Server: ${YELLOW}$SERVER_NAME${NC}    ${BOLD}Build: ${YELLOW}$BUILD_VER${NC}    ${BOLD}Toolkit: ${CYAN}v$TK_VER${NC}"
    echo ""
    render_status_bar
    echo ""
}

# ============================================================
# navigate_menu — interactive arrow-key menu
# ============================================================
# Usage: navigate_menu "back_label" "Label 1|hint" "Label 2|hint" ...
# Sets MENU_RESULT: 0-based index of selected item, or -1 for back/escape.

MENU_RESULT=-1

navigate_menu() {
    local back_label="$1"
    shift
    local items=("$@")
    local count=${#items[@]}
    local sel=0

    # Classify items: dividers vs selectable
    local is_divider=()     # 1=divider, 0=selectable
    local divider_type=()   # "normal" or "danger"
    local divider_text=()   # text to show for dividers
    local labels=()
    local hints=()
    local selectable=()     # indices of selectable items
    local max_label_len=0

    for ((i = 0; i < count; i++)); do
        local raw="${items[$i]}"
        if [[ "$raw" == ---!* ]]; then
            is_divider+=("1")
            divider_type+=("danger")
            divider_text+=("${raw#---!}")
            labels+=("")
            hints+=("")
        elif [[ "$raw" == ---* ]]; then
            is_divider+=("1")
            divider_type+=("normal")
            divider_text+=("${raw#---}")
            labels+=("")
            hints+=("")
        else
            is_divider+=("0")
            divider_type+=("")
            divider_text+=("")
            selectable+=("$i")
            local label="${raw%%|*}"
            local hint="${raw#*|}"
            [[ "$hint" == "$raw" ]] && hint=""
            local plain
            plain=$(echo -e "$label" | sed 's/\x1b\[[0-9;]*m//g')
            local len=${#plain}
            ((len > max_label_len)) && max_label_len=$len
            labels+=("$label")
            hints+=("$hint")
        fi
    done

    local sel_count=${#selectable[@]}
    local total=$((sel_count + 1))  # selectable items + back
    # sel is index into [0..sel_count] where sel_count = back

    # draw_lines: all items (including dividers) + blank + back + blank + hint
    local draw_lines=$((count + 4))

    # Map sel (0..sel_count-1) to row index, sel_count maps to back row
    _sel_to_row() {
        if ((sel < sel_count)); then
            echo "${selectable[$sel]}"
        else
            echo "$count"  # back row sentinel
        fi
    }

    render_menu() {
        local sel_row
        sel_row=$(_sel_to_row)
        local i
        for ((i = 0; i < count; i++)); do
            if ((is_divider[i])); then
                # Render divider line
                local dtxt="${divider_text[$i]}"
                if [[ -n "$dtxt" ]]; then
                    dtxt=" ${dtxt} "
                fi
                if [[ "${divider_type[$i]}" == "danger" ]]; then
                    echo -e "    ${RED}──${dtxt}──${NC}\033[K"
                else
                    echo -e "    ${DIM}──${dtxt}──${NC}\033[K"
                fi
            else
                local plain
                plain=$(echo -e "${labels[$i]}" | sed 's/\x1b\[[0-9;]*m//g')
                local pad_len=$((max_label_len - ${#plain} + 2))
                local padding=""
                for ((p = 0; p < pad_len; p++)); do padding+=" "; done

                if ((i == sel_row)); then
                    echo -e "  ${BOLD}${CYAN}▸${NC} ${BOLD}${labels[$i]}${NC}${padding}${DIM}${hints[$i]}${NC}\033[K"
                else
                    echo -e "    ${labels[$i]}${padding}${DIM}${hints[$i]}${NC}\033[K"
                fi
            fi
        done
        echo -e "\033[K"
        # Back option
        if ((sel == sel_count)); then
            echo -e "  ${BOLD}${CYAN}▸${NC} ${BOLD}${back_label}${NC}\033[K"
        else
            echo -e "    ${DIM}${back_label}${NC}\033[K"
        fi
        echo -e "\033[K"
        echo -e "  ${DIM}↑↓ Navigate  ⏎ Select  Esc ${back_label}${NC}\033[K"
    }

    tput civis 2>/dev/null
    render_menu

    while true; do
        local key
        IFS= read -rsn1 key

        local move=0  # -1=up, 1=down

        if [[ "$key" == $'\x1b' ]]; then
            local seq
            if IFS= read -rsn1 -t 0.2 seq; then
                if [[ "$seq" == "[" ]]; then
                    local arrow
                    IFS= read -rsn1 -t 0.2 arrow
                    case "$arrow" in
                        A) move=-1 ;;
                        B) move=1 ;;
                        *)
                            while IFS= read -rsn1 -t 0.05 _discard; do :; done
                            ;;
                    esac
                else
                    while IFS= read -rsn1 -t 0.05 _discard; do :; done
                fi
            else
                # Bare escape — go back
                MENU_RESULT=-1
                restore_cursor
                return
            fi
        elif [[ "$key" == "" ]]; then
            # Enter — map sel back to selectable item index
            if ((sel == sel_count)); then
                MENU_RESULT=-1
            else
                MENU_RESULT=$sel
            fi
            restore_cursor
            return
        elif [[ "$key" == "k" ]]; then
            move=-1
        elif [[ "$key" == "j" ]]; then
            move=1
        elif [[ "$key" == "q" ]]; then
            MENU_RESULT=-1
            restore_cursor
            return
        fi

        if ((move != 0)); then
            ((sel += move))
            if ((sel < 0)); then
                sel=$((total - 1))
            elif ((sel >= total)); then
                sel=0
            fi
        fi

        # Move cursor up and redraw
        printf "\033[%dA" "$draw_lines"
        render_menu
    done
}

# --- Sub-menus ---

menu_services() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${GREEN}SERVICES & CONTROL${NC}"
        echo ""
        navigate_menu "Back" \
            "${YELLOW}Restart Cycle${NC}|(stop all > clean temp > start all)" \
            "${CYAN}Status${NC}|(show running state of all services)" \
            "---Application Server" \
            "${GREEN}Start${NC} App Server|(launch $APP_SERVER JVM)" \
            "${RED}Stop${NC} App Server|(graceful shutdown $APP_SERVER)" \
            "---Dmgr & Node Agent" \
            "${GREEN}Start${NC} Dmgr|(launch Deployment Manager)" \
            "${RED}Stop${NC} Dmgr|(shutdown Deployment Manager)" \
            "${GREEN}Start${NC} Node Agent|(launch local node agent)" \
            "${RED}Stop${NC} Node Agent|(shutdown local node agent)" \
            "${CYAN}Sync Node${NC}|(push Dmgr config to this node)" \
            "---MQ" \
            "${GREEN}Start MQ${NC}|(start queue manager)" \
            "${RED}Stop MQ${NC}|(stop queue manager)" \
            "MQ Queue Depths|(check message backlog per queue)"
        case $MENU_RESULT in
            0) run_script "services/restart-websphere.sh" ;;
            1) run_script "services/status.sh" ;;
            2) run_script "services/start-appserver.sh" ;;
            3) run_script "services/stop-appserver.sh" ;;
            4) run_script "services/start-dmgr.sh" ;;
            5) run_script "services/stop-dmgr.sh" ;;
            6) run_script "services/start-nodeagent.sh" ;;
            7) run_script "services/stop-nodeagent.sh" ;;
            8) run_script "services/sync-node.sh" ;;
            9) run_script "services/start-mq.sh" ;;
            10) run_script "services/stop-mq.sh" ;;
            11) run_script "diagnostics/mq-depth.sh" ;;
            -1) return ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_deploy() {
    while true; do
        show_banner
        BUILD_VER=$(get_build_version)
        echo -e "  ${BOLD}${CYAN}BUILD & DEPLOY${NC}"
        echo ""
        navigate_menu "Back" \
            "Run Ant Target|(execute any Ant build target)" \
            "Deploy from Cache|(install from local cache, no FTP)" \
            "Set Build Version|(current: $BUILD_VER)" \
            "Build WS Apps|(install apps into WebSphere)" \
            "Download Build|(fetch build artifacts via FTP)" \
            "Full Upgrade|(clean + download + deploy)" \
            "End-to-End Build|(full pipeline: version > FTP > deploy)" \
            "---!Danger Zone" \
            "Teardown WS Apps|(${RED}uninstall all deployed apps${NC})"
        case $MENU_RESULT in
            0) run_script "deploy/run-ant.sh" ;;
            1) run_script "deploy/deploy-cached.sh" ;;
            2) run_script "deploy/set-build-version.sh" ;;
            3) run_script "deploy/build-ws-apps.sh" ;;
            4) run_script "deploy/download-build.sh" ;;
            5) run_script "deploy/full-upgrade.sh" ;;
            6) run_script "deploy/e2e-build.sh" ;;
            7) run_script "deploy/teardown-ws-apps.sh" ;;
            -1) return ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_housekeeping() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${BRIGHT_WHITE}HOUSEKEEPING${NC}"
        echo ""
        navigate_menu "Back" \
            "Remove Temp Files|(clean WAS temp & cache dirs)" \
            "Check Disk Space|(show usage for WAS partitions)" \
            "Check Permissions|(audit file ownership, read-only)" \
            "Fix Permissions|(chown ${WAS_USER}:${WAS_GROUP} on WAS dirs)" \
            "${GREEN}Backup Config${NC}|(snapshot config before changes)" \
            "${RED}Restore Config${NC}|(rollback config from backup)" \
            "---!Danger Zone" \
            "Kill Stale Processes|(${RED}force kill orphaned JVMs${NC})"
        case $MENU_RESULT in
            0) run_script "maintenance/remove-temp-files.sh" ;;
            1) run_script "maintenance/check-disk.sh" ;;
            2) run_script "maintenance/check-permissions.sh" ;;
            3) run_script "maintenance/fix-permissions.sh" ;;
            4) run_script "maintenance/backup-config.sh" ;;
            5) run_script "maintenance/restore-config.sh" ;;
            6) run_script "diagnostics/kill-stale-procs.sh" ;;
            -1) return ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_logs() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${YELLOW}LOGS & DIAGNOSTICS${NC}"
        echo ""
        navigate_menu "Back" \
            "View Logs|(tail -f SystemOut & SystemErr)" \
            "${CYAN}Log Search${NC}|(grep keyword across all log files)" \
            "FFDC Summary|(list recent first-failure exceptions)" \
            "Clear Logs|(truncate SystemOut, SystemErr, FFDC)" \
            "---Health & Performance" \
            "${GREEN}Health Check${NC}|(verify ports, processes, disk)" \
            "Thread Dump|(capture JVM thread snapshot)" \
            "---Audit" \
            "View Audit Trail|(show who ran what and when)"
        case $MENU_RESULT in
            0) run_script "diagnostics/tail-logs.sh" ;;
            1) run_script "diagnostics/log-search.sh" ;;
            2) run_script "diagnostics/ffdc-summary.sh" ;;
            3) run_script "maintenance/clear-logs.sh" ;;
            4) run_script "diagnostics/health-check.sh" ;;
            5) run_script "diagnostics/thread-dump.sh" ;;
            6) run_script "diagnostics/view-audit.sh" ;;
            -1) return ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_server_info() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${BLUE}SERVER INFO${NC}"
        echo ""
        navigate_menu "Back" \
            "List Applications|(deployed apps)" \
            "Server Runtime Info|(PID, heap, threads, uptime)" \
            "JVM Configuration|(heap, GC, thread pools)" \
            "Data Sources|(JDBC, JNDI)" \
            "Virtual Hosts|(host aliases)" \
            "Ports & Endpoints|(open/closed)"
        case $MENU_RESULT in
            0) run_script "admin/list-apps.sh" ;;
            1) run_script "admin/server-info.sh" ;;
            2) run_script "admin/show-jvm-config.sh" ;;
            3) run_script "admin/show-datasources.sh" ;;
            4) run_script "admin/show-vhosts.sh" ;;
            5) run_script "admin/show-ports.sh" ;;
            -1) return ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

# --- Main menu ---
while true; do
    show_banner
    navigate_menu "Exit" \
        "${BOLD}${BRIGHT_YELLOW}One Shot Deploy${NC}|(boot, fix, build — done in one go)" \
        "---" \
        "${GREEN}Services & Control${NC}|(MQ, WebSphere, App Server)" \
        "${CYAN}Build & Deploy${NC}|(Ant, FTP, upgrade, deploy)" \
        "${YELLOW}Logs & Diagnostics${NC}|(search, health, FFDC, threads)" \
        "${BRIGHT_WHITE}Housekeeping${NC}|(disk, permissions, backup)" \
        "${BLUE}Server Info${NC}|(apps, JVM, data sources, ports)"
    case $MENU_RESULT in
        0) run_script "deploy/one-shot-deploy.sh" ; echo "" ; read -p "  Press Enter to continue..." ;;
        1) menu_services ;;
        2) menu_deploy ;;
        3) menu_logs ;;
        4) menu_housekeeping ;;
        5) menu_server_info ;;
        -1) echo -e "\n  ${BOLD}Exiting...${NC}"; break ;;
    esac
done

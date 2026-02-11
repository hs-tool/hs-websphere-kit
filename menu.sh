#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
source "$SCRIPT_DIR/config.sh"
set -uo pipefail

# --- Colors ---
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

    # MQ — slowest check, uses su
    if command -v dspmq &>/dev/null || [[ -d /opt/mqm/bin ]]; then
        local dspmq_cmd="dspmq"
        command -v dspmq &>/dev/null || dspmq_cmd="/opt/mqm/bin/dspmq"
        local mq_out
        mq_out=$(su -c "$dspmq_cmd" "$MQ_USER" 2>/dev/null || true)
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
    local total=$((count + 1))  # items + back
    local sel=0

    # Parse labels and hints
    local labels=()
    local hints=()
    local max_label_len=0
    for item in "${items[@]}"; do
        local label="${item%%|*}"
        local hint="${item#*|}"
        [[ "$hint" == "$item" ]] && hint=""
        # Strip ANSI for length calculation
        local plain
        plain=$(echo -e "$label" | sed 's/\x1b\[[0-9;]*m//g')
        local len=${#plain}
        ((len > max_label_len)) && max_label_len=$len
        labels+=("$label")
        hints+=("$hint")
    done

    # draw_lines: items + blank + back + blank + hint
    local draw_lines=$((count + 4))

    render_menu() {
        local i
        for ((i = 0; i < count; i++)); do
            local plain
            plain=$(echo -e "${labels[$i]}" | sed 's/\x1b\[[0-9;]*m//g')
            local pad_len=$((max_label_len - ${#plain} + 2))
            local padding=""
            for ((p = 0; p < pad_len; p++)); do padding+=" "; done

            if ((i == sel)); then
                echo -e "  ${BOLD}${CYAN}▸${NC} ${BOLD}${labels[$i]}${NC}${padding}${DIM}${hints[$i]}${NC}\033[K"
            else
                echo -e "    ${labels[$i]}${padding}${DIM}${hints[$i]}${NC}\033[K"
            fi
        done
        echo -e "\033[K"
        # Back option
        if ((sel == count)); then
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

        if [[ "$key" == $'\x1b' ]]; then
            local seq
            if IFS= read -rsn1 -t 0.2 seq; then
                if [[ "$seq" == "[" ]]; then
                    local arrow
                    IFS= read -rsn1 -t 0.2 arrow
                    case "$arrow" in
                        A) # Up
                            ((sel--))
                            ((sel < 0)) && sel=$((total - 1))
                            ;;
                        B) # Down
                            ((sel++))
                            ((sel >= total)) && sel=0
                            ;;
                        *)
                            # Drain remaining escape chars
                            while IFS= read -rsn1 -t 0.05 _discard; do :; done
                            ;;
                    esac
                else
                    # Unknown escape seq — drain
                    while IFS= read -rsn1 -t 0.05 _discard; do :; done
                fi
            else
                # Bare escape — go back
                MENU_RESULT=-1
                restore_cursor
                return
            fi
        elif [[ "$key" == "" ]]; then
            # Enter
            if ((sel == count)); then
                MENU_RESULT=-1
            else
                MENU_RESULT=$sel
            fi
            restore_cursor
            return
        elif [[ "$key" == "k" ]]; then
            ((sel--))
            ((sel < 0)) && sel=$((total - 1))
        elif [[ "$key" == "j" ]]; then
            ((sel++))
            ((sel >= total)) && sel=0
        elif [[ "$key" == "q" ]]; then
            MENU_RESULT=-1
            restore_cursor
            return
        else
            continue
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
        echo -e "  ${BOLD}${GREEN}SERVICES${NC}"
        echo ""
        navigate_menu "Back" \
            "${MAGENTA}Start MQ${NC}|" \
            "${GREEN}Start${NC} Dmgr|" \
            "${RED}Stop${NC} Dmgr|" \
            "${GREEN}Start${NC} Node Agent|" \
            "${RED}Stop${NC} Node Agent|" \
            "${GREEN}Start${NC} WebSphere|(manager + node)" \
            "${RED}Stop${NC} WebSphere|(manager + node)" \
            "${GREEN}Start${NC} App Server|($APP_SERVER)" \
            "${RED}Stop${NC} App Server|($APP_SERVER)" \
            "${YELLOW}Restart Cycle${NC}|(stop > clean > start)" \
            "${CYAN}Status${NC}|"
        case $MENU_RESULT in
            0) run_script "services/start-mq.sh" ;;
            1) run_script "services/start-dmgr.sh" ;;
            2) run_script "services/stop-dmgr.sh" ;;
            3) run_script "services/start-nodeagent.sh" ;;
            4) run_script "services/stop-nodeagent.sh" ;;
            5) run_script "services/start-websphere.sh" ;;
            6) run_script "services/stop-websphere.sh" ;;
            7) run_script "services/start-appserver.sh" ;;
            8) run_script "services/stop-appserver.sh" ;;
            9) run_script "services/restart-websphere.sh" ;;
            10) run_script "services/status.sh" ;;
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
            "Set Build Version|(current: $BUILD_VER)" \
            "Download Build|(FTP only)" \
            "Deploy from Cache|(no FTP, use local)" \
            "Full Upgrade|(clean + FTP + deploy)" \
            "Teardown WAS Apps|(remove apps only)" \
            "Build WAS Apps|(install apps only)" \
            "Set Java 8 SDK|" \
            "Run Ant Target|(any target)" \
            "End-to-End Build|(full pipeline)"
        case $MENU_RESULT in
            0) run_script "deploy/set-build-version.sh" ;;
            1) run_script "deploy/download-build.sh" ;;
            2) run_script "deploy/deploy-cached.sh" ;;
            3) run_script "deploy/full-upgrade.sh" ;;
            4) run_script "deploy/teardown-ws-apps.sh" ;;
            5) run_script "deploy/build-ws-apps.sh" ;;
            6) run_script "deploy/configure-java-8.sh" ;;
            7) run_script "deploy/run-ant.sh" ;;
            8) run_script "deploy/e2e-build.sh" ;;
            -1) return ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_maintenance() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${BRIGHT_WHITE}MAINTENANCE${NC}"
        echo ""
        navigate_menu "Back" \
            "Clear Logs|" \
            "Remove Temp Files|" \
            "Check Disk Space|" \
            "Check Permissions|(audit only)" \
            "Fix Permissions|(chown ${WAS_USER}:${WAS_GROUP})"
        case $MENU_RESULT in
            0) run_script "maintenance/clear-logs.sh" ;;
            1) run_script "maintenance/remove-temp-files.sh" ;;
            2) run_script "maintenance/check-disk.sh" ;;
            3) run_script "maintenance/check-permissions.sh" ;;
            4) run_script "maintenance/fix-permissions.sh" ;;
            -1) return ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_diagnostics() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${YELLOW}DIAGNOSTICS${NC}"
        echo ""
        navigate_menu "Back" \
            "Tail Logs|(live follow)" \
            "Kill Stale Procs|"
        case $MENU_RESULT in
            0) run_script "diagnostics/tail-logs.sh" ;;
            1) run_script "diagnostics/kill-stale-procs.sh" ;;
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
        "${GREEN}Services${NC}|(MQ, WebSphere, App Server)" \
        "${CYAN}Build & Deploy${NC}|(upgrade, FTP, Ant, deploy)" \
        "${BRIGHT_WHITE}Maintenance${NC}|(logs, disk, permissions)" \
        "${YELLOW}Diagnostics${NC}|(tail logs, kill procs)"
    case $MENU_RESULT in
        0) menu_services ;;
        1) menu_deploy ;;
        2) menu_maintenance ;;
        3) menu_diagnostics ;;
        -1) echo -e "\n  ${BOLD}Exiting...${NC}"; break ;;
    esac
done

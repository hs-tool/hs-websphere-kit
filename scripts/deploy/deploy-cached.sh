#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Deploy from Cache (No FTP) ===${NC}"
echo ""

# Show current build version
current_name=$(grep -E "^project\.name=" "$DEPLOY_OVERRIDE" 2>/dev/null | tail -1 | cut -d'=' -f2)
echo -e "  Build:  ${BOLD}${YELLOW}${current_name:-<not set>}${NC}"

# Verify the build is actually cached
archive_dir="$DEPLOY_PATH/archive"
if [[ -n "$current_name" && -d "$archive_dir/product/$current_name" ]]; then
    echo -e "  Cache:  ${GREEN}Found${NC} ${DIM}($archive_dir/product/$current_name)${NC}"
else
    echo -e "  Cache:  ${RED}NOT FOUND${NC}"
    echo ""
    echo -e "  ${RED}Build '$current_name' is not cached. Run 'Download Build' first.${NC}"
    exit 1
fi

echo ""
echo "  This will: unpack cached build → teardown WAS → rebuild WAS"
echo "  (Skips FTP download — uses local cache)"
read -p "  Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

start_time=$SECONDS

echo ""
echo -e "  ${BOLD}Deploying...${NC}"
echo ""

ant_rc=0
(
    cd "$DEPLOY_PATH" || exit 1
    SUPERROOT=`pwd`/../../..
    export CLASSPATH=.
    for each in $SUPERROOT/3rdlibs/ant/*.jar; do
        export CLASSPATH=$CLASSPATH:$each
    done
    export CLASSPATH=$CLASSPATH:$SUPERROOT/3rdlibs/commons-net-1.4.1.jar
    export CLASSPATH=$CLASSPATH:$SUPERROOT/3rdlibs/jakarta-oro-2.0.8.jar
    $JAVA_HOME/bin/java -ms64m -mx512m org.apache.tools.ant.Main -buildfile upgrade.xml upgrade-live 2> errlog.out
    exit $?
) || ant_rc=$?

elapsed=$(( SECONDS - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo ""
if (( ant_rc == 0 )); then
    echo -e "${GREEN}${BOLD}  Deploy complete in ${minutes}m ${seconds}s${NC}"
else
    echo -e "${RED}${BOLD}  Deploy FAILED (exit code $ant_rc) in ${minutes}m ${seconds}s${NC}"
    echo -e "  ${DIM}Check errlog.out in $DEPLOY_PATH for details${NC}"
fi
echo ""

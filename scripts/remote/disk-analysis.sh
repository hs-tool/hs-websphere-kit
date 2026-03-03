#!/bin/bash
# disk-analysis.sh — Runs on remote server to analyze disk usage
# Creates /tmp/was-disk-analysis.txt with full breakdown
# Runs as wasadmin via sudo from downloadLogs.cmd
set +e

SERVER_NAME="$(hostname)"
WAS_BASE="/opt/was/profiles"
REPORT="/tmp/was-disk-analysis.txt"

divider() {
    echo "================================================================================" >> "$REPORT"
}

section() {
    echo "" >> "$REPORT"
    divider
    echo "  $1" >> "$REPORT"
    divider
    echo "" >> "$REPORT"
}

# Start report
cat > "$REPORT" <<HEADER
================================================================================
  DISK USAGE ANALYSIS — ${SERVER_NAME}
  Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')
  Running as: $(whoami)
================================================================================
HEADER

# ---------------------------------------------------------------------------
# 1. Filesystem overview
# ---------------------------------------------------------------------------
section "1. FILESYSTEM OVERVIEW"

df -h >> "$REPORT" 2>&1
echo "" >> "$REPORT"
echo "Inode usage:" >> "$REPORT"
df -i / /opt /tmp 2>/dev/null >> "$REPORT"

# ---------------------------------------------------------------------------
# 2. Top-level directory sizes on / (root filesystem)
# ---------------------------------------------------------------------------
section "2. ROOT FILESYSTEM (/) — TOP-LEVEL BREAKDOWN"

echo "Sizes of top-level directories on the root filesystem:" >> "$REPORT"
echo "(sorted by size, largest first)" >> "$REPORT"
echo "" >> "$REPORT"

# Get the root device to filter only dirs on the root FS
ROOT_DEV=$(df / | tail -1 | awk '{print $1}')
echo "Root device: ${ROOT_DEV}" >> "$REPORT"
echo "" >> "$REPORT"

du -hx --max-depth=1 / 2>/dev/null | sort -rh | head -30 >> "$REPORT"

# ---------------------------------------------------------------------------
# 3. Drill into largest directories on /
# ---------------------------------------------------------------------------
section "3. DRILL-DOWN — LARGEST DIRECTORIES"

# /var breakdown
echo "--- /var ---" >> "$REPORT"
du -hx --max-depth=2 /var 2>/dev/null | sort -rh | head -20 >> "$REPORT"
echo "" >> "$REPORT"

# /usr breakdown
echo "--- /usr ---" >> "$REPORT"
du -hx --max-depth=2 /usr 2>/dev/null | sort -rh | head -20 >> "$REPORT"
echo "" >> "$REPORT"

# /home breakdown
echo "--- /home ---" >> "$REPORT"
du -hx --max-depth=2 /home 2>/dev/null | sort -rh | head -20 >> "$REPORT"
echo "" >> "$REPORT"

# /root breakdown
echo "--- /root ---" >> "$REPORT"
du -hx --max-depth=1 /root 2>/dev/null | sort -rh | head -10 >> "$REPORT"

# ---------------------------------------------------------------------------
# 4. WAS profiles breakdown
# ---------------------------------------------------------------------------
section "4. WAS PROFILES BREAKDOWN"

echo "Overall WAS base:" >> "$REPORT"
du -hs "$WAS_BASE" >> "$REPORT" 2>&1
echo "" >> "$REPORT"

echo "Per-profile sizes:" >> "$REPORT"
du -hs "$WAS_BASE"/*/ 2>/dev/null | sort -rh >> "$REPORT"
echo "" >> "$REPORT"

for profile_dir in "$WAS_BASE"/*/; do
    pname=$(basename "$profile_dir")
    echo "--- ${pname} (depth 2) ---" >> "$REPORT"
    du -h --max-depth=2 "$profile_dir" 2>/dev/null | sort -rh | head -20 >> "$REPORT"
    echo "" >> "$REPORT"
done

# ---------------------------------------------------------------------------
# 5. WAS temp / wstemp / tranlog / workspace (safe to clean)
# ---------------------------------------------------------------------------
section "5. WAS TEMP & CACHE DIRECTORIES (candidates for cleanup)"

for profile_dir in "$WAS_BASE"/*/; do
    pname=$(basename "$profile_dir")
    echo "=== ${pname} ===" >> "$REPORT"

    for subdir in temp wstemp tranlog workspace config/temp config/backup; do
        target="${profile_dir}${subdir}"
        if [ -d "$target" ]; then
            size=$(du -hs "$target" 2>/dev/null | awk '{print $1}')
            count=$(find "$target" -type f 2>/dev/null | wc -l)
            echo "  ${subdir}: ${size} (${count} files)" >> "$REPORT"
        fi
    done
    echo "" >> "$REPORT"
done

# ---------------------------------------------------------------------------
# 6. WAS log files — all profiles (candidates for rotation)
# ---------------------------------------------------------------------------
section "6. WAS LOG FILES — SIZE BREAKDOWN"

for profile_dir in "$WAS_BASE"/*/; do
    pname=$(basename "$profile_dir")
    logs_dir="${profile_dir}logs"
    if [ -d "$logs_dir" ]; then
        echo "--- ${pname}/logs ---" >> "$REPORT"
        du -h --max-depth=2 "$logs_dir" 2>/dev/null | sort -rh | head -20 >> "$REPORT"
        echo "" >> "$REPORT"
    fi
done

# ---------------------------------------------------------------------------
# 7. Large files (>10MB) on root filesystem
# ---------------------------------------------------------------------------
section "7. LARGE FILES (>10MB) ON ROOT FILESYSTEM"

echo "(excluding /opt, /proc, /sys, /dev)" >> "$REPORT"
echo "" >> "$REPORT"
find / -xdev -type f -size +10M \
    -not -path "/proc/*" \
    -not -path "/sys/*" \
    -not -path "/dev/*" \
    -exec ls -lhS {} + 2>/dev/null | sort -k5 -rh | head -40 >> "$REPORT"

# ---------------------------------------------------------------------------
# 8. Large files on /opt
# ---------------------------------------------------------------------------
section "8. LARGE FILES (>10MB) ON /opt"

find /opt -type f -size +10M \
    -exec ls -lhS {} + 2>/dev/null | sort -k5 -rh | head -40 >> "$REPORT"

# ---------------------------------------------------------------------------
# 9. Core dumps and heap dumps
# ---------------------------------------------------------------------------
section "9. CORE DUMPS, HEAP DUMPS & CRASH FILES"

echo "Searching for core dumps, heap dumps, and javacore files..." >> "$REPORT"
echo "" >> "$REPORT"

found=0
for pattern in "core.*" "heapdump*" "javacore*" "Snap*" "*.phd" "*.hprof" "hs_err_*.log"; do
    results=$(find / -xdev -name "$pattern" -type f 2>/dev/null)
    if [ -n "$results" ]; then
        echo "$results" | while read f; do
            ls -lh "$f" 2>/dev/null >> "$REPORT"
        done
        found=1
    fi
done

# Also check WAS profiles for crash artifacts
for profile_dir in "$WAS_BASE"/*/; do
    results=$(find "$profile_dir" -name "core.*" -o -name "heapdump*" -o -name "javacore*" -o -name "Snap*" -o -name "*.phd" 2>/dev/null)
    if [ -n "$results" ]; then
        echo "$results" | while read f; do
            ls -lh "$f" 2>/dev/null >> "$REPORT"
        done
        found=1
    fi
done

if [ "$found" -eq 0 ]; then
    echo "  No core/heap dumps found" >> "$REPORT"
fi

# ---------------------------------------------------------------------------
# 10. /tmp breakdown
# ---------------------------------------------------------------------------
section "10. /tmp BREAKDOWN"

du -hx --max-depth=1 /tmp 2>/dev/null | sort -rh | head -20 >> "$REPORT"
echo "" >> "$REPORT"
echo "Old files in /tmp (>7 days):" >> "$REPORT"
find /tmp -xdev -type f -mtime +7 -exec ls -lhS {} + 2>/dev/null | sort -k5 -rh | head -20 >> "$REPORT"

# ---------------------------------------------------------------------------
# 11. /var/log breakdown
# ---------------------------------------------------------------------------
section "11. /var/log BREAKDOWN"

du -h --max-depth=2 /var/log 2>/dev/null | sort -rh | head -20 >> "$REPORT"
echo "" >> "$REPORT"
echo "Large log files (>5MB):" >> "$REPORT"
find /var/log -type f -size +5M -exec ls -lhS {} + 2>/dev/null | sort -k5 -rh | head -20 >> "$REPORT"

# ---------------------------------------------------------------------------
# 12. Beanstore / application data
# ---------------------------------------------------------------------------
section "12. BEANSTORE & APPLICATION DATA"

for dir in /beanstore /pcms; do
    if [ -d "$dir" ]; then
        echo "--- ${dir} ---" >> "$REPORT"
        du -h --max-depth=2 "$dir" 2>/dev/null | sort -rh | head -20 >> "$REPORT"
        echo "" >> "$REPORT"
    fi
done

# ---------------------------------------------------------------------------
# 13. Cleanup recommendations summary
# ---------------------------------------------------------------------------
section "13. CLEANUP CANDIDATES SUMMARY"

echo "The following are typically safe to clean on a WAS server:" >> "$REPORT"
echo "" >> "$REPORT"

total_reclaimable=0

for profile_dir in "$WAS_BASE"/*/; do
    pname=$(basename "$profile_dir")
    for subdir in temp wstemp tranlog workspace; do
        target="${profile_dir}${subdir}"
        if [ -d "$target" ]; then
            size_kb=$(du -sk "$target" 2>/dev/null | awk '{print $1}')
            size_h=$(du -hs "$target" 2>/dev/null | awk '{print $1}')
            if [ "${size_kb:-0}" -gt 1024 ]; then
                echo "  [CLEAN] ${pname}/${subdir}: ${size_h}" >> "$REPORT"
                total_reclaimable=$((total_reclaimable + size_kb))
            fi
        fi
    done
done

# Old FFDC files
for profile_dir in "$WAS_BASE"/*/; do
    pname=$(basename "$profile_dir")
    ffdc="${profile_dir}logs/ffdc"
    if [ -d "$ffdc" ]; then
        old_ffdc_kb=$(find "$ffdc" -type f -mtime +30 -exec du -sk {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
        if [ "${old_ffdc_kb:-0}" -gt 100 ]; then
            old_ffdc_h=$(echo "${old_ffdc_kb}" | awk '{printf "%.1fM", $1/1024}')
            echo "  [CLEAN] ${pname}/logs/ffdc (>30 days old): ${old_ffdc_h}" >> "$REPORT"
            total_reclaimable=$((total_reclaimable + old_ffdc_kb))
        fi
    fi
done

# Old rotated logs
for profile_dir in "$WAS_BASE"/*/; do
    pname=$(basename "$profile_dir")
    logs="${profile_dir}logs"
    if [ -d "$logs" ]; then
        old_logs_kb=$(find "$logs" -type f \( -name "*.log_*" -o -name "SystemOut_*" -o -name "SystemErr_*" -o -name "*.log.[0-9]*" \) -mtime +14 -exec du -sk {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
        if [ "${old_logs_kb:-0}" -gt 100 ]; then
            old_logs_h=$(echo "${old_logs_kb}" | awk '{printf "%.1fM", $1/1024}')
            echo "  [CLEAN] ${pname}/logs (rotated logs >14 days): ${old_logs_h}" >> "$REPORT"
            total_reclaimable=$((total_reclaimable + old_logs_kb))
        fi
    fi
done

# Core dumps
core_kb=$(find / -xdev \( -name "core.*" -o -name "heapdump*" -o -name "javacore*" -o -name "Snap*" -o -name "*.phd" -o -name "*.hprof" \) -type f -exec du -sk {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
if [ "${core_kb:-0}" -gt 100 ]; then
    core_h=$(echo "${core_kb}" | awk '{printf "%.1fM", $1/1024}')
    echo "  [CLEAN] Core/heap dumps across filesystem: ${core_h}" >> "$REPORT"
    total_reclaimable=$((total_reclaimable + core_kb))
fi

# Old /tmp files
tmp_old_kb=$(find /tmp -xdev -type f -mtime +7 -exec du -sk {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
if [ "${tmp_old_kb:-0}" -gt 1024 ]; then
    tmp_old_h=$(echo "${tmp_old_kb}" | awk '{printf "%.1fM", $1/1024}')
    echo "  [CLEAN] /tmp files older than 7 days: ${tmp_old_h}" >> "$REPORT"
    total_reclaimable=$((total_reclaimable + tmp_old_kb))
fi

echo "" >> "$REPORT"
total_h=$(echo "${total_reclaimable}" | awk '{printf "%.1fM", $1/1024}')
echo "  ESTIMATED RECLAIMABLE: ~${total_h}" >> "$REPORT"
echo "" >> "$REPORT"
echo "  NOTE: Stop WAS servers before cleaning temp/wstemp/tranlog directories." >> "$REPORT"
echo "  NOTE: Review large files in section 7/8 for additional space recovery." >> "$REPORT"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
section "END OF DISK ANALYSIS"

chmod 644 "$REPORT" 2>/dev/null
echo "DISK_ANALYSIS_COLLECTED"

#!/bin/bash
# =============================================================================
# Cluster Health Check — Cluster-Lab
# =============================================================================
# Runs on any node to check the health of the Slurm cluster.
# Designed for cron (every 5 min) or on-demand.
#
# Usage:
#   ./scripts/monitoring/cluster_health.sh          # all checks
#   ./scripts/monitoring/cluster_health.sh slurm     # Slurm only
#   ./scripts/monitoring/cluster_health.sh system    # system only
#   ./scripts/monitoring/cluster_health.sh nfs       # NFS only
# =============================================================================

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-cluster-lab}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
PASS=0
FAIL=0
WARN=0

print_status() {
    local status="$1" msg="$2"
    case "$status" in
        PASS) echo "  ✅ $msg"; ((PASS++));;
        WARN) echo "  ⚠️  $msg"; ((WARN++));;
        FAIL) echo "  ❌ $msg"; ((FAIL++));;
    esac
}

check_slurm() {
    echo ""
    echo "── Slurm Status ──────────────────────────────────"

    # slurmctld
    if pidof slurmctld &>/dev/null; then
        print_status PASS "slurmctld running (PID $(pidof slurmctld))"
    else
        print_status FAIL "slurmctld NOT running"
    fi

    # slurmd
    if pidof slurmd &>/dev/null; then
        local slurmd_pids
        slurmd_pids=$(pidof slurmd | wc -w)
        print_status PASS "slurmd running (${slurmd_pids} instance(s))"
    else
        print_status FAIL "slurmd NOT running"
    fi

    # Munge
    if pidof munged &>/dev/null; then
        print_status PASS "munged running"
    else
        print_status WARN "munged NOT running"
    fi

    # sinfo
    if command -v sinfo &>/dev/null; then
        local sinfo_out
        sinfo_out=$(sinfo -o '%P %D %t %c %m %N' --noheader 2>/dev/null || true)
        if [ -n "$sinfo_out" ]; then
            echo "  ✅ sinfo — partitions:"
            echo "$sinfo_out" | while read -r line; do
                echo "       $line"
            done
        else
            print_status WARN "sinfo returned no data (cluster may be idle)"
        fi
    fi

    # squeue
    if command -v squeue &>/dev/null; then
        local squeue_count
        squeue_count=$(squeue --noheader 2>/dev/null | wc -l)
        print_status PASS "squeue shows ${squeue_count} job(s)"
    fi

    # sacct (if slurmdbd)
    if command -v sacct &>/dev/null; then
        local recent_jobs
        recent_jobs=$(sacct -X -n -S "now-1day" --format=JobID,State 2>/dev/null | wc -l)
        print_status PASS "sacct records: ${recent_jobs} recent job(s)"
    fi
}

check_system() {
    echo ""
    echo "── System Status ─────────────────────────────────"

    # CPU load
    local load
    load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | sed 's/ //')
    print_status PASS "CPU load: ${load}"

    # Memory
    local mem_total mem_used mem_pct
    mem_total=$(free -m | awk '/Mem:/{print $2}')
    mem_used=$(free -m | awk '/Mem:/{print $3}')
    mem_pct=$(( mem_used * 100 / mem_total ))
    if [ "$mem_pct" -lt 70 ]; then
        print_status PASS "Memory: ${mem_used}M / ${mem_total}M (${mem_pct}%)"
    elif [ "$mem_pct" -lt 90 ]; then
        print_status WARN "Memory: ${mem_used}M / ${mem_total}M (${mem_pct}%)"
    else
        print_status FAIL "Memory: ${mem_used}M / ${mem_total}M (${mem_pct}%)"
    fi

    # Disk
    local disk_pct
    disk_pct=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' | sed 's/%//')
    if [ "$disk_pct" -lt 70 ]; then
        print_status PASS "Disk: $(df -h / 2>/dev/null | awk 'NR==2{print $3}') / $(df -h / 2>/dev/null | awk 'NR==2{print $2}') (${disk_pct}%)"
    elif [ "$disk_pct" -lt 90 ]; then
        print_status WARN "Disk: ${disk_pct}% used"
    else
        print_status FAIL "Disk: ${disk_pct}% used — CRITICAL"
    fi

    # Uptime
    print_status PASS "Uptime: $(uptime -p 2>/dev/null || echo 'N/A')"

    # Docker container check
    if [ -f /.dockerenv ]; then
        print_status PASS "Running inside Docker container"
    else
        print_status WARN "Not running inside Docker"
    fi

    # Hostname
    print_status PASS "Host: $(hostname)"
}

check_nfs() {
    echo ""
    echo "── NFS Status ────────────────────────────────────"

    # showmount
    if command -v showmount &>/dev/null; then
        local exports
        exports=$(showmount -e localhost 2>/dev/null || true)
        if [ -n "$exports" ]; then
            echo "  ✅ NFS exports:"
            echo "$exports" | while read -r line; do
                echo "       $line"
            done
        else
            print_status WARN "showmount returned no exports"
        fi
    fi

    # mount check
    if mount | grep -q nfs; then
        print_status PASS "NFS mount(s) active:"
        mount | grep nfs | while read -r line; do
            echo "       $line"
        done
    else
        print_status WARN "No active NFS mounts"
    fi

    # nfs-kernel-server
    if pidof nfsd &>/dev/null; then
        print_status PASS "NFS server running"
    else
        print_status WARN "NFS server not running on this node"
    fi
}

print_summary() {
    local total=$((PASS + FAIL + WARN))
    echo ""
    echo "─── Summary ─────────────────────────────────────"
    echo "  Cluster:  ${CLUSTER_NAME}"
    echo "  Time:     ${TIMESTAMP}"
    echo "  Host:     $(hostname)"
    echo "  Results:  ✅ ${PASS} passed | ⚠️  ${WARN} warnings | ❌ ${FAIL} failed"
    echo "─────────────────────────────────────────────────"

    if [ "$FAIL" -gt 0 ]; then
        return 1
    elif [ "$WARN" -gt 0 ]; then
        return 2
    else
        return 0
    fi
}

# --- Main ---
echo "==========================================="
echo "  ${CLUSTER_NAME} — Cluster Health Report"
echo "  ${TIMESTAMP}"
echo "==========================================="

case "${1:-all}" in
    slurm)     check_slurm;;
    system)    check_system;;
    nfs)       check_nfs;;
    all|*)
        check_system
        check_slurm
        check_nfs
        ;;
esac

print_summary
exit $?

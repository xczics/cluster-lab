#!/bin/bash
# Cluster-Lab Comprehensive Verification Script
# Usage: docker exec slurmctl bash /home/scripts/test-cluster.sh

set -e

PASS=0
FAIL=0
FAILURES=()

log_pass() { echo "  ✅ PASS: $1"; ((PASS++)); }
log_fail() { echo "  ❌ FAIL: $1"; ((FAIL++)); FAILURES+=("$1"); }
header() { echo; echo "===== $1 ====="; }

# ── Preliminary checks ──
header "Preliminary: Container connectivity"

echo "Controller: $(hostname)"
echo "User: $(whoami)"

# ── 1. Cluster status ──
header "1. Slurm Node Status"

if sinfo --noheader -o "%t" 2>/dev/null | grep -q "idle"; then
  log_pass "sinfo shows idle nodes"
else
  log_fail "sinfo: no idle nodes"
fi

NODES=$(sinfo --noheader -o "%D" 2>/dev/null | head -1)
echo "  Nodes detected: $NODES"

# ── 2. srun hostname (single node) ──
header "2. srun hostname (single node)"

OUT=$(srun --nodes=1 hostname 2>&1)
if echo "$OUT" | grep -qE "node0[12]|slurmctl"; then
  log_pass "srun hostname: $OUT"
else
  log_fail "srun hostname: $OUT"
fi

# ── 3. srun -N 2 (cross-node) ──
header "3. srun -N 2 hostname (cross-node)"

OUT=$(srun -N 2 hostname 2>&1)
HOSTS=$(echo "$OUT" | sort -u | tr '\n' ' ')
HOST_COUNT=$(echo "$OUT" | sort -u | wc -l)
if [ "$HOST_COUNT" -ge 2 ]; then
  log_pass "srun -N 2 reached nodes: $HOSTS"
else
  log_fail "srun -N 2 only got $HOST_COUNT unique host(s): $OUT"
fi

# ── 4. NFS test ──
header "4. NFS Shared Filesystem"

echo "cross-node test" > /tmp/nfs_test_$$.txt
if ssh node01 "cat /tmp/nfs_test_$$.txt" 2>/dev/null | grep -q "cross-node"; then
  log_pass "NFS: write on controller, read on node01"
else
  log_fail "NFS: cross-node read failed"
fi
rm -f /tmp/nfs_test_$$.txt

# ── 5. Compile MPI ──
header "5. Compile MPI test program"

if mpicc -o /tmp/hello_mpi_test /home/tests/hello_mpi.c -lm 2>&1; then
  log_pass "mpicc compile OK"
else
  log_fail "mpicc compile failed"
fi

# ── 6. MPI cross-node via srun ──
header "6. MPI cross-node (srun --mpi=pmix)"

OUT=$(srun -N 2 -n 2 --mpi=pmix /tmp/hello_mpi_test 2>&1)
PROC_COUNT=$(echo "$OUT" | grep -c "Hello from MPI process")
if [ "$PROC_COUNT" -ge 2 ]; then
  log_pass "MPI cross-node: $PROC_COUNT processes ($(echo "$OUT" | tr '\n' '; '))"
else
  log_fail "MPI cross-node: only $PROC_COUNT processes: $OUT"
fi
rm -f /tmp/hello_mpi_test

# ── 7. Compile OpenMP ──
header "7. Compile OpenMP test program"

if gcc -fopenmp -o /tmp/hello_openmp_test /home/tests/hello_openmp.c -lm 2>&1; then
  log_pass "gcc -fopenmp compile OK"
else
  log_fail "gcc -fopenmp compile failed"
fi

# ── 8. OpenMP ──
header "8. OpenMP (srun)"

OUT=$(srun --cpus-per-task=4 /tmp/hello_openmp_test 2>&1)
THREAD_COUNT=$(echo "$OUT" | grep -oP '\d+ threads' | grep -oP '\d+')
if [ "$THREAD_COUNT" -ge 2 ]; then
  log_pass "OpenMP: $THREAD_COUNT threads"
else
  log_fail "OpenMP: only $THREAD_COUNT threads: $OUT"
fi
rm -f /tmp/hello_openmp_test

# ── 9. module load ──
header "9. Lmod module system"

module load gcc/13.3.0 openmpi/4.1.6 2>&1
if module list 2>&1 | grep -q "openmpi"; then
  log_pass "module load gcc/13.3.0 openmpi/4.1.6 OK"
else
  log_fail "module load failed"
fi

# ── 10. srun with module ──
header "10. srun with loaded modules"

OUT=$(srun which mpirun 2>&1)
if echo "$OUT" | grep -q "openmpi"; then
  log_pass "srun with module: mpirun at $OUT"
else
  log_fail "srun with module: mpirun not found: $OUT"
fi

# ── 11. sbatch test ──
header "11. sbatch submission test"

JOB_ID=$(sbatch --parsable /home/scripts/jobs/hello_openmp.sbatch 2>&1)
if echo "$JOB_ID" | grep -qE '^[0-9]+'; then
  log_pass "sbatch submitted: job $JOB_ID"
  sleep 2
  sacct -j "$JOB_ID" --noheader --format=State 2>/dev/null | head -1 | grep -qE 'COMPLETED|RUNNING' && \
    log_pass "sbatch job $JOB_ID OK" || log_fail "sbatch job $JOB_ID state unclear"
else
  log_fail "sbatch failed: $JOB_ID"
fi

# ── Summary ──
echo
echo "═══════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "Failed checks:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  echo
  echo "❌ Some checks failed — review above."
  exit 1
else
  echo "✅ ALL CHECKS PASSED!"
  exit 0
fi

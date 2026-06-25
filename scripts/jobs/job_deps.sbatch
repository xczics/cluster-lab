#!/bin/bash
#SBATCH --job-name=job_deps_demo
#SBATCH --output=job_deps_%j.out
#SBATCH --error=job_deps_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:02:00

# ============================================================
# Job Dependency Examples — Cluster-Lab
# ============================================================
# Shows how Slurm job dependencies work.
#
# Step-by-step submission:
#
#   # Step 1: Submit the "producer" job (gets JOBID)
#   JOBID=$(sbatch --parsable scripts/jobs/job_deps.sbatch \
#     --export=STEP=produce)
#
#   # Step 2: Submit dependent job (runs AFTER producer succeeds)
#   sbatch --dependency=afterok:$JOBID scripts/jobs/job_deps.sbatch \
#     --export=STEP=consume,JOBID_DEP=$JOBID
#
# Dependency types:
#   afterok:JOBID     — run after job completes successfully (exit 0)
#   afternotok:JOBID  — run after job fails (exit != 0)
#   afterany:JOBID    — run after job finishes (any exit code)
#   after:JOBID       — run after job starts (not finishes)
#   aftercorr:JOBID   — run after job completes with same job array spec
#   singleton         — ensure no other job with same name runs concurrently
# ============================================================

STEP=${STEP:-produce}

if [ "$STEP" = "produce" ]; then
    echo "========================================"
    echo "Producer Step — Job Dependency Demo"
    echo "========================================"
    echo "Job ID:   ${SLURM_JOB_ID}"
    echo "Node:     $(hostname)"
    echo "Date:     $(date)"
    echo "========================================"
    echo "Generating simulation data..."
    sleep 10
    echo "Critical value: $(( RANDOM % 100 ))" > /tmp/dep_output_${SLURM_JOB_ID}.txt
    echo "Data written to /tmp/dep_output_${SLURM_JOB_ID}.txt"
    echo "Producer complete! Status: SUCCESS"
    exit 0

elif [ "$STEP" = "consume" ]; then
    echo "========================================"
    echo "Consumer Step — Job Dependency Demo"
    echo "========================================"
    echo "Job ID:    ${SLURM_JOB_ID}"
    echo "Depends on: ${JOBID_DEP:-unknown}"
    echo "Node:      $(hostname)"
    echo "Date:      $(date)"
    echo "========================================"
    if [ -f "/tmp/dep_output_${JOBID_DEP}.txt" ]; then
        echo "Reading output from producer job ${JOBID_DEP}:"
        cat "/tmp/dep_output_${JOBID_DEP}.txt"
        echo "Consumer processing complete!"
    else
        echo "WARNING: Producer output not found at /tmp/dep_output_${JOBID_DEP}.txt"
        echo "(This is expected if producer ran on a different node without NFS)"
    fi
    echo "Consumer complete!"

elif [ "$STEP" = "fail" ]; then
    echo "========================================"
    echo "Failing Step — For dependency testing"
    echo "========================================"
    echo "This job is INTENTIONALLY failing to demonstrate"
    echo "afternotok / afterany dependency behavior."
    echo "========================================"
    sleep 5
    echo "About to fail..."
    exit 1

else
    echo "Unknown STEP: $STEP"
    echo "Valid values: produce, consume, fail"
    exit 1
fi

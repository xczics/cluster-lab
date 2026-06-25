#!/bin/bash
#SBATCH --job-name=job_array_demo
#SBATCH --output=job_array_%A_%a.out
#SBATCH --error=job_array_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00

# ============================================================
# Job Array Example — Cluster-Lab
# ============================================================
# Submit with:     sbatch --array=1-10 jobs/job_array.sbatch
# Submit specific: sbatch --array=1,3,5 jobs/job_array.sbatch
# Submit range:    sbatch --array=1-10:2 jobs/job_array.sbatch (odd only)
# Check status:    squeue --name=job_array_demo
# ============================================================
#
# Slurm environment variables in array jobs:
#   SLURM_ARRAY_JOB_ID    — parent job ID
#   SLURM_ARRAY_TASK_ID   — current task index (1, 2, 3, ...)
#   SLURM_ARRAY_TASK_COUNT — total number of tasks
#   SLURM_ARRAY_TASK_MAX  — maximum task index
#   SLURM_ARRAY_TASK_MIN  — minimum task index

echo "========================================"
echo "Job Array Demo — Cluster-Lab"
echo "========================================"
echo "Array Job ID:    ${SLURM_ARRAY_JOB_ID}"
echo "Task ID:         ${SLURM_ARRAY_TASK_ID}"
echo "Task Count:      ${SLURM_ARRAY_TASK_COUNT}"
echo "Task Range:      ${SLURM_ARRAY_TASK_MIN} — ${SLURM_ARRAY_TASK_MAX}"
echo "Node:            $(hostname)"
echo "Date:            $(date)"
echo "========================================"

# Simulate work proportional to task ID
WORK_SECONDS=$(( SLURM_ARRAY_TASK_ID * 2 ))
echo "Task #${SLURM_ARRAY_TASK_ID}: Working for ${WORK_SECONDS} seconds..."
sleep ${WORK_SECONDS}
echo "Task #${SLURM_ARRAY_TASK_ID}: Complete!"

# Generate task-specific output
echo "Result for task ${SLURM_ARRAY_TASK_ID}: $(( SLURM_ARRAY_TASK_ID * 100 + RANDOM % 100 ))" > task_${SLURM_ARRAY_TASK_ID}_result.txt
echo "Results written to task_${SLURM_ARRAY_TASK_ID}_result.txt"

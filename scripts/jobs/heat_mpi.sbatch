#!/bin/bash
#SBATCH --job-name=heat_mpi
#SBATCH --output=heat_mpi_%j.out
#SBATCH --error=heat_mpi_%j.err
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --ntasks-per-node=2
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
#SBATCH --partition=normal
# Load modules (automatic gcc + openmpi dependency)
module load mpi-test/1.0

echo "Running 2D Heat Equation Solver (MPI)"
echo "Grid: 200x200, Iterations: 10000"
echo "SLURM_NODELIST: $SLURM_NODELIST"
echo "SLURM_NNODES: $SLURM_NNODES"
echo "SLURM_NTASKS: $SLURM_NTASKS"
echo "Partition: $SLURM_JOB_PARTITION"
echo "---"

# Run MPI heat solver (expect ~2 min runtime)
srun --mpi=pmix /home/user01/heat_mpi 200 10000

echo "---"
echo "Job complete! Check billing dashboard at http://slurmctl:5000"

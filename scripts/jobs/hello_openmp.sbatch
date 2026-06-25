#!/bin/bash
#SBATCH --job-name=hello_openmp
#SBATCH --output=hello_openmp_%j.out
#SBATCH --error=hello_openmp_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:05:00
#SBATCH --partition=normal

# Load modules
module load gcc/13.3.0

# Set OpenMP threads
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}

echo "Running OpenMP Hello World"
echo "OMP_NUM_THREADS: $OMP_NUM_THREADS"
echo "Host: $(hostname)"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK"
echo "---"

# Run OpenMP program
srun /home/hello_openmp

echo "---"
echo "Job complete!"

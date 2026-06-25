#!/bin/bash
#SBATCH --job-name=hello_mpi
#SBATCH --output=hello_mpi_%j.out
#SBATCH --error=hello_mpi_%j.err
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
#SBATCH --partition=normal
#SBATCH --mpi=pmix

# Load modules
module load gcc/13.3.0 openmpi/4.1.6

echo "Running MPI Hello World on $(scontrol show hostname)"
echo "SLURM_NODELIST: $SLURM_NODELIST"
echo "SLURM_NNODES: $SLURM_NNODES"
echo "SLURM_NTASKS: $SLURM_NTASKS"
echo "---"

# Run MPI program via srun
srun /home/hello_mpi

echo "---"
echo "Job complete!"

# sbatch Job Templates

Batch job submission scripts for the Cluster-Lab Slurm cluster.

## Usage

```bash
# From the controller node
docker exec slurmctl sbatch /home/scripts/jobs/hello_mpi.sbatch
docker exec slurmctl sbatch /home/scripts/jobs/hello_openmp.sbatch

# Check job status
docker exec slurmctl squeue
docker exec slurmctl sacct

# View output
cat hello_mpi_<jobid>.out
```

## Templates

| Template | Type | Nodes | Description |
|----------|------|-------|-------------|
| `hello_mpi.sbatch` | MPI | 2 | Cross-node MPI Hello World via PMIx |
| `hello_openmp.sbatch` | OpenMP | 1 | Shared-memory OpenMP with 4 threads |

## Tips

- Always `module load gcc/13.3.0 openmpi/4.1.6` before running MPI jobs
- Use `scontrol show job <jobid>` for detailed job info
- Output files are written to the working directory (`/home/` by default)
- Error files (`*_%j.err`) capture stderr

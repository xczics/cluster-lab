# 🖥️ Cluster-Lab — Local Virtual HPC Cluster

Build a small virtual HPC cluster on local macOS with Docker, to learn Slurm architecture, configuration, administration, and troubleshooting.

## Architecture

```
┌─────────────────────────────────────────────┐
│                  Docker Network              │
│             172.20.0.0/16 (cluster-net)      │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ slurmctl  │  │  node01  │  │  node02  │  │
│  │(controller)│  │(compute) │  │(compute) │  │
│  │ 172.20.0.2 │  │172.20.0.3│  │172.20.0.4│  │
│  │ slurmctld  │  │  slurmd  │  │  slurmd  │  │
│  │ mariadb    │  │          │  │          │  │
│  │ munge      │  │  munge   │  │  munge   │  │
│  │ nfs-server │  │  nfs-cli │  │  nfs-cli │  │
│  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────┘
```

- **slurmctl** — Controller node: slurmctld + slurmdbd + mariadb + NFS server
- **node01/node02** — Compute nodes: slurmd + NFS client (mounts /home /scratch)

## Directory Structure

```
cluster-lab/
├── README.md              # This file
├── docker/
│   ├── Dockerfile         # Unified image (controller + compute)
│   ├── docker-compose.yml # Multi-container orchestration
│   └── entrypoint.sh      # Container entrypoint, starts services by role
├── config/
│   ├── slurm/
│   │   ├── slurm.conf     # Slurm main configuration
│   │   └── cgroup.conf    # cgroup constraints
│   ├── nfs/
│   │   └── exports        # NFS share configuration
│   └── ssh/
├── scripts/
│   ├── setup.sh           # Deployment script
│   └── test-cluster.sh    # Cluster validation (TODO)
└── journal/
    └── experiments.md     # Experiment diary (Chinese allowed)
```

## Quick Start

```bash
# 1. Build the image
docker compose -f docker/docker-compose.yml build

# 2. Start the cluster
docker compose -f docker/docker-compose.yml up -d

# 3. Check node status
docker exec slurmctl sinfo

# 4. Submit a test job
docker exec slurmctl srun -N 2 hostname
```

## Experiment Roadmap

1. ✅ Cluster startup & node registration
2. ⬜ Job submission (batch/interactive)
3. ⬜ Partition configuration
4. ⬜ QoS and priority
5. ⬜ Troubleshooting & log analysis
6. ⬜ Multi-user environment
7. ⬜ Custom resources (GRES/GPU simulation)

## Environment

- **Host**: macOS (Apple Silicon / Intel)
- **Container**: Docker (Ubuntu 24.04 LTS base image)
- **Scheduler**: Slurm 24.x
- **Auth**: Munge
- **Storage**: NFSv4

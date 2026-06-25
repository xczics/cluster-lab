# 🖥️ Cluster-Lab — Local Virtual HPC Cluster

Build a small virtual HPC cluster on local macOS with Docker, to learn Slurm architecture, configuration, administration, and troubleshooting.

**Current status: Phase 1–3 complete — MPI cross-node, OpenMP, Lmod module system all verified.**

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                 Docker Network                               │
│            172.20.0.0/16 (cluster-net)                       │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   slurmctl   │    │    node01    │    │    node02    │   │
│  │ (controller) │    │  (compute)   │    │  (compute)   │   │
│  │ 172.20.0.10  │    │ 172.20.0.11  │    │ 172.20.0.12  │   │
│  │  slurmctld   │    │   slurmd     │    │   slurmd     │   │
│  │  mariadb     │    │              │    │              │   │
│  │  munge       │    │  munge       │    │  munge       │   │
│  │  nfs-server  │    │  nfs-client  │    │  nfs-client  │   │
│  │  sshd        │    │  sshd        │    │  sshd        │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

- **slurmctl** — Controller: slurmctld + slurmdbd + mariadb + NFS server
- **node01/node02** — Compute: slurmd + NFS client (/home /scratch) + SSH

## Directory Structure

```
cluster-lab/
├── README.md                  # This file
├── LICENSE                    # MIT License
├── .gitignore                 # Docker / IDE / OS ignore rules
├── docker/
│   ├── Dockerfile             # Unified image (controller + compute)
│   ├── docker-compose.yml     # Multi-container orchestration
│   └── entrypoint.sh          # Container entrypoint by role
├── config/
│   ├── slurm/
│   │   ├── slurm.conf         # Slurm main configuration
│   │   ├── slurmdbd.conf      # SlurmDBD configuration
│   │   └── cgroup.conf        # cgroup resource isolation
│   ├── nfs/
│   │   └── exports            # NFS share definitions
│   └── modulefiles/           # Lmod modulefiles
│       ├── gcc/
│       │   └── 13.3.0.lua     # GCC module definition
│       └── openmpi/
│           └── 4.1.6.lua      # OpenMPI module definition
├── scripts/
│   └── setup.sh               # One-click deploy (check → build → up → verify)
├── tests/
│   ├── hello_mpi.c            # MPI parallel test (cross-node capable)
│   └── hello_openmp.c         # OpenMP shared-memory test
├── 日记/                      # Project diaries (Chinese)
│   ├── 日记-项目架构与设计笔记.md       # Architecture & design decisions
│   ├── 日记-部署阶段实战笔记.md        # 11 deployment pitfalls & fixes
│   └── 日记-跨节点MPI与Lmod配置.md     # MPI cross-node & module system
└── journal/                   # (planned) Experiment logs
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

# 5. Run MPI cross-node
docker exec slurmctl srun -N 2 -n 2 --mpi=pmix /home/hello_mpi
```

## Current Capabilities

| Capability | Status | Verification |
|------------|--------|-------------|
| Cluster startup (3 nodes) | ✅ | `docker ps` + `sinfo` |
| Slurm job scheduling | ✅ | `srun hostname` |
| NFS shared filesystem | ✅ | Cross-node /home access |
| OpenMP parallel computing | ✅ | `./hello_openmp` |
| MPI single-node parallel | ✅ | `srun -n 2 ./hello_mpi` |
| **MPI cross-node (srun)** | ✅ | `srun -N 2 -n 2 --mpi=pmix` |
| **MPI cross-node (SSH)** | ✅ | `mpirun --host node01,node02 -np 2` |
| Lmod module environment | ✅ | `module load gcc/13.3.0 openmpi/4.1.6` |
| Git version control | ✅ | GitHub: xczics/cluster-lab |

## Milestones

| Phase | Status | What |
|-------|--------|------|
| Phase 1: Deployment | ✅ | 11 issues resolved — Docker, Slurm, NFS, Munge, cgroup, network |
| Phase 2: Compilers & MPI | ✅ | OpenMP 4.5 + OpenMPI 4.1.6 installed and verified |
| Phase 3: Module System | ✅ | Lmod — `module load gcc/13.3.0` + `openmpi/4.1.6` |
| Phase 4: Cross-node MPI | ✅ | A+B dual approach — PMIx (srun) + SSH (mpirun) |

## MPI Cross-Node: A+B Dual Approach

### Approach A — SSH + mpirun (Quick validation)
```bash
mpirun --host node01,node02 -np 2 /home/hello_mpi
```
Independent of Slurm, uses SSH keys for node-to-node authentication.

### Approach B — PMIx + srun (HPC standard)
```bash
srun -N 2 -n 2 --mpi=pmix /home/hello_mpi
```
Fully integrated with Slurm scheduler — resource isolation, job queuing, priority.

### Verification Output
```
Hello from MPI process 1 of 2 on node02
Hello from MPI process 0 of 2 on node01
```

## Technical Stack

| Component | Detail |
|-----------|--------|
| **Host** | macOS (Apple Silicon / Intel) |
| **Container** | Docker — Ubuntu 24.04 LTS |
| **Scheduler** | Slurm 24.11.3 (apt) + PMIx integration |
| **MPI** | OpenMPI 4.1.6 — Built with `--with-pmix` |
| **OpenMP** | GCC 13.3.0 built-in |
| **Module System** | Lmod 8 (Lua 5.4) |
| **Auth** | Munge (slurmctld → slurmd) |
| **Storage** | NFS v3 (nolock) — /home + /scratch |
| **Network** | Docker custom bridge — 172.20.0.0/16 |

## Environment Details

- **Controller node** (slurmctl): slurmctld + slurmdbd + mariadb + NFS server + sshd
- **Compute nodes** (node01/node02): slurmd + NFS client + sshd
- **Container image**: Single Dockerfile, role selected by `SLURM_ROLE` env var
- **cgroup**: v1 with `linuxproc` tracking (Docker Desktop compatibility)
- **Accounting**: Disabled (`AccountingStorageType=none`) — Munge errors bypassed
- **All nodes**: Cross-mounted `/home` via NFS, shared SSH authorized_keys

## Next Steps (Planned)

- [ ] sbatch job script templates (MPI/OpenMP)
- [ ] Cluster benchmark suite (HPL, IOR)
- [ ] Multi-user environment with Slurm accounts
- [ ] QoS and priority configuration
- [ ] GRES (GPU simulation via fake GPU)
- [ ] Monitoring & log aggregation
- [ ] `test-cluster.sh` comprehensive validation script

## License

MIT

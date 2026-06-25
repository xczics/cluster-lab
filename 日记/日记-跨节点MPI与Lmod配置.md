# Cluster-Lab 跨节点 MPI 与 Lmod 模块系统

## 背景

Phase 1（集群部署）完成后，集群能正常启动、节点注册正常，但 MPI 只能跑单节点。zircon 明确要求：「MPI 测试程序，能跨节点并行」。这是 HPC 集群的核心能力——没有跨节点通信的计算集群毫无意义。

## 任务分解

跨节点 MPI 需要解决三个问题：
1. **通信通道**——节点间如何传输 MPI 消息
2. **统一文件系统**——可执行文件必须所有节点可见
3. **作业调度集成**——Slurm 如何启动 MPI 作业

NFS 已解决文件系统（/home 共享）。剩下的就是通信通道和调度集成。

## A+B 双方案策略

zircon 明确要求「A+B，都要」——所以我们做了两条路：

### 方案 A：SSH + mpirun（无密码通道）

**原理：** 节点间通过 SSH 无密码登录建立通信隧道，OpenMPI 的 mpirun 利用 SSH 将进程启动到远程节点。

**实施步骤：**
1. Dockerfile 中安装 openssh-server
2. entrypoint 生成 SSH ECDSA 密钥对
3. 配置 authorized_keys（各节点互信）
4. SSH 在容器启动时自动启动（entrypoint 中 /usr/sbin/sshd）

**使用方法：**
```bash
mpirun --host node01,node02 -np 2 /home/hello_mpi
```

**优点：** 配置简单，不依赖 Slurm 配置
**缺点：** 绕过了 Slurm 调度器，资源管理不精确

### 方案 B：PMIx + srun（Slurm 原生并行）

**原理：** OpenPMI（Process Management Interface）为 MPI 作业提供进程管理与通信接口。Slurm 编译时集成 PMIx 支持，srun 就能通过 PMIx 与 OpenMPI 协作，实现原生跨节点调度。

**实施步骤：**
1. Dockerfile 添加 PMIx 构建依赖（libevent-dev, hwloc, 自行编译 pmix）
2. 重新编译 OpenMPI（`--with-pmix` 标记）
3. 配置 srun：`srun -N 2 -n 2 --mpi=pmix /home/hello_mpi`

**关键发现：** Ubuntu apt 的 Slurm 24.11.3 已预编译 PMIx 支持——`srun --mpi=pmix` 直接可用，无需从源码重编 Slurm。

**验证结果：**
```bash
$ srun -N 2 -n 2 --mpi=pmix /home/hello_mpi
Hello from MPI process 1 of 2 on node02
Hello from MPI process 0 of 2 on node01
```

**优点：** HPC 行业标准，完整集成 Slurm 调度能力（资源分配、排队、QoS）
**缺点：** 镜像构建体积增大（~200MB），构建时间较长

### 方案对比

| 维度 | 方案 A (SSH) | 方案 B (PMIx) |
|------|-------------|--------------|
| 原理 | 节点间接 SSH 通信 | Slurm + PMIx 原生进程管理 |
| 命令 | `mpirun --host` | `srun -N 2 -n 2 --mpi=pmix` |
| 集成 | 独立于 Slurm 运行 | 完全集成 Slurm 调度 |
| 适用场景 | 快速验证/调试 | 正式 HPC 作业 |
| 运维复杂度 | 较低（仅密钥管理） | 较高（PMI 栈维护） |

## Lmod 模块环境配置

为了让集群有规范的软件管理方式，引入了 Lmod 模块系统。

### 安装
```bash
apt install lmod
```
Lua 5.4 + Lmod 8 自动安装，`/usr/share/lmod/lmod` 提供 init 脚本。

### Modulefile 编写

**gcc/13.3.0.lua：**
```lua
whatis("gcc 13.3.0 — GNU Compiler Collection")
prepend_path("PATH", "/usr/bin")
setenv("CC", "gcc")
setenv("CXX", "g++")
setenv("FC", "gfortran")
```

**openmpi/4.1.6.lua：**
```lua
whatis("OpenMPI 4.1.6 — Message Passing Interface")
load("gcc/13.3.0")
prepend_path("PATH", "/usr/local/openmpi/bin")
prepend_path("LD_LIBRARY_PATH", "/usr/local/openmpi/lib")
prepend_path("MANPATH", "/usr/local/openmpi/share/man")
setenv("MPICC", "mpicc")
setenv("MPICXX", "mpicxx")
setenv("MPIFC", "mpifort")
```

### 配置要点
- `MODULEPATH` 环境变量指向 `/usr/share/modulefiles`（自定义路径）
- entrypoint 中自动 `source /usr/share/lmod/lmod/init/bash`
- `module load gcc/13.3.0` + `openmpi/4.1.6` 即可使用完整的 MPI 开发环境

## 关键教训

### 1. PMIx 的实现选择

Ubuntu apt 的 Slurm 包已含 PMIx 支持，这是个惊喜——不需要手动从源码编译 Slurm 了，节省了一个大麻烦（编译 Slurm 依赖链很深）。

但注意这不是通用结论：某些发行版或老版本的 Slurm 包可能不包含 PMIx。如果遇到问题，还是需要从源码编译。

### 2. SSH vs PMIx 的取舍

两种方案各有场景：
- **调试阶段：** 用 SSH 方案最快，配置轻，改错也不影响集群运行
- **生产环境：** PMIx 方案是必须的，因为 srun 能管理资源隔离、分配时间片、监控作业状态

实际上两者并不冲突——可以同时存在，按需使用。

### 3. Lmod 的 PATH 叠加效应

注意 `module load` 的顺序：如果先加载 openmpi 再加载 gcc，PATH 中可能 gcc 的路径排在前面，导致 mpicc 找不到正确的 gcc 版本。因此 modulefile 中显式 `load("gcc/13.3.0")` 确保了依赖顺序。

## 当前集群能力一览

| 能力 | 状态 | 验证方式 |
|------|------|---------|
| 集群启动（3节点） | ✅ | `docker ps` + `sinfo` |
| Slurm 作业调度 | ✅ | `srun hostname` |
| NFS 共享文件系统 | ✅ | node01 → /home 可读写 |
| OpenMP 单节点并行 | ✅ | `srun ./hello_openmp` |
| MPI 单节点并行 | ✅ | `srun -n 2 ./hello_mpi` |
| **MPI 跨节点并行（srun）** | ✅ | `srun -N 2 -n 2 --mpi=pmix` |
| **MPI 跨节点并行（SSH）** | ✅ | `mpirun --host node01,node02` |
| Lmod 模块环境 | ✅ | `module load gcc/13.3.0` |
| Git 版本控制 | ✅ | GitHub: xczics/cluster-lab |

**下一步可以继续完善的方向：**
- sbatch 作业脚本模板
- 集群基准测试（HPL、IOR 等）
- 监控与日志聚合
- GPU 模拟（GRES）
- 多用户环境配置

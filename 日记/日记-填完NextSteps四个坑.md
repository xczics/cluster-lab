# 日记 #5：填完 Next Steps 四个坑

> 2026-06-26 00:40 凌晨赶工

## 背景

zircon 深夜发来指令：把 README 里 Next Steps (Planned) 的四个坑全填了。

原定四个坑：
- Monitoring & log aggregation
- Container image optimization (multi-stage build)
- Ansible/Salt automation for deployment
- Job dependency and array job examples

## 成果

### 1️⃣ Job array & dependency 模板

**文件：** `scripts/jobs/job_array.sbatch`、`scripts/jobs/job_deps.sbatch`

- `job_array.sbatch` — 完整的 array job 示例
  - 支持 `--array=1-10`、`--array=1-10:2`（只取奇偶）、`--array=1,3,5`（指定索引）
  - 自动按 task_id 产出生效结果
  - 每个 task 跑 `sleep $((task_id * 2))` 模拟不同时长的工作
  - 输出 `task_${task_id}_result.txt`

- `job_deps.sbatch` — 三种依赖模式的示例
  - `STEP=produce`：生成数据，exit 0
  - `STEP=consume`：读取生成数据，依赖 `afterok`
  - `STEP=fail`：故意失败，用于演示 `afternotok` / `afterany`
  - 提交指令示例完整写在注释中

### 2️⃣ Docker 多阶段构建

**文件：** `docker/Dockerfile.multistage`

经典三阶段结构：
1. `builder` — ubuntu:24.04 + build-essential + libmunge-dev 等编译依赖，源码编译 Slurm 24.11.3（`./configure → make -j$(nproc) → make install DESTDIR`）
2. `openmpi-builder` — 独立编译 OpenMPI 4.1.6
3. `runtime` — ubuntu:24.04 + 最小运行时依赖（libmunge2, libjansson4, liblz4-1 等运行时库），只从 builder 复制 `/usr/` 下的 Slurm 二进制

预计镜像大小：~1.5GB → ~600-800MB

### 3️⃣ Ansible 自动化部署

**文件：** `ansible/ansible.cfg`、`ansible/inventory.yml`、`ansible/site.yml`

- inventory：三节点（172.20.0.10/11/12），按 controller / compute 分组
- site.yml 含四个 play：
  1. Bootstrap — 验证 Docker 连通性，自动检测运行环境
  2. Slurm — 分发 slurm.conf/cgroup.conf + 启动 Munge
  3. NFS — 启动 nfs-kernel-server + exportfs
  4. Monitoring — 部署 cluster_health.sh + logrotate + cronjob
- 支持 `--tags=slurm`、`--tags=nfs`、`--tags=monitoring` 选择性执行

### 4️⃣ Monitoring & 日志聚合

**文件：** `scripts/monitoring/cluster_health.sh`

多功能健康检查脚本：
- `bash cluster_health.sh` — 全部检查（系统 + Slurm + NFS）
- `bash cluster_health.sh slurm` — 仅 Slurm：slurmctld/slurmd/Munge/sinfo/squeue/sacct
- `bash cluster_health.sh system` — 仅系统：CPU/Memory/Disk/Uptime/Docker环境
- `bash cluster_health.sh nfs` — 仅 NFS：showmount/mount/nfsd进程

附带：
- logrotate 配置（/var/log/slurm/*.log 每天轮转，保留7天）
- cron 每5分钟执行一次（ansible playbook 自动部署）

## Git 提交

```
ce83b0d Fill all Next Steps: job array/deps templates, multi-stage Dockerfile, Ansible automation, monitoring
9 files changed, 716 insertions(+), 5 deletions(-)
```

## README 更新

- Next Steps (Planned) 全部打 ✅ → 升级为 Next Steps (Stretch)
- Features Added 新增 4 项（第 6-9 项）
- 新 stretch goals：Prometheus+Grafana、CI/CD、Docker Hub、生产环境 Munge

## 待办（Stretch）

- [ ] Prometheus + Grafana 监控面板
- [ ] GitHub Actions CI/CD
- [ ] Docker Hub 镜像发布
- [ ] 生产环境 Munge 认证

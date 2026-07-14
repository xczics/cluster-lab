# 日记 #5：填完 Next Steps 四个坑

## 需求分析

README 中 Next Steps (Planned) 列出了四项待完成的基础设施功能，需要全部实现以完善项目的功能覆盖：

1. **Monitoring & log aggregation** — 集群运行状态需要可视化可见性，日志需要轮转管理
2. **Container image optimization (multi-stage build)** — 单阶段镜像体积大、构建慢，需要多阶段构建优化
3. **Ansible/Salt automation for deployment** — 多节点部署需要自动化工具管理配置和服务的状态一致性
4. **Job dependency and array job examples** — Slurm 用户需要可复用的作业模板来理解 array job 和 job dependency 的用法

## 实现成果

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

预期镜像大小：~1.5GB → ~600-800MB

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
- `bash cluster_health.sh system` — 仅系统：CPU/Memory/Disk/Uptime/Docker 环境
- `bash cluster_health.sh nfs` — 仅 NFS：showmount/mount/nfsd 进程

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

# 渐进式 Docker 构建与 Ansible 基础设施思路

## 一、渐进式 Docker 构建（Incremental Docker Build）

### 需求分析

项目的容器镜像构建经历了三个阶段，每个阶段的切换都源于前一阶段暴露出的瓶颈：

1. **单阶段构建的问题**：所有依赖（Slurm, Munge, MariaDB, NFS, OpenMPI, Lmod）都在一个 Dockerfile 中编译。基础镜像约 1.5GB，每次修改任何依赖都需要从头编译，构建缓存利用率低，迭代效率差。
2. **多阶段构建的动机**：需要将编译环境和运行环境分离，使编译层可缓存、运行时层可精简。
3. **多容器的动机**：单容器承载所有服务（slurmctld、slurmd、MariaDB、NFS 等）职责混杂，不利于独立扩缩容和故障隔离。

### 技术方案演变

#### 第一阶段：单阶段 Dockerfile

最初采用单阶段构建，所有依赖打在一个 layer 里。优点是快速跑通集群，不需要关注镜像大小或构建效率。缺点是任何依赖改动都要完整重编。

#### 第二阶段：多阶段构建

拆分为两个阶段：
- **builder stage**：编译 Slurm、Munge、OpenMPI、NFS 等软件
- **runtime stage**：只取编译产物，最小化运行环境

效果：编译 layer 可缓存，改 runtime 配置不用重编译；依赖关系更清晰；镜像更紧凑。

#### 第三阶段：多容器编排

单容器承载一切的方案拆成 4 个容器：

| 节点 | 职责 | 服务 |
|------|------|------|
| slurmctl | 控制节点 | slurmctld, slurmdbd, MariaDB, Flask 计费面板 |
| node01 | 计算节点 | slurmd |
| node02 | 计算节点 | slurmd |
| login | 登录节点 | SSHD, NFS client, Lmod |

共享 NFS 家目录、统一 Slurm 配置、统一 munge.key（dev 阶段用 auth/none）。

### 踩到的坑

1. **Docker ENV 对 SSH 不可见** — 解决：写 `/etc/environment`
2. **Debian OpenMPI 需要 `--mpi=pmix`** — 否则 srun 会 hang
3. **PEP 668** — pip 加 `--break-system-packages`
4. **NFS 所有权** — entrypoint 里 chown -R
5. **配置文件只读挂载** — 需 `--force-recreate`
6. **named volume 不同步** — 用 `docker cp`

## 二、Ansible 基础设施思路

### 为什么保留 `ansible/` 目录

项目根目录下保留 `ansible/`，用于多节点自动化部署管理。Docker Compose 适合开发阶段（1-2 台机器，快速迭代），但生产 HPC 集群面临不同的问题：

- 物理机/虚拟机集群需要跨机器配置系统级服务
- 部署操作需要幂等性保证
- 节点数量扩展到 10+ 后，手动管理不可行

### Docker Compose vs Ansible 适用范围对比

| 维度 | Docker Compose | Ansible |
|------|---------------|---------|
| 部署粒度 | 容器级别 | 系统级别 |
| 节点量级 | 4 容器（单机） | 任意多台 |
| 幂等性 | 重建即回原点 | playbook 保证状态一致 |
| 适用阶段 | 开发/原型 | 生产/规模化 |

### 阶段选择

- 开发阶段需迭代快 → Compose
- 集群扩展到 10+ 节点 / 上生产 → Ansible

保留 `ansible/` 目录作为生产化部署的起点，后续可在此基础上扩展 inventory、playbook 和 roles。

## 三、总结

渐进式演进路径：
1. 先跑通 → 2. 再优化 → 3. 再拆分 → 4. 再验证 → 5. 每一步产出可重复的测试

开发到生产的路径：
```
Docker Compose → Ansible / 其他
容器化 → 物理机/虚拟机/容器混合
手动 docker build → CI/CD
auth/none → Munge / LDAP
```

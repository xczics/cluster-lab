FROM ubuntu:24.04

LABEL description="Cluster-Lab: Slurm HPC Node"
LABEL maintainer="agent-yuan / zircon"

# 环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV SLURM_VERSION=24.11.3
ENV TZ=Europe/Copenhagen
ENV MODULEPATH=/usr/share/modules/modulefiles

# 系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Slurm 依赖
    build-essential \
    munge \
    libmunge-dev \
    libmunge2 \
    libssl-dev \
    libpam0g-dev \
    libncurses-dev \
    libreadline-dev \
    libhdf5-dev \
    # MariaDB / SlurmDBD
    mariadb-server \
    libmariadb-dev \
    # NFS
    nfs-kernel-server \
    nfs-common \
    # 工具
    vim \
    curl \
    wget \
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    lsof \
    strace \
    less \
    sudo \
    # Python
    python3 \
    python3-pip \
    # Environment Modules (Lmod)
    lmod \
    lua5.4 \
    # SSH (for mpirun cross-node)
    openssh-server \
    # PMIx (for srun --mpi=pmix)
    libpmix-dev \
    # OpenMPI
    openmpi-bin \
    libopenmpi-dev \
    # slurmrestd 依赖
    libhttp-parser-dev \
    libjson-c-dev \
    && rm -rf /var/lib/apt/lists/*

# Billing dashboard
RUN pip3 install --break-system-packages flask requests

# 下载并编译 Slurm
WORKDIR /tmp
RUN set -ex \
    && wget -q https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 \
    && tar xf slurm-${SLURM_VERSION}.tar.bz2 \
    && cd slurm-${SLURM_VERSION} \
    && ./configure \
        --prefix=/usr \
        --sysconfdir=/etc/slurm \
        --enable-slurmrestd \
        --with-munge=/usr \
        --with-mysql=/usr \
        --with-hdf5=no \
        --with-pmix=/usr/lib/aarch64-linux-gnu/pmix2 \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/slurm-*

# 创建 Slurm 运行时目录
RUN mkdir -p /var/{log,run,spool}/slurm \
    && mkdir -p /var/spool/slurm/d \
    && mkdir -p /etc/slurm \
    && chmod 755 /var/{log,run,spool}/slurm

# 创建 slurm 用户（UID/GID 统一跨节点）
RUN groupadd -r -g 64030 slurm \
    && useradd -r -g slurm -u 64030 -s /bin/false slurm \
    && mkdir -p /home/slurm && chown slurm:slurm /home/slurm && chmod 755 /home/slurm

# 配置 Munge 密钥
RUN mkdir -p /etc/munge \
    && /usr/sbin/mungekey --force \
    && chown -R munge:munge /etc/munge \
    && chmod 0700 /etc/munge \
    && chmod 0400 /etc/munge/munge.key

# 配置文件
COPY config/slurm/slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN chmod 600 /etc/slurm/slurmdbd.conf

# Lmod 环境模块（SSH 登录 shell 不继承 Docker ENV，需多重路径）
ENV MODULEPATH=/usr/share/modules/modulefiles
# /etc/lmod/modulespath: lmod.sh 有此文件则读取，加入 MODULEPATH
# /etc/environment: SSH PAM 读取此文件设环境变量
RUN mkdir -p /etc/lmod \
    && echo "/usr/share/modules/modulefiles" > /etc/lmod/modulespath \
    && echo "MODULEPATH=/usr/share/modules/modulefiles" >> /etc/environment
COPY config/modulefiles /usr/share/modules/modulefiles
RUN echo "source /usr/share/lmod/lmod/init/bash" >> /etc/bash.bashrc \
    && echo "source /usr/share/lmod/lmod/init/bash" >> /etc/skel/.bashrc \
    && echo "source /usr/share/lmod/lmod/init/bash" >> /root/.bashrc

# MPI 测试程序（编译并安装为公共软件）
COPY scripts/jobs/hello_mpi.c /usr/local/src/hello_mpi.c
RUN mkdir -p /usr/local/mpi-test/1.0/bin \
    && cd /usr/local/src \
    && . /usr/share/lmod/lmod/init/bash \
    && module load gcc/13.3.0 openmpi/4.1.6 \
    && mpicc -o hello_mpi hello_mpi.c \
    && cp hello_mpi /usr/local/mpi-test/1.0/bin/ \
    && rm -f hello_mpi hello_mpi.c

# SSH 配置（跨节点 MPI）
RUN ssh-keygen -A \
    && sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && mkdir -p /root/.ssh \
    && ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" \
    && cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys \
    && chmod 600 /root/.ssh/authorized_keys

# 启动脚本
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

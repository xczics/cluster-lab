FROM ubuntu:24.04

LABEL description="Cluster-Lab: Slurm HPC Node"
LABEL maintainer="agent-yuan / zircon"

# 环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV SLURM_VERSION=24.11.3
ENV TZ=Europe/Copenhagen

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
    # OpenMPI
    openmpi-bin \
    libopenmpi-dev \
    # slurmrestd 依赖
    libhttp-parser-dev \
    libjson-c-dev \
    && rm -rf /var/lib/apt/lists/*

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
    && useradd -r -g slurm -u 64030 -s /bin/false slurm

# 配置 Munge 密钥
RUN mkdir -p /etc/munge \
    && /usr/sbin/mungekey --force \
    && chown -R munge:munge /etc/munge \
    && chmod 0700 /etc/munge \
    && chmod 0400 /etc/munge/munge.key

# 配置文件
COPY config/slurm/slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN chmod 600 /etc/slurm/slurmdbd.conf

# 启动脚本
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

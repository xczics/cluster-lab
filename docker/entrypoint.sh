#!/bin/bash
# Cluster-Lab 容器入口脚本
# 根据 CLUSTER_ROLE 环境变量启动对应服务
set -e

# --- 通用初始化 ---

# 确保 Munge 运行
echo "[ENTRY] Starting Munge..."
mkdir -p /run/munge
chown munge:munge /run/munge
chmod 755 /run/munge
sudo -u munge /usr/sbin/munged || true
sleep 1

# 确保 Slurm 目录存在
mkdir -p /var/run/slurm /var/spool/slurm /var/spool/slurm/d /var/log/slurm
chown -R slurm:slurm /var/{run,spool,log}/slurm

# --- 按角色启动服务 ---

case "${CLUSTER_ROLE}" in
  controller)
    echo "[ENTRY] Role: CONTROLLER"

    # 初始化 MariaDB（首次启动时）
    if [ ! -d /var/lib/mysql/mysql ]; then
        echo "[ENTRY] Initializing MariaDB..."
        mysql_install_db --user=mysql --datadir=/var/lib/mysql
    fi

    # 启动 MariaDB
    echo "[ENTRY] Starting MariaDB..."
    mysqld_safe --skip-syslog &
    MYSQL_PID=$!
    sleep 3

    # 配置 Slurm 数据库
    echo "[ENTRY] Configuring SlurmDB..."
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS slurm_acct_db;"
    mysql -u root -e \
      "GRANT ALL ON slurm_acct_db.* TO 'slurm'@'localhost' IDENTIFIED BY 'slurm';"
    mysql -u root -e "FLUSH PRIVILEGES;"

    # 启动 slurmdbd
    echo "[ENTRY] Starting slurmdbd..."
    /usr/sbin/slurmdbd -D -v &
    sleep 2

    # 启动 slurmctld
    echo "[ENTRY] Starting slurmctld..."
    /usr/sbin/slurmctld -D -v &
    sleep 2

    # 启动 NFS 服务端
    echo "[ENTRY] Starting NFS server..."
    exportfs -ra
    rpcbind
    /usr/sbin/rpc.nfsd 8
    /usr/sbin/rpc.mountd -p 20048

    echo "[ENTRY] Controller ready."

    # Tail 日志保持容器运行
    exec tail -f /var/log/slurm/slurmctld.log /var/log/slurm/slurmdbd.log
    ;;

  worker)
    echo "[ENTRY] Role: WORKER"

    # 挂载 NFS
    echo "[ENTRY] Mounting NFS shares..."
    sleep 3
    mount -t nfs -o proto=tcp,port=2049 172.20.0.2:/home /home || echo "NFS /home mount failed (non-fatal)"
    mount -t nfs -o proto=tcp,port=2049 172.20.0.2:/scratch /scratch || echo "NFS /scratch mount failed (non-fatal)"

    # 启动 slurmd
    echo "[ENTRY] Starting slurmd..."
    /usr/sbin/slurmd -D -v &
    sleep 2

    echo "[ENTRY] Worker ready."

    # Tail 日志保持容器运行
    exec tail -f /var/log/slurm/slurmd.log
    ;;

  *)
    echo "[ENTRY] Unknown role: ${CLUSTER_ROLE}"
    echo "Usage: CLUSTER_ROLE=controller|worker"
    exec bash
    ;;
esac

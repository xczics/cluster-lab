#!/bin/bash
# Cluster-Lab 容器入口脚本
# 根据 CLUSTER_ROLE 环境变量启动对应服务
set -e

# --- 通用初始化 ---

# 启动 SSH（跨节点 MPI 通信）
echo "[ENTRY] Starting SSH..."
/usr/sbin/sshd -D &
sleep 1

# 确保 Munge 运行
echo "[ENTRY] Starting Munge..."
mkdir -p /run/munge
chown munge:munge /run/munge
chmod 755 /run/munge
sudo -u munge /usr/sbin/munged --num-threads=10 || true
sleep 1

# 确保 slurm 用户 home 目录存在
mkdir -p /home/slurm
chown slurm:slurm /home/slurm
chmod 755 /home/slurm

# 确保 Slurm 目录存在
mkdir -p /var/run/slurm /var/spool/slurmd /var/spool/slurm/d /var/log/slurm
chown -R slurm:slurm /var/{run,spool,log}/slurm

# 创建 GRES 模拟 GPU 设备（用于测试 GRES 作业调度）
echo "[ENTRY] Creating fake GPU devices for GRES..."
for i in 0 1 2 3; do
  if [ ! -e /dev/fake_gpu${i} ]; then
    mknod /dev/fake_gpu${i} c 10 2${i} 2>/dev/null || true
    chmod 666 /dev/fake_gpu${i} 2>/dev/null || true
  fi
done

# 加载 Lmod 模块系统
echo "[ENTRY] Loading Lmod..."
if [ -f /usr/share/lmod/lmod/init/bash ]; then
  source /usr/share/lmod/lmod/init/bash
  echo "[ENTRY] Lmod loaded — use: module load gcc/13.3.0 openmpi/4.1.6"
fi

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

    # 启动 Flask 计费面板
    echo "[ENTRY] Starting Flask billing dashboard..."
    cd /home/scripts/billing && nohup python3 app.py > /var/log/slurm/flask.log 2>&1 &
    sleep 1

    echo "[ENTRY] Controller ready."

    # Tail 日志保持容器运行
    exec tail -f /var/log/slurm/slurmctld.log /var/log/slurm/slurmdbd.log /var/log/slurm/flask.log
    ;;

  worker)
    echo "[ENTRY] Role: WORKER"

    # 挂载 NFS（soft 选项防止挂起）
    echo "[ENTRY] Mounting NFS shares..."
    sleep 3
    mount -t nfs -o proto=tcp,port=2049,nolock,soft,timeo=5,retrans=1 172.20.0.10:/home /home 2>/dev/null || echo "NFS /home mount failed (non-fatal)"
    mount -t nfs -o proto=tcp,port=2049,nolock,soft,timeo=5,retrans=1 172.20.0.10:/scratch /scratch 2>/dev/null || echo "NFS /scratch mount failed (non-fatal)"

    # 启动 slurmd
    echo "[ENTRY] Starting slurmd..."
    /usr/sbin/slurmd -D -v &
    sleep 2

    echo "[ENTRY] Worker ready."

    # Tail 日志保持容器运行
    exec tail -f /var/log/slurm/slurmd.log
    ;;

  login)
    echo "[ENTRY] Role: LOGIN NODE"

    # 挂载 NFS /home
    echo "[ENTRY] Mounting NFS /home..."
    sleep 3
    mount -t nfs -o proto=tcp,port=2049,nolock,soft,timeo=5,retrans=1 172.20.0.10:/home /home 2>/dev/null || echo "NFS /home mount failed (non-fatal)"

    # SSH 已经由公共 init 启动
    # Munge 已经由公共 init 启动
    # 不启动 slurmd / slurmctld — 仅作登录和提交作业

    echo "[ENTRY] Login node ready."
    echo "[ENTRY] Users can SSH in (user01/user02/user03) and run: sbatch, sinfo, squeue"

    # 保活：每 10 秒打印一次概要
    while true; do
      sleep 60
      echo "[LOGIN] $(date '+%Y-%m-%d %H:%M:%S') — sinfo: $(sinfo -o '%P %D %t' --noheader 2>/dev/null | tr '\n' ' ')"
    done
    ;;

  *)
    echo "[ENTRY] Unknown role: ${CLUSTER_ROLE}"
    echo "Usage: CLUSTER_ROLE=controller|worker|login"
    exec bash
    ;;
esac

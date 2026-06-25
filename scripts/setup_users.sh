#!/bin/bash
# Multi-user environment setup for Cluster-Lab
# Usage: docker exec slurmctl bash /home/scripts/setup_users.sh

set -e

echo "===== Setting up Multi-User Environment ====="

# Create system users
echo "Creating system users..."
for user_info in "alice:2001:high" "bob:2002:normal" "charlie:2003:low"; do
  IFS=':' read -r user uid qos <<< "$user_info"
  
  if id "$user" &>/dev/null; then
    echo "  ✅ User $user already exists"
  else
    useradd -m -u "$uid" -s /bin/bash "$user"
    echo "$user:changeme" | chpasswd
    echo "  ✅ Created user $user (uid=$uid)"
  fi
done

# Configure Slurm accounting
echo "Setting up Slurm accounts..."

# Ensure Slurm accounting is minimally available
if command -v sacctmgr &>/dev/null; then
  # Create parent account
  sacctmgr -i add account cluster-lab description="Cluster-Lab Project" organization="local" 2>/dev/null || \
    echo "  Account 'cluster-lab' may already exist"
  
  # Create associations for each user
  for user_info in "alice:2001:high" "bob:2002:normal" "charlie:2003:low"; do
    IFS=':' read -r user uid qos <<< "$user_info"
    
    sacctmgr -i add user "$user" account=cluster-lab adminlevel=none \
      partition=normal qos="$qos" 2>/dev/null || \
      echo "  User $user may already have an association"
  done
  
  echo "  ✅ Slurm accounts and associations configured"
else
  echo "  ⚠️ sacctmgr not available — skipping Slurm accounts"
fi

echo ""
echo "===== Users Created ====="
echo "  alice   (uid=2001) — QoS: high   — User for privileged tests"
echo "  bob     (uid=2002) — QoS: normal — Standard user"
echo "  charlie (uid=2003) — QoS: low    — Capped user for fairness testing"
echo ""
echo "All passwords set to: changeme"
echo ""
echo "Usage:"
echo "  docker exec -u alice slurmctl sbatch /home/scripts/jobs/hello_mpi.sbatch"
echo "  docker exec slurmctl sacctmgr show associations"

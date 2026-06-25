#!/bin/bash
# Slurm QoS setup for Cluster-Lab
# Usage: docker exec slurmctl bash /home/scripts/setup_qos.sh

set -e

echo "===== Setting up Slurm QoS ====="

# Step 1: Create QoS entries
echo "Creating QoS definitions..."
for qos_def in "high:1000:1-00:00:00:10" "normal:500:2-00:00:00:20" "low:100:7-00:00:00:50"; do
  IFS=':' read -r name priority max_wall max_jobs <<< "$qos_def"
  
  if sacctmgr list qos "$name" --noheader 2>/dev/null | grep -q "$name"; then
    echo "  ✅ QoS '$name' already exists"
  else
    sacctmgr -i add qos "$name" \
      priority="$priority" \
      maxwall="$max_wall" \
      maxjobs="$max_jobs" \
      flags="DenyOnLimit"
    echo "  ✅ Created QoS '$name' (priority=$priority)"
  fi
done

# Step 2: Assign QoS to current users
echo "Assigning QoS to users..."
for assignment in "root:high" "alice:high" "bob:normal" "charlie:low"; do
  IFS=':' read -r user qos <<< "$assignment"
  
  if id "$user" &>/dev/null 2>&1; then
    sacctmgr -i modify user "$user" set qos="$qos" 2>/dev/null || \
      echo "  ⚠️ Could not assign QoS '$qos' to user '$user'"
    echo "  ✅ User '$user' → QoS '$qos'"
  fi
done

echo ""
echo "===== QoS Summary ====="
sacctmgr show qos format=Name,Priority,MaxWall,MaxJobs,Flags 2>/dev/null || true

echo ""
echo "Usage:"
echo "  docker exec -u user slurmctl srun --qos=high hostname"
echo "  docker exec slurmctl sacctmgr show qos"

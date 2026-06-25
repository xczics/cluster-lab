#!/bin/bash
# Cluster-Lab one-click deployment script
# Run on the host (macOS) to build and start the entire virtual cluster
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo "=========================================="
echo "  Cluster-Lab — Local Virtual HPC Cluster"
echo "=========================================="
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "[ERROR] Docker is not installed. Please install Docker Desktop for Mac:"
    echo "  https://docs.docker.com/desktop/install/mac-install/"
    exit 1
fi

echo "[1/4] Building Docker image..."
docker compose -f "$PROJECT_ROOT/docker/docker-compose.yml" build

echo ""
echo "[2/4] Starting cluster containers..."
docker compose -f "$PROJECT_ROOT/docker/docker-compose.yml" up -d

echo ""
echo "[3/4] Waiting for cluster readiness..."
# Wait for slurmctld to start
for i in {1..30}; do
    if docker exec slurmctl sinfo &>/dev/null 2>&1; then
        echo "  ✅ slurmctld ready"
        break
    fi
    echo "  ⏳ Waiting for slurmctld... ($i/30)"
    sleep 2
done

# Wait for node registration
sleep 5
echo ""
echo "[4/4] Node status:"
docker exec slurmctl sinfo -N -o "%N %t %C %m"

echo ""
echo "=========================================="
echo "  ✅ Cluster deployed successfully!"
echo "=========================================="
echo ""
echo "Useful commands:"
echo "  docker exec slurmctl sinfo       # View node status"
echo "  docker exec slurmctl squeue      # View job queue"
echo "  docker exec slurmctl sacct       # View job history"
echo "  docker exec slurmctl scontrol show node   # Node details"
echo ""
echo "Submit test jobs:"
echo "  docker exec slurmctl srun -N 2 hostname"
echo "  docker exec slurmctl sbatch scripts/test-job.sh"
echo ""
echo "Enter containers:"
echo "  docker exec -it slurmctl bash"
echo "  docker exec -it node01 bash"
echo ""
echo "Stop the cluster:"
echo "  docker compose -f docker/docker-compose.yml stop"
echo "  docker compose -f docker/docker-compose.yml down"
echo ""

#!/usr/bin/env bash
set -euo pipefail

# Delegate host execution to the toolbox container.
if [[ "${KUBECONFIG:-}" != "/workspace/.kube/config" ]]; then
    echo "Starting assessment inside the toolbox container..."

    for attempt in $(seq 1 180); do
        if docker compose exec -T toolbox test -f /workspace/.kube/config \
            >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    docker compose exec -T toolbox bash /workspace/scripts/run-all.sh
    exit $?
fi

cd /workspace

echo "========================================"
echo " DevOps Take-Home: Full Assessment Run"
echo "========================================"

echo
echo "[1/4] Checking cluster..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes

echo
echo "[2/4] Running Kubernetes troubleshooting assessment..."
bash scripts/30-troubleshoot.sh

echo
echo "[3/4] Deploying Quote API through Argo CD..."
bash scripts/20-deploy.sh

echo
echo "[4/4] Running Quote API smoke tests..."
bash scripts/40-smoke-test.sh

echo
echo "========================================"
echo " ALL ASSESSMENT CHECKS COMPLETED"
echo "========================================"

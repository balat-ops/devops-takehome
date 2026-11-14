#!/usr/bin/env bash
set -euo pipefail

cd /workspace

echo "========================================"
echo " DevOps Take-Home: Full Assessment Run"
echo "========================================"

echo
echo "[1/4] Checking cluster..."
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

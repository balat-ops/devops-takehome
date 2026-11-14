#!/usr/bin/env bash
set -euo pipefail

echo "Applying corrected troubleshooting resources..."

kubectl apply -f /workspace/troubleshoot/fixed-app.yaml

echo
echo "Waiting for web Deployment..."
kubectl rollout status deployment/web \
    -n troubleshoot --timeout=120s

echo
echo "Waiting for AI inference Deployment..."
kubectl rollout status deployment/ai-inference \
    -n troubleshoot --timeout=120s

echo
echo "Running original assessment verification..."
cd /workspace/troubleshoot
sh ./verify.sh

echo
echo "Troubleshooting assessment completed successfully."

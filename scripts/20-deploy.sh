#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="v3.6.1"
ARGOCD_NAMESPACE="argocd"
APPLICATION="quote-api"

if kubectl get deployment argocd-server -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
    echo "Existing Argo CD installation detected. Skipping installation."
else
    echo "Creating Argo CD namespace..."
    kubectl create namespace "${ARGOCD_NAMESPACE}"

    echo "Installing Argo CD ${ARGOCD_VERSION}..."
    kubectl apply --server-side --force-conflicts \
        -n "${ARGOCD_NAMESPACE}" \
        -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
fi

echo "Waiting for Argo CD server..."
kubectl rollout status deployment/argocd-server \
    -n "${ARGOCD_NAMESPACE}" --timeout=300s

echo "Waiting for Argo CD repository server..."
kubectl rollout status deployment/argocd-repo-server \
    -n "${ARGOCD_NAMESPACE}" --timeout=300s

echo "Applying Quote API Argo CD Application..."
kubectl apply -f /workspace/argocd/application.yaml

echo "Waiting for Quote API application to become Synced and Healthy..."
TIMEOUT=600
ELAPSED=0

while [ "${ELAPSED}" -lt "${TIMEOUT}" ]; do
    SYNC_STATUS=$(kubectl get application "${APPLICATION}" \
        -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.status.sync.status}' 2>/dev/null || true)

    HEALTH_STATUS=$(kubectl get application "${APPLICATION}" \
        -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.status.health.status}' 2>/dev/null || true)

    echo "Sync: ${SYNC_STATUS:-Pending} | Health: ${HEALTH_STATUS:-Pending}"

    if [ "${SYNC_STATUS}" = "Synced" ] && [ "${HEALTH_STATUS}" = "Healthy" ]; then
        echo "Quote API deployment completed successfully."
        kubectl get pods -o wide
        exit 0
    fi

    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

echo "ERROR: Quote API did not become Synced and Healthy within ${TIMEOUT} seconds."
kubectl get application "${APPLICATION}" -n "${ARGOCD_NAMESPACE}" -o yaml
exit 1

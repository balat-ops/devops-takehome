#!/usr/bin/env bash
set -euo pipefail

echo "Checking Calico installation..."

if kubectl get installation.operator.tigera.io default >/dev/null 2>&1; then
    echo "Calico Installation already exists. Skipping installation."
    exit 0
fi

echo "Installing Calico CRDs..."
kubectl apply --server-side --force-conflicts -f /workspace/calico/v3_projectcalico_org-v1beta1.yaml

echo "Waiting for Calico CRDs..."
kubectl wait --for=condition=Established \
    --timeout=120s \
    crd/installations.operator.tigera.io

echo "Installing Tigera Operator..."
kubectl apply -f /workspace/calico/tigera-operator.yaml

echo "Waiting for Tigera Operator Deployment..."
for i in $(seq 1 60); do
    if kubectl get deployment tigera-operator -n tigera-operator >/dev/null 2>&1; then
        break
    fi
    sleep 3
done

kubectl rollout status deployment/tigera-operator \
    -n tigera-operator \
    --timeout=180s

echo "Applying Calico custom resources..."
kubectl apply -f /workspace/calico/custom-resources.yaml

echo "Waiting for Calico installation..."
kubectl wait --for=condition=Ready \
    installation.operator.tigera.io/default \
    --timeout=300s

echo "Calico installation completed."

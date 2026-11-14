#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="devops-assessment"

echo "Checking k3d cluster: ${CLUSTER_NAME}"

if ! k3d cluster list | awk 'NR > 1 {print $1}' | grep -Fxq "${CLUSTER_NAME}"; then
    echo "Creating Kubernetes cluster..."
    k3d cluster create --config /workspace/k3d-config.yaml --wait
else
    echo "Existing cluster detected. Reusing it."
fi

echo "Generating kubeconfig..."
k3d kubeconfig get "${CLUSTER_NAME}" > /tmp/kubeconfig

CLUSTER=$(kubectl config view \
    --kubeconfig=/tmp/kubeconfig \
    -o jsonpath='{.contexts[0].context.cluster}')

SERVER=$(kubectl config view \
    --kubeconfig=/tmp/kubeconfig \
    -o jsonpath='{.clusters[0].cluster.server}')

API_PORT="${SERVER##*:}"

echo "Configuring Kubernetes API endpoint..."
kubectl config set-cluster "${CLUSTER}" \
    --kubeconfig=/tmp/kubeconfig \
    --server="https://host.docker.internal:${API_PORT}" \
    --tls-server-name="k3d-${CLUSTER_NAME}-serverlb"

mkdir -p /workspace/.kube
cp /tmp/kubeconfig /workspace/.kube/config

export KUBECONFIG=/workspace/.kube/config

echo "Verifying Kubernetes connectivity..."
kubectl get nodes

echo "Installing or checking Calico..."
bash /workspace/scripts/05-install-calico.sh

echo "Waiting for Kubernetes nodes..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "Preparing assessment node labels and taints..."
bash /workspace/troubleshoot/prepare.sh

echo "Final node status..."
kubectl get nodes -o wide

echo "Bootstrap completed successfully."
echo "Toolbox is ready."

exec sleep infinity

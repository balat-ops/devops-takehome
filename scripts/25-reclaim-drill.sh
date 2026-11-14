#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="default"
DEPLOYMENT="quote-api"
PDB="quote-api"
SERVICE_URL="http://host.docker.internal:8080/healthz"
HOST_HEADER="quote.local"
REPLICAS=3
DRAIN_TIMEOUT="180s"
RECOVERY_TIMEOUT="240s"
CHECK_INTERVAL=2

DRAINED_NODE=""
MONITOR_PID=""
MONITOR_LOG="$(mktemp)"
FAILURES_FILE="$(mktemp)"

cleanup() {
    if [[ -n "${MONITOR_PID}" ]]; then
        kill "${MONITOR_PID}" 2>/dev/null || true
        wait "${MONITOR_PID}" 2>/dev/null || true
    fi

    if [[ -n "${DRAINED_NODE}" ]]; then
        echo
        echo "Uncordoning ${DRAINED_NODE}..."
        kubectl uncordon "${DRAINED_NODE}" || {
            echo "ERROR: Could not uncordon ${DRAINED_NODE}. Manual intervention required."
        }
    fi

    rm -f "${MONITOR_LOG}" "${FAILURES_FILE}"
}

trap cleanup EXIT

echo "========================================"
echo " Spot Node Reclaim Drill"
echo "========================================"

# Select a Ready spot node that currently hosts a Quote API pod.
SPOT_NODE=""

while read -r NODE; do
    [[ -z "${NODE}" ]] && continue

    if kubectl get pods -n "${NAMESPACE}" \
        -l app=quote-api \
        --field-selector "spec.nodeName=${NODE}" \
        --no-headers | grep -q .; then
        SPOT_NODE="${NODE}"
        break
    fi
done < <(
    kubectl get nodes -l acme.io/capacity=spot \
        --no-headers |
    awk '$2 == "Ready" {print $1}'
)

if [[ -z "${SPOT_NODE}" ]]; then
    echo "ERROR: No Ready spot node currently hosting a Quote API pod."
    exit 1
fi

echo "Selected spot node: ${SPOT_NODE}"

# Verify the application is healthy before starting.
READY_REPLICAS="$(
    kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}'
)"

if [[ "${READY_REPLICAS:-0}" -ne "${REPLICAS}" ]]; then
    echo "ERROR: Expected ${REPLICAS} Ready replicas; found ${READY_REPLICAS:-0}."
    exit 1
fi

# Ensure the PDB permits at least one voluntary disruption.
ALLOWED="$(
    kubectl get pdb "${PDB}" -n "${NAMESPACE}" \
        -o jsonpath='{.status.disruptionsAllowed}'
)"

if [[ "${ALLOWED:-0}" -lt 1 ]]; then
    echo "ERROR: PDB does not currently allow a disruption."
    exit 1
fi

echo "Deployment healthy: ${READY_REPLICAS}/${REPLICAS}"
echo "PDB allowed disruptions: ${ALLOWED}"

# Start continuous HTTP health checks during the drain.
(
    while true; do
        TIMESTAMP="$(date '+%H:%M:%S')"

        if curl -fsS --max-time 5 \
            -H "Host: ${HOST_HEADER}" \
            "${SERVICE_URL}" >/dev/null; then
            echo "${TIMESTAMP} HTTP 200" >> "${MONITOR_LOG}"
        else
            echo "${TIMESTAMP} HTTP FAILURE" >> "${MONITOR_LOG}"
            echo "failure" >> "${FAILURES_FILE}"
        fi

        sleep "${CHECK_INTERVAL}"
    done
) &
MONITOR_PID=$!

# Wait for the first health-check result before starting the drain.
for attempt in $(seq 1 10); do
    if [[ -s "${MONITOR_LOG}" ]]; then
        break
    fi
    sleep 1
done

if [[ ! -s "${MONITOR_LOG}" ]]; then
    echo "ERROR: Health monitor did not record an initial result."
    exit 1
fi

if [[ -s "${FAILURES_FILE}" ]]; then
    echo "ERROR: Initial HTTP health check failed. Aborting before drain."
    cat "${MONITOR_LOG}"
    exit 1
fi

echo
echo "Initial HTTP health check passed."
echo "Draining spot node: ${SPOT_NODE}"

# Set before drain so the exit trap attempts to uncordon after any failure.
DRAINED_NODE="${SPOT_NODE}"

kubectl drain "${SPOT_NODE}" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout="${DRAIN_TIMEOUT}"

echo
echo "Waiting for all Quote API replicas to recover..."

kubectl rollout status deployment/"${DEPLOYMENT}" \
    -n "${NAMESPACE}" \
    --timeout="${RECOVERY_TIMEOUT}"

kubectl wait pods \
    -n "${NAMESPACE}" \
    -l app=quote-api \
    --for=condition=Ready \
    --timeout="${RECOVERY_TIMEOUT}"

READY_REPLICAS="$(
    kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}'
)"

if [[ "${READY_REPLICAS:-0}" -ne "${REPLICAS}" ]]; then
    echo "ERROR: Application did not recover to ${REPLICAS} Ready replicas."
    exit 1
fi

echo
echo "Application recovered: ${READY_REPLICAS}/${REPLICAS}"
kubectl get pods -n "${NAMESPACE}" -o wide

# Stop monitoring and report the HTTP checks.
kill "${MONITOR_PID}" 2>/dev/null || true
wait "${MONITOR_PID}" 2>/dev/null || true
MONITOR_PID=""

echo
echo "HTTP health-check results:"
cat "${MONITOR_LOG}"

if [[ -s "${FAILURES_FILE}" ]]; then
    echo
    echo "ERROR: HTTP failures were observed during the reclaim drill."
    exit 1
fi

echo
echo "SUCCESS: No HTTP failures observed during the reclaim drill."
echo "The cleanup handler will uncordon ${SPOT_NODE}."

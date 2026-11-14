#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://host.docker.internal:8080"
HOST_HEADER="quote.local"

echo "Testing Quote API through k3d ingress..."

check_endpoint() {
    local path="$1"
    echo
    echo "Checking ${path}..."

    curl -fsS \
        -H "Host: ${HOST_HEADER}" \
        "${BASE_URL}${path}"
    echo
}

check_endpoint "/healthz"
check_endpoint "/readyz"
check_endpoint "/api/quote"

echo
echo "Checking Prometheus metrics..."
METRICS=$(curl -fsS \
    -H "Host: ${HOST_HEADER}" \
    "${BASE_URL}/metrics")

if ! grep -q "quote_api_requests_total" <<< "${METRICS}"; then
    echo "ERROR: Expected Prometheus counter was not found."
    exit 1
fi

echo "Prometheus counter verified."

echo
echo "All smoke tests passed."

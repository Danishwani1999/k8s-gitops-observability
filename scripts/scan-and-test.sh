#!/usr/bin/env bash
set -euo pipefail

# 1. Scan local Kubernetes policies for misconfigurations using Trivy
echo "=== Running Trivy security scan on policies ==="
trivy config ./policies/

# 2. Test that Kyverno blocks insecure pods running as root
echo -e "\n=== Testing root pod restriction (Expect block) ==="
set +e
kubectl apply -f tests/fail-root-pod.yaml 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "SUCCESS: Kyverno correctly blocked the root pod."
else
    echo "FAILURE: The insecure pod was allowed through!"
    exit 1
fi

# 3. Test that compliant non-root pods deploy successfully
echo -e "\n=== Testing secure pod deployment (Expect success) ==="
kubectl apply -f tests/pass-non-root-pod.yaml
kubectl delete pod secure-workload --ignore-not-found=true

echo -e "\nAll Trivy scans and policy checks passed!"

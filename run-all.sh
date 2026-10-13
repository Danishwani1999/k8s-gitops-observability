#!/usr/bin/env bash
set -euo pipefail

echo "=== Deploying Policy via kubectl ==="
kubectl apply -f policies/disallow-root-user.yaml

echo "=== Syncing Argo CD Application ==="
kubectl apply -f application.yaml -n argocd

echo "=== Testing Negative Case (Root Pod should be BLOCKED) ==="
SET_OUTPUT=$(kubectl apply -f tests/insecure-pod.yaml 2>&1 || true)

if echo "$SET_OUTPUT" | grep -q "Disallow Root User\|securityContext"; then
    echo "SUCCESS: Insecure pod was correctly blocked by Kyverno policy."
else
    echo "FAILURE: Insecure pod was NOT blocked as expected!"
    echo "Output: $SET_OUTPUT"
    exit 1
fi

echo "=== Testing Positive Case (Non-Root Pod should be ALLOWED) ==="
kubectl apply -f tests/secure-pod.yaml
kubectl wait --for=condition=Ready pod/secure-pod --timeout=60s
echo "SUCCESS: Secure pod passed policy and reached Ready state."

#!/usr/bin/env bsh
set -euo pipefail

echo "==> Running Kyverno CLI tests..."
kyverno test ./policies/

echo "==> Scanning Kubernetes manifests with Trivy..."
trivy config ./manifests/

echo "==> Applying test pods to cluster..."
kubectl apply -f ./tests/compliant-pod.yaml || true
kubectl apply -f ./tests/non-compliant-pod.yaml || true

echo "==> Verification complete!"

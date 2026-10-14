#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Preflight: cluster and policy must be ready ==="
kubectl cluster-info >/dev/null 2>&1 || { echo "FAIL: cluster not reachable"; exit 1; }
kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=120s
kubectl get clusterpolicy disallow-root-user >/dev/null 2>&1 \
  || { echo "FAIL: policy disallow-root-user is not installed (is Argo CD synced?)"; exit 1; }

echo "=== Trivy scan of the compliant test pod ==="
trivy config --severity HIGH,CRITICAL --exit-code 1 tests/pass-non-root-pod.yaml

echo "=== Negative test: root pod must be denied by Kyverno ==="
set +e
OUT=$(kubectl apply -f tests/fail-root-pod.yaml 2>&1)
RC=$?
set -e
echo "$OUT"
if [ "$RC" -ne 0 ] && grep -q "admission webhook" <<<"$OUT" && grep -q "disallow-root-user" <<<"$OUT"; then
  echo "PASS: Kyverno denied the root pod"
else
  echo "FAIL: root pod was not denied by disallow-root-user"
  kubectl delete -f tests/fail-root-pod.yaml --ignore-not-found
  exit 1
fi

echo "=== Positive test: hardened pod must be admitted ==="
kubectl apply -f tests/pass-non-root-pod.yaml
kubectl wait --for=condition=Ready pod/secure-workload --timeout=60s
kubectl delete -f tests/pass-non-root-pod.yaml --ignore-not-found

echo "All checks passed"

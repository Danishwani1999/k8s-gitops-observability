#!/usr/bin/env bash
# Live admission test: the root pod must be DENIED by Kyverno, the hardened pod must be ALLOWED.
set -uo pipefail
cd "$(dirname "$0")/.."

cleanup() {
  kubectl delete pod insecure-root-workload secure-workload --ignore-not-found --wait=false >/dev/null 2>&1
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "--- waiting for Kyverno admission controller"
kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=300s \
  || fail "admission controller not ready"
until [ -n "$(kubectl -n kyverno get endpoints kyverno-svc -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)" ]; do
  sleep 5
done
kubectl wait --for=condition=Ready clusterpolicy/disallow-root-user --timeout=120s \
  || fail "policy disallow-root-user is not Ready"

echo "--- expect DENY: tests/fail-root-pod.yaml"
denied=0
for i in 1 2 3 4 5; do
  out=$(kubectl apply -f tests/fail-root-pod.yaml 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && grep -q "disallow-root-user" <<<"$out"; then
    echo "$out"; denied=1; break
  fi
  echo "$out"
  grep -q "failed calling webhook" <<<"$out" || break
  echo "webhook unreachable, retry $i/5"; sleep 10
done
[ "$denied" -eq 1 ] || fail "root pod was not blocked by disallow-root-user"
echo "PASS: Kyverno blocked the root pod."

echo "--- expect ALLOW: tests/pass-non-root-pod.yaml"
ok=0
for i in 1 2 3 4 5; do
  if out=$(kubectl apply -f tests/pass-non-root-pod.yaml 2>&1); then echo "$out"; ok=1; break; fi
  echo "$out"
  grep -q "failed calling webhook" <<<"$out" || break
  echo "webhook unreachable, retry $i/5"; sleep 10
done
[ "$ok" -eq 1 ] || fail "hardened pod was not admitted"
kubectl wait --for=condition=Ready pod/secure-workload --timeout=120s \
  || fail "hardened pod did not become Ready"
echo "PASS: hardened pod admitted and running."

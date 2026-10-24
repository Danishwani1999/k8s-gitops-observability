set -uo pipefail
cd "$(dirname "$0")/.."

cleanup() {
  kubectl delete pod insecure-root-workload secure-workload --ignore-not-found --wait=false >/dev/null 2>&1
}
trap cleanup EXIT

echo "--- expect DENY: tests/fail-root-pod.yaml"
out=$(kubectl apply -f tests/fail-root-pod.yaml 2>&1); rc=$?
echo "$out"
if [ "$rc" -ne 0 ] && grep -q "disallow-root-user" <<<"$out"; then
  echo "PASS: Kyverno blocked the root pod."
else
  echo "FAIL: root pod was not blocked by disallow-root-user." >&2
  exit 1
fi

echo "--- expect ALLOW: tests/pass-non-root-pod.yaml"
kubectl apply -f tests/pass-non-root-pod.yaml
kubectl wait --for=condition=Ready pod/secure-workload --timeout=90s
echo "PASS: hardened pod admitted and running."

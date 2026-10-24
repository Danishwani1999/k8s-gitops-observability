#!/usr/bin/env bash
# Offline checks (no cluster) followed by the live admission tests.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== 1/3 Trivy: misconfiguration scan of ALL manifests (HIGH,CRITICAL fail the run) ==="
# tests/fail-root-pod.yaml is deliberately insecure, so it is the only file skipped.
trivy config --severity HIGH,CRITICAL --exit-code 1 \
  --skip-files tests/fail-root-pod.yaml .

echo "=== 2/3 Kyverno CLI: offline policy unit tests ==="
kyverno test tests/

echo "=== 3/3 Live admission tests against the cluster ==="
./scripts/live-test.sh

echo "All checks passed."

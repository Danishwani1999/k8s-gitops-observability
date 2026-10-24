# shows genuine metrics and sync status instead of hand-written samples.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=docs/evidence
mkdir -p "$OUT"

PROM_PROXY="/api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy"
enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
pretty() { python3 -m json.tool; }

echo "Generating traffic so the counters are non-zero ..."
./scripts/live-test.sh >/dev/null 2>&1 || true
sleep 45   # allow one scrape interval

echo "1/5 Argo CD applications"
kubectl -n argocd get applications.argoproj.io -o wide | tee "$OUT/argocd-applications.txt"

echo "2/5 Kyverno metric series (shows the real label names for your chart version)"
kubectl get --raw "${PROM_PROXY}/api/v1/series?match%5B%5D=$(enc 'kyverno_policy_results_total')" \
  | pretty > "$OUT/kyverno-policy-results-series.json"

echo "3/5 kyverno_policy_results_total by policy and result"
kubectl get --raw "${PROM_PROXY}/api/v1/query?query=$(enc 'sum by (policy_name, rule_result) (kyverno_policy_results_total)')" \
  | pretty > "$OUT/kyverno-policy-results.json"

echo "4/5 kyverno_admission_requests_total"
kubectl get --raw "${PROM_PROXY}/api/v1/query?query=$(enc 'sum by (resource_kind, resource_request_operation) (kyverno_admission_requests_total)')" \
  | pretty > "$OUT/kyverno-admission-requests.json"

echo "5/5 Dashboard ConfigMap and Prometheus targets"
kubectl -n monitoring get configmap -l grafana_dashboard=1 | tee "$OUT/grafana-dashboards.txt"
kubectl get --raw "${PROM_PROXY}/api/v1/targets?state=active" \
  | python3 -c 'import sys,json
d=json.load(sys.stdin)["data"]["activeTargets"]
for t in d:
    if "kyverno" in t["labels"].get("namespace","") or "kyverno" in t["scrapePool"]:
        print(t["scrapePool"], t["health"])' | tee "$OUT/kyverno-targets.txt"

echo
echo "Evidence written to $OUT/. Paste the relevant parts into the README and take a Grafana"
echo "screenshot (kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80) into docs/evidence/."

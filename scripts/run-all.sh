#!/usr/bin/env bash
# Bootstrap the whole lab: Minikube -> Argo CD (pinned) -> root app -> wait -> tests.
# Argo CD then installs monitoring, Kyverno, policies and dashboards from Git.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/versions.env
source scripts/versions.env

APPS=(monitoring kyverno policies dashboards)

wait_app() {
  local app=$1
  echo "   waiting for application/${app} ..."
  until kubectl -n argocd get "application/${app}" >/dev/null 2>&1; do sleep 5; done
  kubectl -n argocd wait "application/${app}" --for=jsonpath='{.status.sync.status}'=Synced --timeout=900s
  kubectl -n argocd wait "application/${app}" --for=jsonpath='{.status.health.status}'=Healthy --timeout=900s
}

echo "[1/5] Minikube"
minikube status >/dev/null 2>&1 || minikube start --driver=docker --cpus="${MINIKUBE_CPUS:-3}" --memory="${MINIKUBE_MEMORY:-3584}"

echo "[2/5] Argo CD ${ARGOCD_VERSION}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "[3/5] Root application (app-of-apps)"
kubectl apply -f argocd/root-app.yaml

echo "[4/5] Waiting for Argo CD to sync every application"
for a in "${APPS[@]}"; do wait_app "$a"; done

echo "[5/5] Offline checks + live admission tests"
./scripts/scan-and-test.sh

echo "Done. Collect proof with: ./scripts/collect-evidence.sh"


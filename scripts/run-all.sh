#!/usr/bin/env bash
set -e

echo "[1/6] Checking / starting Minikube..."
minikube status >/dev/null 2>&1 || minikube start --driver=docker --memory="${MINIKUBE_MEMORY:-6144}" --cpus="${MINIKUBE_CPUS:-4}"

echo "[2/6] Installing Argo CD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION:-v2.13.3}/manifests/install.yaml

if [ "${SKIP_MONITORING:-0}" = "1" ]; then
  echo "[3/6] Skipping Prometheus and Grafana (SKIP_MONITORING=1)"
else
  echo "[3/6] Installing Prometheus and Grafana..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update >/dev/null 2>&1
  helm repo update >/dev/null 2>&1
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    -f charts/monitoring-values.yaml
fi

echo "[4/6] Installing Kyverno..."
helm repo add kyverno https://kyverno.github.io/kyverno --force-update >/dev/null 2>&1
helm repo update >/dev/null 2>&1
helm upgrade --install kyverno kyverno/kyverno --version 3.9.1 \
  --namespace kyverno --create-namespace -f charts/kyverno-values.yaml

echo "Waiting for the Kyverno admission controller..."
kubectl rollout status deployment kyverno-admission-controller -n kyverno --timeout=180s

if [ "${SKIP_MONITORING:-0}" != "1" ]; then
  echo "Applying Kyverno ServiceMonitor and alert rules..."
  kubectl apply -f monitoring/
fi

echo "[5/6] Connecting Argo CD to this repository (syncs policies/)..."
kubectl apply -f argocd/application.yaml

echo "[6/6] Running Trivy scan and admission tests..."
./scripts/scan-and-test.sh

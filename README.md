
# Kubernetes GitOps & Policy Enforcement Lab

A local Kubernetes lab that combines **policy-as-code admission control (Kyverno)**, **manifest scanning (Trivy)**, **GitOps delivery (Argo CD)** and **metrics/dashboards (Prometheus + Grafana)**. Everything runs on a single Minikube cluster, and one script provisions and verifies it.

![CI](https://github.com/Danishwani1999/k8s-gitops-observability/actions/workflows/ci.yml/badge.svg)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Minikube-326CE5?logo=kubernetes&logoColor=white)
![Kyverno](https://img.shields.io/badge/Kyverno-Policy%20Engine-F5A623)
![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-EF7B4D?logo=argo&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-Scanning-1904DA)
![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?logo=grafana&logoColor=white)

> **Scope:** this is a learning and demonstration environment on Minikube, not a production reference architecture. See [Limitations](#limitations-and-roadmap).

---

## What this demonstrates

- **Shift-left security:** Trivy scans Kubernetes manifests before they reach the cluster.
- **Admission control:** a Kyverno `ClusterPolicy` rejects pods that run as root, and a test suite proves both the deny and allow paths.
- **GitOps:** an Argo CD `Application` tracks this repository and reports sync and health status.
- **Observability:** kube-prometheus-stack provides Prometheus and Grafana for cluster and policy metrics.
- **Repeatability:** one script builds the environment, applies policies and runs the tests.

## Screenshots

**Argo CD synced, policies loaded**

![Argo CD synced](docs/argocd-synced.png)

**Kyverno denies the root pod and admits the hardened pod**

![Policy deny](docs/policy-deny.png)

**GitHub Actions CI**

![CI green](docs/ci-green.png)

**Prometheus scraping Kyverno metrics**

![Prometheus targets](docs/prometheus-targets.png)

**Alert firing on policy violations**

![Prometheus alert](docs/prometheus-alert.png)

**Kyverno policy results in Grafana**

![Grafana Kyverno](docs/grafana-kyverno.png)

## Architecture

```mermaid
graph TD
    Dev[Developer] -->|git push| GH[GitHub repository]
    GH -->|sync| ARGO[Argo CD]
    ARGO -->|apply manifests| K8S[Minikube cluster]

    subgraph Security
        TRIVY[Trivy scan] -->|checks manifests| GH
        KYV[Kyverno admission webhook] -->|allow / deny| K8S
    end

    subgraph Observability
        K8S -->|metrics| PROM[Prometheus]
        PROM --> GRAF[Grafana]
    end
```

| Tool | Role |
|---|---|
| Kyverno | Admission controller enforcing security policies |
| Trivy | Static misconfiguration scanning |
| Argo CD | Declarative GitOps delivery and drift detection |
| Prometheus / Grafana | Metrics collection and dashboards (kube-prometheus-stack) |
| Helm | Installs Kyverno and the monitoring stack |
| Minikube | Local Kubernetes cluster (Docker driver) |

## Repository structure

```text
├── argocd/application.yaml     # Argo CD Application (syncs policies/)
├── charts/kyverno-values.yaml  # Low-resource Kyverno values
├── charts/monitoring-values.yaml # Low-resource Prometheus and Grafana values
├── policies/                   # Kyverno ClusterPolicies
├── monitoring/                 # Kyverno ServiceMonitor, alert and Grafana dashboard
├── docs/                       # Screenshots of the verified run
├── scripts/                    # run-all.sh, scan-and-test.sh
├── tests/                      # Test pods and Kyverno CLI tests
└── .github/workflows/ci.yml    # Kyverno tests, Trivy, kubeconform, Argo CD app check
```

## The policy

`disallow-root-user` (Enforce) requires `runAsNonRoot: true` on the pod or on every container, so pods
that set no user at all are rejected as well. The rule excludes system namespaces.
It uses `failurePolicy: Ignore`, so if the Kyverno
webhook is down, pods are admitted instead of blocked. That is a
deliberate low-resource tradeoff for Minikube and should be `Fail` in
production. The other three policies run in Audit mode and also use `failurePolicy: Ignore`, so a Kyverno outage never blocks workloads.

## Prerequisites

- Linux, macOS, or WSL2 (Ubuntu)
- Docker, Minikube, `kubectl`, Helm 3, Trivy
- About 4 CPUs and 8 GB RAM free for the cluster

## Quick start

```bash
git clone https://github.com/Danishwani1999/k8s-gitops-observability.git
cd k8s-gitops-observability
chmod +x scripts/*.sh
./scripts/run-all.sh
```

`run-all.sh` performs these steps:

1. Starts Minikube if it is not running.
2. Installs Argo CD into the `argocd` namespace.
3. Installs kube-prometheus-stack (Prometheus and Grafana) into `monitoring` with `charts/monitoring-values.yaml`.
4. Installs Kyverno with `charts/kyverno-values.yaml` and waits for the admission controller.
5. Applies the policies in `policies/`.
6. Runs `scripts/scan-and-test.sh`.

## Validation

`scripts/scan-and-test.sh` runs two phases:

1. **Static scan:** Trivy scans the repository manifests for misconfigurations.
2. **Admission test:** applies `fail-root-pod.yaml` and expects a rejection, then applies `pass-non-root-pod.yaml` and expects success.

The script exits non-zero if either expectation is not met, so it can be used as a CI gate.

### Example output (abridged)

```text
=== Running Trivy security scan ===
...
=== Testing root pod restriction (expect block) ===
SUCCESS: Kyverno correctly blocked the root pod.

=== Testing secure pod deployment (expect success) ===
pod/secure-workload created
All checks passed.
```

## GitOps with Argo CD

`argocd/application.yaml` registers this repository with Argo CD.

```bash
kubectl apply -f argocd/application.yaml
kubectl -n argocd get applications
kubectl -n argocd port-forward svc/argocd-server 8080:443
# Admin password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

The Argo CD `Application` syncs only `policies/` to the cluster, so `tests/` is never deployed.

## Observability

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Kyverno exposes policy metrics, and the `ServiceMonitor` in `monitoring/` makes Prometheus scrape them. Verified query (Kyverno v1.19.1):

````promql
sum by (policy_name, rule_result) (kyverno_policy_results_total)
````

The `KyvernoPolicyViolations` alert fires when any policy records a failed result in the last 10 minutes. A Grafana dashboard, "Kyverno policy results", is provisioned from `monitoring/kyverno-dashboard.yaml`. Get the Grafana admin password with:

````bash
kubectl -n monitoring get secret monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```


## Running on a small machine

Verified on WSL2 with 3 CPUs and about 5 GB of RAM. Argo CD, Kyverno and Prometheus together can overload a node that small: health probes time out and pods restart in a loop. What worked:

- Start Minikube with `MINIKUBE_CPUS=3 MINIKUBE_MEMORY=4096` and run `SKIP_MONITORING=1 ./scripts/run-all.sh` first.
- Scale down the Argo CD components this lab does not use: `kubectl -n argocd scale deploy argocd-dex-server argocd-notifications-controller argocd-applicationset-controller --replicas=0`.
- Install monitoring with `charts/monitoring-values.yaml` (no Alertmanager, no node-exporter, memory caps), and bring components up one at a time instead of all at once.
- Kyverno's probes are relaxed in `charts/kyverno-values.yaml`, and every policy fails open, so a Kyverno restart does not block workloads.

## Cleanup

```bash
minikube delete
```

## Limitations and roadmap

- Local Minikube only. Argo CD manages `policies/`, not an application.
- Kyverno and monitoring are installed by script, not by Argo CD.
- All four policies use `failurePolicy: Ignore` (fail-open), so Kyverno restarts on a small machine never block workloads. Use `Fail` in production.
- Verified on a 3-CPU, about 5 GB WSL2 machine, where Argo CD, Kyverno and Prometheus together overload the node. See Running on a small machine.
- Trivy scans the compliant test pod and the policy, Argo CD and monitoring manifests; container images are not scanned.

Next steps:

- [ ] Deploy a sample app through Argo CD
- [ ] Move Kyverno and monitoring into Argo CD Applications
- [x] Require `runAsNonRoot`
- [ ] Set `failurePolicy: Fail` in production
- [ ] Scan container images in CI

## Author

**Danish Ahmad Wani** · Fresher DevOps & Cloud Engineer
GitHub: [@Danishwani1999](https://github.com/Danishwani1999)

## License

MIT. See [LICENSE](LICENSE).

## Verified run

Minikube (3 CPU, 4 GB), Kyverno chart 3.9.1 (Kyverno v1.19.1), Argo CD v2.13.3, 2026-10-17

```text
NAME                       SYNC STATUS   HEALTH STATUS
k8s-gitops-observability   Synced        Healthy

NAME                             ADMISSION   BACKGROUND   READY   AGE     MESSAGE
disallow-latest-tag              true        true         True    2m56s   Ready
disallow-privileged-containers   true        true         True    2m56s   Ready
disallow-root-user               true        true         True    2m56s   Ready
require-resource-limits          true        true         True    2m56s   Ready
```

# Kubernetes DevSecOps Policy Engine 🛡️

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.35+-blue?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Kyverno](https://img.shields.io/badge/Kyverno-Admission%20Control-orange?logo=kyverno&logoColor=white)](https://kyverno.io/)
[![Trivy](https://img.shields.io/badge/Trivy-Config%20Scanning-brightgreen?logo=aquasecurity&logoColor=white)](https://aquasecurity.github.io/trivy/)
[![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-red?logo=argo&logoColor=white)](https://argoproj.github.io/argo-cd/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-grade **DevSecOps policy enforcement and validation pipeline** for Kubernetes. This project demonstrates automated security configuration scanning, admission control webhook policy enforcement via Kyverno, and GitOps-driven cluster management.

---

## 🏗️ Architecture & Toolchain

| Tool | Purpose |
| :--- | :--- |
| **Kyverno** | Kubernetes native admission control policy engine (enforces security baselines). |
| **Trivy** | Static code analysis and vulnerability scanner for Kubernetes manifests and policies. |
| **Argo CD** | Continuous delivery and GitOps tool for synchronizing cluster state from Git. |
| **Helm** | Package manager for deploying and managing chart dependencies (Kyverno). |
| **Minikube / Docker** | Local container orchestration environment running on Ubuntu WSL. |

---

## 📂 Repository Structure

```text
k8s-policy-engine/
├── argocd/                # Argo CD application manifests for GitOps sync
├── charts/                # Helm value overrides and custom chart configurations
├── policies/              # Kyverno ClusterPolicy definitions (e.g., root user restrictions)
├── scripts/               # Automation scripts (Trivy scan + admission testing)
├── tests/                 # Validation test workloads (pass/fail manifests)
└── README.md
```

---

## 🚀 Automated Validation & Testing

This project includes an end-to-end automation script (`./scripts/scan-and-test.sh`) that validates security posture in two phases:
1. **Static Analysis:** Runs **Trivy** against all local policy definitions to check for misconfigurations.
2. **Dynamic Admission Control:** Tests cluster webhook enforcement by attempting to deploy insecure workloads (`fail-root-pod.yaml`) and compliant workloads (`pass-non-root-pod.yaml`).

### Execution Output

Running the test script produces the following verified validation report:

```text
=== Running Trivy security scan on policies ===
2026-10-10T09:03:12Z    INFO    [misconfig] Misconfiguration scanning is enabled
2026-10-10T09:03:12Z    INFO    [checks-client] Using existing checks from cache        path="/home/danish/.cache/trivy/policy/content"
2026-10-10T09:03:20Z    INFO    Detected config files    num=1

Report Summary
┌─────────────────────────┬────────────┬───────────────────┐
│         Target          │    Type    │ Misconfigurations │
├─────────────────────────┼────────────┼───────────────────┤
│ disallow-root-user.yaml │ kubernetes │         0         │
└─────────────────────────┴────────────┴───────────────────┘

=== Testing root pod restriction (Expect block) ===
Error from server: error when creating "tests/fail-root-pod.yaml": admission webhook "validate.kyverno.svc-fail" denied the request:
  resource Pod/default/insecure-root-workload was blocked due to the following policies
  disallow-root-user:
    check-runAsNonRoot: 'validation error: Running as root is not allowed. Set securityContext.runAsNonRoot to true. rule check-runAsNonRoot failed at path /spec/securityContext/runAsNonRoot/'
SUCCESS: Kyverno correctly blocked the root pod.

=== Testing secure pod deployment (Expect success) ===
pod/secure-workload created
pod "secure-workload" deleted from default namespace

All Trivy scans and policy checks passed!
```

---

## 🛠️ Quick Start & Usage

### Prerequisites
* Minikube & Docker (running on Ubuntu WSL)
* `kubectl` and `helm` installed

### 1. Deploy Kyverno via Helm
```bash
helm repo add kyverno https://kyverno.github.io/kyverno
helm repo update
helm upgrade --install kyverno kyverno/kyverno   --namespace kyverno   --create-namespace   -f charts/kyverno-values.yaml
```

### 2. Apply Security Policies
```bash
kubectl apply -f policies/disallow-root-user.yaml
```

### 3. Run the Automated Scan & Test Script
```bash
./scripts/scan-and-test.sh
```

---

## 👤 Author
**Danish Wani**  
*Fresher DevOps & Cloud Engineer*  
[GitHub Profile](https://github.com/Danishwani1999)

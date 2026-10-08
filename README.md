# Kubernetes Policy Engine (`k8s-policy-engine`)

[![Kubernetes](https://img.shields.io/badge/kubernetes-v1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Kyverno](https://img.shields.io/badge/kyverno-v1.19.1-009688?logo=kyverno&logoColor=white)](https://kyverno.io/)
[![Helm](https://img.shields.io/badge/helm-v3-0F1689?logo=helm&logoColor=white)](https://helm.sh/)

A lightweight, production-grade policy enforcement engine on Kubernetes using **Kyverno** admission controls deployed via **Helm**. This project demonstrates dynamic policy-based security gating by intercepting API admission requests and blocking non-compliant container specs (such as privileged root executions) before they reach the cluster datastore.

---

## 📌 Executive Summary

Modern Kubernetes security requires shifting control plane policy enforcement left. Rather than reacting to runtime vulnerabilities, `k8s-policy-engine` enforces admission-time governance using fine-grained policy rules. 

### Key Outcomes
- **Zero-Trust Guardrails**: Enforced strict `runAsNonRoot` policies cluster-wide.
- **Resource-Optimized Control Plane**: Custom Helm configuration stripping unused controllers to fit edge/local development environments without sacrificing security capabilities.
- **Automated Rejection**: Blocked root workload attempts at the API level with actionable violation errors.

---

## 🏛️ Architecture & Control Flow

text
[ User / CI/CD Pipeline ]
|
kubectl apply / run
|
v
+-------------------------------+
|   Kubernetes API Server       |
+-------------------------------+
|
Mutating / Validating
Admission Webhook
|
v
+-------------------------------+
|   Kyverno Admission Engine    |
|  (kyverno-admission-ctrl)     |
+-------------------------------+
|
+-------------------+-------------------+
|                                       |
[ Policy Rule Matched ]                 [ Policy Rule Violation ]
spec.securityContext.runAsNonRoot           spec.securityContext.runAsNonRoot
== true                                     != true
|                                       |
v                                       v
+-----------------+                     +-----------------+
|  200 OK Allowed |                     |  403 Forbidden  |
| (Persisted etcd)|                     | (Request Denied)|
+-----------------+                     +-----------------+
|                                       |
v                                       v
Pod Scheduled                           Deployment Blocked


---

## ⚙️ Implementation & Deployment Steps

### 1. Minimal-Footprint Helm Deployment

bash

Add official Kyverno Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

Install admission controller with lightweight values
helm install kyverno kyverno/kyverno -n kyverno --create-namespace 

--set global.backgroundController.enabled=false 

--set global.cleanupController.enabled=false 

--set global.reportsController.enabled=false


### 2. Root Restriction Policy (`policies/disallow-root-user.yaml`)

yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
name: disallow-root-user
annotations:
policies.kyverno.io/title: Disallow Root User
policies.kyverno.io/severity: high
spec:
validationFailureAction: Enforce
background: false
rules:
- name: check-runAsNonRoot
match:
any:
- resources:
kinds:
- Pod
validate:
message: "Running as root is not allowed. Set securityContext.runAsNonRoot to true."
pattern:
spec:
securityContext:
runAsNonRoot: true


Apply the policy:

bash
kubectl apply -f policies/disallow-root-user.yaml


---

## 🧪 Verification & Proof of Enforcement

### Test 1: Non-Compliant Root Pod Attempt (**EXPECTED: BLOCKED**)

bash
kubectl run test-root --image=nginx


**Actual Terminal Output**:
text
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:

resource Pod/default/test-root was blocked due to the following policies

disallow-root-user:
check-runAsNonRoot: 'validation error: Running as root is not allowed. Set securityContext.runAsNonRoot to true. rule check-runAsNonRoot failed at path /spec/securityContext/runAsNonRoot/'


---

### Test 2: Compliant Non-Root Pod Attempt (**EXPECTED: ALLOWED**)

bash
kubectl run test-nonroot --image=nginx --overrides='{
"spec": {
"securityContext": {
"runAsNonRoot": true,
"runAsUser": 10001
}
}
}'


**Actual Terminal Output**:
text
pod/test-nonroot created


---

## 📁 Repository Structure

text
k8s-policy-engine/
├── README.md
├── charts/
│   └── kyverno-values.yaml      # Exported Helm deployment values
└── policies/
└── disallow-root-user.yaml  # Kyverno ClusterPolicy enforcement manifest


---

## 🧹 Cleanup

bash
kubectl delete pod test-nonroot --ignore-not-found
kubectl delete -f policies/disallow-root-user.yaml
helm uninstall kyverno -n kyverno


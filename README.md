# 🛡️ GitOps + DevSecOps Pipeline with Policy Gates

[![CI/CD Pipeline](https://github.com/Swayam933/gitops-devsecops-pipeline/actions/workflows/ci-cd.yml/badge.svg?branch=main)](https://github.com/Swayam933/gitops-devsecops-pipeline/actions/workflows/ci-cd.yml)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Policy Engine](https://img.shields.io/badge/Policy-Kyverno-00979D?logo=kyverno&logoColor=white)](https://kyverno.io/)
[![Security Scanner](https://img.shields.io/badge/Security-Trivy-00A98F?logo=aquasec&logoColor=white)](https://aquasec.github.io/trivy/)
[![Secret Scanner](https://img.shields.io/badge/Secrets-Gitleaks-orange)](https://github.com/gitleaks/gitleaks)
[![GitOps Engine](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)](https://argoproj.github.io/cd/)

A production-grade CI/CD pipeline and cluster admission setup that **cannot ship or run an insecure container on Kubernetes**. Security checks are **hard, automated gates** at two distinct defense layers.

---

## 📑 Table of Contents

- [The Real-World Problem This Solves](#the-real-world-problem-this-solves)
- [End-to-End Architecture & Workflow](#end-to-end-architecture--workflow)
- [Repository Structure](#repository-structure)
- [System Prerequisites & Tool Installation](#system-prerequisites--tool-installation)
- [Quickstart: Run Everything Locally (5 Steps)](#quickstart-run-everything-locally-5-steps)
  - [Step 1: Run Local Pre-Commit Gates](#step-1-run-local-pre-commit-gates)
  - [Step 2: Create a Local Kubernetes Cluster (`kind`)](#step-2-create-a-local-kubernetes-cluster-kind)
  - [Step 3: Deploy Kyverno & Security Policies](#step-3-deploy-kyverno--security-policies)
  - [Step 4: Prove Policy Enforcement (Catch Insecure Pods)](#step-4-prove-policy-enforcement-catch-insecure-pods)
  - [Step 5: Deploy Hardened Workload & Verify Live Service](#step-5-deploy-hardened-workload--verify-live-service)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [Full GitHub Actions CI/CD Setup](#full-github-actions-cicd-setup)
- [Security Hardening Implementation](#security-hardening-implementation)
- [Troubleshooting & Common Questions](#troubleshooting--common-questions)
- [Measurable Metrics for Resumes / Portfolios](#measurable-metrics-for-resumes--portfolios)

---

## The Real-World Problem This Solves

In most DevOps pipelines, security tooling produces **advisory reports that are ignored under deadline pressure**:
1. **Ignored CI Scanners:** Vulnerability scanners (Trivy/Snyk) output long reports or PR annotations, but the image is built and pushed anyway.
2. **Missing Kubernetes Admission Enforcement:** By default, Kubernetes will happily schedule containers running as `root`, using floating `:latest` tags, with no CPU/memory limits, and with writable root filesystems.
3. **Overprivileged CI Runners:** Pipelines often run `kubectl apply` directly with broad cluster credentials stored in CI runner secrets. If the CI runner is compromised, the entire cluster is exposed.

### How This Project Closes Those Gaps:
* **CI Layer (Pre-Publish Gate):** The pipeline aborts with exit code `1` if Trivy finds Critical/High CVEs with available fixes, or if Gitleaks detects committed credentials.
* **Admission Layer (Pre-Scheduling Gate):** Kyverno `ClusterPolicy` resources reject non-compliant manifests at admission time, preventing misconfigurations even if someone attempts `kubectl apply` directly.
* **Strict GitOps Boundary:** CI only writes manifest changes (image tag bumps) to Git via Kustomize. **ArgoCD** is the only component with cluster credentials, reconciling state declaratively.

---

## End-to-End Architecture & Workflow

```mermaid
flowchart TD
    subgraph Developer [Developer Workspace]
        Code[Code Changes] --> LocalTest["./scripts/local-test.sh\n(Build + Trivy + Kyverno CLI + Kustomize)"]
        LocalTest --> Push[Git Push to GitHub]
    end

    subgraph CI [GitHub Actions Pipeline]
        Push --> Lint[1. Lint Dockerfile & Run Unit Tests]
        Lint --> Build[2. Build Unpushed Container Artifact]
        Build --> Gates{"3. HARD SECURITY GATES\n- Trivy (High/Crit CVEs fail job)\n- Gitleaks (Committed Secret Scan)"}
        Gates -- Vulnerabilities Found --> Fail["❌ Pipeline Blocked\nImage Never Pushed"]
        Gates -- Clean / Passed --> PushImg["4. Publish Exact Scanned Image to GHCR"]
        PushImg --> GitOpsUpdate["5. GitOps Step:\nUpdate Image Tag via Kustomize in Manifests Repo"]
    end

    subgraph GitOps [GitOps Controller: ArgoCD]
        GitOpsUpdate --> ArgoDev["ArgoCD Dev Application\n(Auto-Sync + Self-Heal)"]
        GitOpsUpdate --> ArgoProd["ArgoCD Prod Application\n(Manual Approval Gate)"]
    end

    subgraph K8sCluster [Kubernetes Admission Control & Runtime]
        ArgoDev --> Admission{"Kyverno Admission Webhook\n- disallow-latest-tag\n- require-non-root & drop caps\n- require-resource-limits"}
        ArgoProd --> Admission
        Admission -- Insecure Manifest --> Reject["🚫 Rejected at Admission\nPod Never Scheduled"]
        Admission -- Hardened Manifest --> Admitted["✅ Admitted & Scheduled"]
        Admitted --> DevPods["Dev Pods (1 Replica, Non-root, Read-only Root FS)"]
        Admitted --> ProdPods["Prod Pods (3 Replicas, High Resource Limits)"]
    end

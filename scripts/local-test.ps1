# Run the same checks locally that CI enforces, before you push.
# Requires: docker, trivy, kyverno CLI, and kustomize / kubectl
$ErrorActionPreference = "Stop"

$IMAGE_NAME = "devsecops-demo:local"

Write-Host "== 1. Building image ==" -ForegroundColor Cyan
docker build -t $IMAGE_NAME .

Write-Host "== 2. Trivy scan (fails on CRITICAL/HIGH with a fix available) ==" -ForegroundColor Cyan
trivy image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 $IMAGE_NAME

Write-Host "== 3. Validating K8s manifests against Kyverno policies ==" -ForegroundColor Cyan
kyverno apply policies/ --resource k8s/base/deployment.yaml

Write-Host "== 4. Rendering the dev overlay (sanity check) ==" -ForegroundColor Cyan
if (Get-Command kustomize -ErrorAction SilentlyContinue) {
    kustomize build k8s/overlays/dev
} elseif (Get-Command kubectl -ErrorAction SilentlyContinue) {
    kubectl kustomize k8s/overlays/dev
} else {
    Write-Warning "Neither kustomize nor kubectl found in PATH to render overlay."
}

Write-Host "All local checks passed." -ForegroundColor Green


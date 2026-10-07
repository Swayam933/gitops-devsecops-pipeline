#!/usr/bin/env bash
# Run the same checks locally that CI enforces, before you push.
# Requires: docker, trivy, kyverno CLI (https://kyverno.io/docs/kyverno-cli/)
set -euo pipefail

IMAGE_NAME="devsecops-demo:local"

echo "== 1. Building image =="
docker build -t "$IMAGE_NAME" .

echo "== 2. Trivy scan (fails on CRITICAL/HIGH with a fix available) =="
trivy image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 "$IMAGE_NAME"

echo "== 3. Validating K8s manifests against Kyverno policies =="
kyverno apply policies/ --resource k8s/base/deployment.yaml

echo "== 4. Rendering the dev overlay (sanity check) =="
command -v kustomize >/dev/null && kustomize build k8s/overlays/dev || \
  kubectl kustomize k8s/overlays/dev

echo "All local checks passed."

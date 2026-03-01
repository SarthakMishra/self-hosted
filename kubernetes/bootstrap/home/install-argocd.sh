#!/usr/bin/env bash
# =============================================================================
# Argo CD Bootstrap Script — Home Server
# =============================================================================
# One-time Helm install of Argo CD. After this, Argo CD manages itself
# and all other components from Git (app-of-apps pattern).
#
# Usage:
#   ./install-argocd.sh
#
# After install:
#   1. Get the initial admin password:
#      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
#   2. Access the UI via port-forward:
#      kubectl -n argocd port-forward svc/argocd-server 8080:80
#   3. Or via the HTTPRoute at argocd.k8s.home.example.com
# =============================================================================

set -euo pipefail

echo "=============================================="
echo "Installing Argo CD — Home Server"
echo "=============================================="
echo ""

# Add Argo Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Install Argo CD
helm install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f "${K8S_DIR}/infrastructure/base/argocd/helm-values.yaml" \
  -f "${K8S_DIR}/infrastructure/overlays/home/argocd/helm-values.yaml"

# Wait for Argo CD to be ready
echo "Waiting for Argo CD to be ready..."
kubectl -n argocd wait --for=condition=available deployment/argocd-server --timeout=300s

# Apply the HTTPRoute for UI access
kubectl apply -f "${K8S_DIR}/infrastructure/overlays/home/argocd/httproute.yaml"

echo ""
echo "=============================================="
echo "Argo CD installed successfully!"
echo "=============================================="
echo ""
echo "Get initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d && echo"
echo ""
echo "Access the UI:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:80"
echo "  Or: https://argocd.k8s.home.example.com"
echo ""
echo "Next steps:"
echo "  1. Login: argocd login localhost:8080 --username admin --password <password>"
echo "  2. Set up the app-of-apps pattern to manage all components from Git"

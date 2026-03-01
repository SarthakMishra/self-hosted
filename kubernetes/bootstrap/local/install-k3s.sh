#!/usr/bin/env bash
# =============================================================================
# k3s Installation Script — Local Development
# =============================================================================
# Installs k3s for local development and testing.
#
# Usage:
#   cp env.example .env   # Edit with your values
#   ./install-k3s.sh
#
# Uninstall:
#   /usr/local/bin/k3s-uninstall.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
else
  echo "ERROR: .env file not found. Copy env.example to .env and edit it."
  exit 1
fi

# Validate required variables
: "${K3S_SERVER_IP:?K3S_SERVER_IP must be set in .env}"

echo "=============================================="
echo "Installing k3s — Local Development"
echo "=============================================="
echo "Server IP:    ${K3S_SERVER_IP}"
echo "Data dir:     ${K3S_DATA_DIR:-/opt/k3s}"
echo ""

# Install k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --tls-san ${K3S_SERVER_IP} \
  --cluster-cidr 10.42.0.0/16 \
  --service-cidr 10.43.0.0/16 \
  --data-dir ${K3S_DATA_DIR:-/opt/k3s}" sh -

echo ""
echo "=============================================="
echo "k3s installed successfully!"
echo "=============================================="
echo ""
echo "Verify:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""
echo "Next steps:"
echo "  1. Install Traefik (see infrastructure/overlays/local/)"
echo "  2. Deploy test app: kubectl apply -k apps/overlays/local/whoami/"

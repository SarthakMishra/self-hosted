#!/usr/bin/env bash
# =============================================================================
# k3d Cluster Setup — Local Development
# =============================================================================
# Creates a k3d cluster (k3s-in-Docker) for local development and testing.
# This avoids WSL2 compatibility issues with bare-metal k3s (cgroup parsing,
# Docker Desktop 9p mounts with unescaped spaces in /proc/mounts).
#
# Prerequisites:
#   - Docker (Docker Desktop or Docker Engine)
#   - k3d (https://k3d.io)
#
# Usage:
#   cp env.example .env   # Edit with your values
#   ./install-k3s.sh
#
# Destroy:
#   k3d cluster delete <cluster-name>
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

# Defaults
K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-local}"
K3D_HTTP_PORT="${K3D_HTTP_PORT:-80}"
K3D_SERVERS="${K3D_SERVERS:-1}"
K3D_AGENTS="${K3D_AGENTS:-0}"
K3S_IMAGE="${K3S_IMAGE:-}"

# -------------------------------------------------------
# Preflight checks
# -------------------------------------------------------

check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' is not installed."
    echo ""
    case "$1" in
      docker)
        echo "Install Docker Desktop: https://docs.docker.com/desktop/"
        echo "  or Docker Engine:     https://docs.docker.com/engine/install/"
        ;;
      k3d)
        echo "Install k3d:"
        echo "  brew install k3d"
        echo "  or: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
        ;;
    esac
    exit 1
  fi
}

check_command docker
check_command k3d

# Verify Docker daemon is running
if ! docker info &>/dev/null; then
  echo "ERROR: Docker daemon is not running. Start Docker Desktop or the Docker service."
  exit 1
fi

# Check if cluster already exists
if k3d cluster list -o json 2>/dev/null | grep -q "\"name\":\"${K3D_CLUSTER_NAME}\""; then
  echo "ERROR: k3d cluster '${K3D_CLUSTER_NAME}' already exists."
  echo ""
  echo "To delete and recreate:"
  echo "  k3d cluster delete ${K3D_CLUSTER_NAME}"
  echo "  ./install-k3s.sh"
  echo ""
  echo "To just update kubeconfig:"
  echo "  k3d kubeconfig merge ${K3D_CLUSTER_NAME} --kubeconfig-switch-context"
  exit 1
fi

echo "=============================================="
echo "Creating k3d cluster — Local Development"
echo "=============================================="
echo "Cluster name: ${K3D_CLUSTER_NAME}"
echo "Servers:      ${K3D_SERVERS}"
echo "Agents:       ${K3D_AGENTS}"
echo "HTTP port:    localhost:${K3D_HTTP_PORT} -> :30080"
echo "k3s image:    ${K3S_IMAGE:-k3d default}"
echo ""

# -------------------------------------------------------
# Build k3d create command
# -------------------------------------------------------

K3D_CMD=(
  k3d cluster create "${K3D_CLUSTER_NAME}"
  --servers "${K3D_SERVERS}"
  --agents "${K3D_AGENTS}"

  # Map host port to Traefik's NodePort (30080) on the server node
  --port "${K3D_HTTP_PORT}:30080@server:0"

  # Disable k3s's built-in Traefik and ServiceLB — we install our own
  --k3s-arg "--disable=traefik@server:*"
  --k3s-arg "--disable=servicelb@server:*"

  # Configure containerd to allow insecure (HTTP) pulls from Harbor.
  # The registries.yaml is a template — setup-cicd.sh updates the
  # endpoint with Harbor's actual ClusterIP after it's deployed.
  --registry-config "${SCRIPT_DIR}/registries.yaml"

  # Wait for the cluster to be ready
  --wait
  --timeout 120s
)

# Optional: pin the k3s image version
if [[ -n "${K3S_IMAGE}" ]]; then
  K3D_CMD+=(--image "${K3S_IMAGE}")
fi

# -------------------------------------------------------
# Create the cluster
# -------------------------------------------------------

echo "Running: ${K3D_CMD[*]}"
echo ""
"${K3D_CMD[@]}"

echo ""

# -------------------------------------------------------
# Kubeconfig setup
# -------------------------------------------------------

# k3d automatically merges kubeconfig into ~/.kube/config and switches context.
# Verify it works:
CURRENT_CTX=$(kubectl config current-context 2>/dev/null || true)
EXPECTED_CTX="k3d-${K3D_CLUSTER_NAME}"

if [[ "${CURRENT_CTX}" != "${EXPECTED_CTX}" ]]; then
  echo "Switching kubectl context to ${EXPECTED_CTX}..."
  kubectl config use-context "${EXPECTED_CTX}"
fi

# -------------------------------------------------------
# Wait for node(s) to be Ready
# -------------------------------------------------------

echo ""
echo "Waiting for node(s) to become Ready..."

TIMEOUT=90
INTERVAL=5
ELAPSED=0

while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
  READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
  EXPECTED_COUNT=$(( K3D_SERVERS + K3D_AGENTS ))

  if [[ "${READY_COUNT}" -ge "${EXPECTED_COUNT}" ]]; then
    break
  fi

  echo "  ${READY_COUNT}/${EXPECTED_COUNT} nodes ready (${ELAPSED}s/${TIMEOUT}s)"
  sleep "${INTERVAL}"
  ELAPSED=$(( ELAPSED + INTERVAL ))
done

echo ""
echo "=============================================="
echo "k3d cluster '${K3D_CLUSTER_NAME}' is ready!"
echo "=============================================="
echo ""
echo "Context:  ${EXPECTED_CTX}"
echo ""
kubectl get nodes -o wide
echo ""
kubectl get pods -A
echo ""
echo "Next steps:"
echo "  1. Install Gateway API CRDs:"
echo "     kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml"
echo ""
echo "  2. Install Traefik:"
echo "     helm repo add traefik https://traefik.github.io/charts"
echo "     helm install traefik traefik/traefik -n traefik --create-namespace \\"
echo "       -f infrastructure/base/traefik/helm-values.yaml \\"
echo "       -f infrastructure/overlays/local/traefik/helm-values.yaml"
echo ""
echo "  3. Deploy test app:"
echo "     kubectl apply -k apps/overlays/local/whoami/"
echo ""
echo "Destroy:"
echo "  k3d cluster delete ${K3D_CLUSTER_NAME}"

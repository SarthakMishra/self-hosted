#!/usr/bin/env bash
# =============================================================================
# CI/CD Pipeline Setup — Local Development
# =============================================================================
# Deploys the full Argo Events CI/CD pipeline to the local k3d cluster:
#   1. Creates Kubernetes secrets (webhook token, Harbor credentials, Git deploy key)
#   2. Creates BuildKit daemon configuration (insecure HTTP registry support)
#   3. Deploys the EventBus (NATS message transport)
#   4. Deploys RBAC for cross-namespace Workflow submission
#   5. Deploys the WorkflowTemplate (BuildKit build + manifest update pipeline)
#   6. Deploys the EventSource (GitHub webhook listener)
#   7. Deploys the Sensor (event-to-workflow trigger)
#   8. Configures k3d containerd to pull from Harbor over HTTP
#
# Prerequisites:
#   - k3d cluster running (./bootstrap/local/install-k3s.sh)
#   - Argo Events controller deployed (Helm)
#   - Argo Workflows controller deployed (Helm)
#   - Harbor deployed and accessible at harbor.k8s.local
#
# Usage:
#   cp env.example .env   # Edit with your values
#   ./setup-cicd.sh
#
# Teardown:
#   ./setup-cicd.sh --delete
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------------------------------
# Parse arguments
# -------------------------------------------------------

DELETE_MODE=false
if [[ "${1:-}" == "--delete" ]] || [[ "${1:-}" == "-d" ]]; then
  DELETE_MODE=true
fi

# -------------------------------------------------------
# Load environment variables
# -------------------------------------------------------

if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
else
  echo "ERROR: .env file not found."
  echo "  cp ${SCRIPT_DIR}/env.example ${SCRIPT_DIR}/.env"
  echo "  # Edit .env with your values, then re-run."
  exit 1
fi

# Defaults / validation
GITHUB_WEBHOOK_SECRET="${GITHUB_WEBHOOK_SECRET:-changeme}"
HARBOR_URL="${HARBOR_URL:-harbor.k8s.local}"
HARBOR_USERNAME="${HARBOR_USERNAME:-admin}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-changeme}"
GIT_DEPLOY_KEY_PATH="${GIT_DEPLOY_KEY_PATH:-~/.ssh/deploy_key}"

# Expand tilde in the deploy key path
GIT_DEPLOY_KEY_PATH="${GIT_DEPLOY_KEY_PATH/#\~/$HOME}"

# Validate deploy key exists
if [[ ! -f "${GIT_DEPLOY_KEY_PATH}" ]]; then
  echo "ERROR: Git deploy key not found at '${GIT_DEPLOY_KEY_PATH}'."
  echo ""
  echo "Generate one with:"
  echo "  ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N \"\""
  echo ""
  echo "Then add the public key (deploy_key.pub) as a Deploy Key"
  echo "with write access in your GitHub repo settings."
  echo ""
  echo "Set GIT_DEPLOY_KEY_PATH in .env to a custom path if needed."
  exit 1
fi

# -------------------------------------------------------
# Preflight checks
# -------------------------------------------------------

check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' is not installed."
    exit 1
  fi
}

check_command kubectl

# Verify cluster is reachable
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: Cannot connect to Kubernetes cluster."
  echo "  Make sure your k3d cluster is running and kubeconfig is set."
  exit 1
fi

# Verify required namespaces exist
for ns in argo-events argo-workflows; do
  if ! kubectl get namespace "${ns}" &>/dev/null; then
    echo "ERROR: Namespace '${ns}' does not exist."
    echo "  Deploy the infrastructure stack first (Argo Events + Argo Workflows)."
    exit 1
  fi
done

# -------------------------------------------------------
# Delete mode
# -------------------------------------------------------

if [[ "${DELETE_MODE}" == "true" ]]; then
  echo "=============================================="
  echo "Tearing down CI/CD pipeline..."
  echo "=============================================="
  echo ""

  echo "[1/8] Deleting Sensor..."
  kubectl delete -f "${SCRIPT_DIR}/sensor-build-on-push.yaml" --ignore-not-found 2>/dev/null || true

  echo "[2/8] Deleting EventSource..."
  kubectl delete -f "${SCRIPT_DIR}/eventsource-github.yaml" --ignore-not-found 2>/dev/null || true

  echo "[3/8] Deleting WorkflowTemplate..."
  kubectl delete -f "${SCRIPT_DIR}/workflow-build-and-push.yaml" --ignore-not-found 2>/dev/null || true

  echo "[4/8] Deleting Sensor RBAC..."
  kubectl delete -f "${SCRIPT_DIR}/sensor-rbac.yaml" --ignore-not-found 2>/dev/null || true

  echo "[5/8] Deleting EventBus..."
  kubectl delete -f "${SCRIPT_DIR}/eventbus.yaml" --ignore-not-found 2>/dev/null || true

  echo "[6/8] Deleting BuildKit config..."
  kubectl -n argo-workflows delete configmap buildkitd-config --ignore-not-found 2>/dev/null || true

  echo "[7/8] Deleting secrets..."
  kubectl -n argo-events delete secret github-webhook-secret --ignore-not-found 2>/dev/null || true
  kubectl -n argo-workflows delete secret harbor-registry-credentials --ignore-not-found 2>/dev/null || true
  kubectl -n argo-workflows delete secret git-deploy-key --ignore-not-found 2>/dev/null || true

  echo "[8/8] Removing k3d registry configuration..."
  K3D_NODE="k3d-${K3D_CLUSTER_NAME:-local}-server-0"
  if docker exec "${K3D_NODE}" test -f /etc/rancher/k3s/registries.yaml 2>/dev/null; then
    docker exec "${K3D_NODE}" rm -f /etc/rancher/k3s/registries.yaml
    echo "  ✓ registries.yaml removed — restart the k3d node to take effect:"
    echo "    docker restart ${K3D_NODE}"
  else
    echo "  registries.yaml not found — skipping."
  fi
  echo ""
  echo "CI/CD pipeline teardown complete."
  exit 0
fi

# -------------------------------------------------------
# Deploy
# -------------------------------------------------------

echo "=============================================="
echo "Deploying CI/CD pipeline — Local Development"
echo "=============================================="
echo ""
echo "  Harbor URL:       ${HARBOR_URL}"
echo "  Harbor username:  ${HARBOR_USERNAME}"
echo "  Webhook secret:   $(echo "${GITHUB_WEBHOOK_SECRET}" | head -c 4)****"
echo "  Deploy key:       ${GIT_DEPLOY_KEY_PATH}"
echo ""

# -------------------------------------------------------
# Step 1: Create secrets
# -------------------------------------------------------

echo "[1/8] Creating secrets..."

# GitHub webhook secret (used by EventSource to validate incoming webhooks)
if kubectl -n argo-events get secret github-webhook-secret &>/dev/null; then
  echo "  github-webhook-secret already exists — updating..."
  kubectl -n argo-events delete secret github-webhook-secret
fi
kubectl -n argo-events create secret generic github-webhook-secret \
  --from-literal=token="${GITHUB_WEBHOOK_SECRET}"
echo "  ✓ github-webhook-secret created in argo-events"

# Harbor registry credentials (used by BuildKit to push images)
if kubectl -n argo-workflows get secret harbor-registry-credentials &>/dev/null; then
  echo "  harbor-registry-credentials already exists — updating..."
  kubectl -n argo-workflows delete secret harbor-registry-credentials
fi
kubectl -n argo-workflows create secret docker-registry harbor-registry-credentials \
  --docker-server="${HARBOR_URL}" \
  --docker-username="${HARBOR_USERNAME}" \
  --docker-password="${HARBOR_PASSWORD}"
echo "  ✓ harbor-registry-credentials created in argo-workflows"

echo ""

# Git deploy key (used by update-manifests step to push image tag changes)
if kubectl -n argo-workflows get secret git-deploy-key &>/dev/null; then
  echo "  git-deploy-key already exists — updating..."
  kubectl -n argo-workflows delete secret git-deploy-key
fi
kubectl -n argo-workflows create secret generic git-deploy-key \
  --from-file=ssh-privatekey="${GIT_DEPLOY_KEY_PATH}"
echo "  ✓ git-deploy-key created in argo-workflows"

echo ""

# -------------------------------------------------------
# Step 2: Create BuildKit daemon configuration
# -------------------------------------------------------

echo "[2/8] Creating BuildKit daemon configuration..."

# BuildKit needs a buildkitd.toml to allow pushing to insecure (HTTP)
# registries. This is only needed for local development where Harbor
# runs without TLS. The ConfigMap is mounted into the BuildKit container
# at /home/user/.config/buildkit/buildkitd.toml (rootless config path).

if kubectl -n argo-workflows get configmap buildkitd-config &>/dev/null; then
  echo "  buildkitd-config already exists — updating..."
  kubectl -n argo-workflows delete configmap buildkitd-config
fi

kubectl -n argo-workflows create configmap buildkitd-config \
  --from-literal=buildkitd.toml="$(cat <<EOF
# BuildKit daemon configuration — Local Development
# Allows pushing to Harbor over HTTP (no TLS).

[registry."${HARBOR_URL}"]
  http = true
  insecure = true
EOF
)"

echo "  ✓ buildkitd-config created in argo-workflows"
echo "    Insecure registry: ${HARBOR_URL}"
echo ""

# -------------------------------------------------------
# Step 3: Deploy EventBus
# -------------------------------------------------------

echo "[3/8] Deploying EventBus (NATS)..."
kubectl apply -f "${SCRIPT_DIR}/eventbus.yaml"

# Wait for EventBus to be ready
echo "  Waiting for EventBus pods..."
TIMEOUT=90
INTERVAL=5
ELAPSED=0
while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
  READY=$(kubectl -n argo-events get pods -l eventbus-name=default --no-headers 2>/dev/null | grep -c "Running" || true)
  if [[ "${READY}" -ge 1 ]]; then
    echo "  ✓ EventBus is running"
    break
  fi
  echo "    waiting... (${ELAPSED}s/${TIMEOUT}s)"
  sleep "${INTERVAL}"
  ELAPSED=$(( ELAPSED + INTERVAL ))
done

if [[ ${ELAPSED} -ge ${TIMEOUT} ]]; then
  echo "  ⚠ EventBus not ready after ${TIMEOUT}s — continuing anyway."
  echo "    Check with: kubectl -n argo-events get pods -l eventbus-name=default"
fi

echo ""

# -------------------------------------------------------
# Step 4: Deploy Sensor RBAC
# -------------------------------------------------------

echo "[4/8] Deploying Sensor RBAC..."
kubectl apply -f "${SCRIPT_DIR}/sensor-rbac.yaml"
echo "  ✓ ServiceAccount, Role, and RoleBinding created"
echo ""

# -------------------------------------------------------
# Step 5: Deploy WorkflowTemplate
# -------------------------------------------------------

echo "[5/8] Deploying WorkflowTemplate..."
kubectl apply -f "${SCRIPT_DIR}/workflow-build-and-push.yaml"
echo "  ✓ WorkflowTemplate 'build-and-push' deployed to argo-workflows"
echo ""

# -------------------------------------------------------
# Step 6: Deploy EventSource
# -------------------------------------------------------

echo "[6/8] Deploying EventSource..."
kubectl apply -f "${SCRIPT_DIR}/eventsource-github.yaml"

# Wait for the EventSource pod and service to come up
echo "  Waiting for EventSource pods..."
ELAPSED=0
while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
  READY=$(kubectl -n argo-events get pods -l eventsource-name=github --no-headers 2>/dev/null | grep -c "Running" || true)
  if [[ "${READY}" -ge 1 ]]; then
    echo "  ✓ EventSource is running"
    break
  fi
  echo "    waiting... (${ELAPSED}s/${TIMEOUT}s)"
  sleep "${INTERVAL}"
  ELAPSED=$(( ELAPSED + INTERVAL ))
done

if [[ ${ELAPSED} -ge ${TIMEOUT} ]]; then
  echo "  ⚠ EventSource not ready after ${TIMEOUT}s — continuing anyway."
  echo "    Check with: kubectl -n argo-events get pods -l eventsource-name=github"
fi

# Verify the auto-created Service exists
SVC_READY=false
for _ in 1 2 3 4 5; do
  if kubectl -n argo-events get svc github-eventsource-svc &>/dev/null; then
    SVC_READY=true
    echo "  ✓ Service 'github-eventsource-svc' created (HTTPRoute backend)"
    break
  fi
  sleep 3
done

if [[ "${SVC_READY}" != "true" ]]; then
  echo "  ⚠ Service 'github-eventsource-svc' not found yet."
  echo "    The EventSource controller may still be creating it."
fi

echo ""

# -------------------------------------------------------
# Step 7: Deploy Sensor
# -------------------------------------------------------

echo "[7/8] Deploying Sensor..."
kubectl apply -f "${SCRIPT_DIR}/sensor-build-on-push.yaml"

echo "  Waiting for Sensor pods..."
ELAPSED=0
while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
  READY=$(kubectl -n argo-events get pods -l sensor-name=build-on-push --no-headers 2>/dev/null | grep -c "Running" || true)
  if [[ "${READY}" -ge 1 ]]; then
    echo "  ✓ Sensor is running"
    break
  fi
  echo "    waiting... (${ELAPSED}s/${TIMEOUT}s)"
  sleep "${INTERVAL}"
  ELAPSED=$(( ELAPSED + INTERVAL ))
done

if [[ ${ELAPSED} -ge ${TIMEOUT} ]]; then
  echo "  ⚠ Sensor not ready after ${TIMEOUT}s."
  echo "    Check with: kubectl -n argo-events get pods -l sensor-name=build-on-push"
fi

echo ""

# -------------------------------------------------------
# Step 8: Configure k3d containerd for Harbor HTTP pulls
# -------------------------------------------------------

echo "[8/8] Configuring k3d containerd for Harbor..."

# Get Harbor's ClusterIP so containerd can reach it directly.
# Kubernetes Service DNS doesn't resolve at the node level (containerd
# uses Docker's DNS, not CoreDNS), so we inject the ClusterIP.
HARBOR_CLUSTER_IP=$(kubectl -n harbor get svc harbor -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
K3D_NODE="k3d-${K3D_CLUSTER_NAME:-local}-server-0"

if [[ -z "${HARBOR_CLUSTER_IP}" ]]; then
  echo "  ⚠ Harbor service not found — skipping registry configuration."
  echo "    Deploy Harbor first, then re-run this script."
elif ! docker info &>/dev/null; then
  echo "  ⚠ Docker not available — skipping registry configuration."
  echo "    Manually create /etc/rancher/k3s/registries.yaml on the k3d node."
else
  # Write registries.yaml with Harbor's ClusterIP as the mirror endpoint.
  # This tells containerd to use HTTP (not HTTPS) when pulling from
  # harbor.k8s.local, and routes traffic to the in-cluster service.
  REGISTRIES_YAML=$(cat <<REGEOF
# Generated by setup-cicd.sh — DO NOT EDIT
# Harbor ClusterIP: ${HARBOR_CLUSTER_IP}
mirrors:
  "harbor.k8s.local":
    endpoint:
      - "http://${HARBOR_CLUSTER_IP}"
REGEOF
)

  echo "${REGISTRIES_YAML}" | docker exec -i "${K3D_NODE}" tee /etc/rancher/k3s/registries.yaml >/dev/null

  echo "  ✓ registries.yaml injected into ${K3D_NODE}"
  echo "    Mirror: harbor.k8s.local → http://${HARBOR_CLUSTER_IP}"

  # Restart the k3d node so k3s/containerd picks up the new config.
  echo "  Restarting ${K3D_NODE} to apply registry config..."
  docker restart "${K3D_NODE}" >/dev/null 2>&1

  # Wait for the node to come back
  TIMEOUT=60
  INTERVAL=5
  ELAPSED=0
  while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    if kubectl get nodes "${K3D_NODE}" --no-headers 2>/dev/null | grep -q " Ready "; then
      echo "  ✓ Node is Ready"
      break
    fi
    echo "    waiting for node... (${ELAPSED}s/${TIMEOUT}s)"
    sleep "${INTERVAL}"
    ELAPSED=$(( ELAPSED + INTERVAL ))
  done

  if [[ ${ELAPSED} -ge ${TIMEOUT} ]]; then
    echo "  ⚠ Node not ready after ${TIMEOUT}s."
    echo "    Check with: kubectl get nodes"
  fi

  # Verify containerd picked up the config
  if docker exec "${K3D_NODE}" test -d "/var/lib/rancher/k3s/agent/etc/containerd/certs.d/harbor.k8s.local" 2>/dev/null; then
    echo "  ✓ containerd registry config verified"
  else
    echo "  ⚠ containerd registry config not found — the node may need more time."
  fi
fi

echo ""

# -------------------------------------------------------
# Summary
# -------------------------------------------------------

echo "=============================================="
echo "CI/CD pipeline deployed!"
echo "=============================================="
echo ""
echo "Resources:"
echo "  EventBus:         kubectl -n argo-events get eventbus"
echo "  EventSource:      kubectl -n argo-events get eventsources"
echo "  Sensor:           kubectl -n argo-events get sensors"
echo "  WorkflowTemplate: kubectl -n argo-workflows get workflowtemplates"
echo "  BuildKit Config:  kubectl -n argo-workflows get configmap buildkitd-config"
echo "  Deploy Key:       kubectl -n argo-workflows get secret git-deploy-key"
echo "  Registry Config:  docker exec k3d-${K3D_CLUSTER_NAME:-local}-server-0 cat /etc/rancher/k3s/registries.yaml"
echo ""
echo "Verify the full chain:"
echo "  kubectl -n argo-events get pods"
echo "  kubectl -n argo-events get svc github-eventsource-svc"
echo ""
echo "Test manually (submit a build workflow):"
echo ""
echo "  # Option 1: Submit directly via WorkflowTemplate"
echo "  argo submit -n argo-workflows --from workflowtemplate/build-and-push \\"
echo "    -p repo=https://github.com/traefik/whoami.git \\"
echo "    -p branch=master \\"
echo "    -p image=harbor.k8s.local/library/whoami \\"
echo "    -p tag=test"
echo ""
echo "  # Option 2: Simulate a GitHub push event via webhook"
echo "  PAYLOAD='{\"ref\":\"refs/heads/main\",\"after\":\"abc1234def5678\",\"repository\":{\"name\":\"whoami\",\"clone_url\":\"https://github.com/traefik/whoami.git\"}}'"
echo "  SIGNATURE=\$(echo -n \"\${PAYLOAD}\" | openssl dgst -sha256 -hmac '${GITHUB_WEBHOOK_SECRET}' | cut -d' ' -f2)"
echo "  curl -X POST http://webhooks.k8s.local/github \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -H 'X-GitHub-Event: push' \\"
echo "    -H \"X-Hub-Signature-256: sha256=\${SIGNATURE}\" \\"
echo "    -d \"\${PAYLOAD}\""
echo ""
echo "Monitor workflows:"
echo "  argo list -n argo-workflows"
echo "  argo logs -n argo-workflows @latest"
echo "  # Or open: http://workflows.k8s.local"
echo ""
echo "Teardown:"
echo "  ./setup-cicd.sh --delete"

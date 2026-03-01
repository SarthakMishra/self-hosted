# Kubernetes (k3s)

k3s clusters for home, remote (Hetzner), and local (k3d) environments. Uses the Kustomize **base + overlays** pattern so shared manifests live in `base/` and environment-specific config (IP ranges, domains, storage, TLS) lives in `overlays/{home,remote,local}/`.

## Directory Structure

```
kubernetes/
  bootstrap/                          # Per-environment cluster setup
    home/                             # TrueNAS homelab (k3s + Argo CD)
    remote/                           # Hetzner VPS
    local/                            # Local dev machine (k3d — k3s-in-Docker)
  infrastructure/                     # Core cluster components
    base/                             # Shared defaults
      metallb/                        # Bare-metal load balancer (home only)
      traefik/                        # Gateway API controller
      argocd/                         # GitOps controller
      argo-rollouts/                  # Progressive delivery (canary/blue-green)
      argo-workflows/                 # CI pipeline engine (home only)
      argo-events/                    # Webhook listener (home only)
      harbor/                         # Container registry (home only)
      rook-ceph/                      # Ceph operator (home only)
      rook-ceph-cluster/              # Ceph cluster + object store (home only)
    overlays/
      home/                           # Full stack: MetalLB + Traefik + Argo + Harbor + Rook-Ceph
      remote/                         # Traefik + Argo CD + Argo Rollouts
      local/                          # Traefik only
  apps/                               # Application workloads
    base/                             # Shared app definitions
      whoami/                         # Test app (Argo Rollout with canary)
    overlays/
      home/                           # Home HTTPRoutes (*.k8s.home.example.com)
      remote/                         # Remote HTTPRoutes (*.k8s.example.com)
      local/                          # Local HTTPRoutes (*.k8s.local)
  cicd/                               # CI/CD pipeline definitions
    workflow-templates/               # Argo WorkflowTemplates (build pipelines)
    event-sources/                    # Argo EventSources (webhook listeners)
    sensors/                          # Argo Sensors (event → workflow triggers)
```

## How the Base + Overlay Pattern Works

**Base** directories contain environment-agnostic resources: namespace definitions, deployments, services, default Helm values. They are never applied directly.

**Overlay** directories reference a base and add environment-specific resources or patches: MetalLB IP pools, HTTPRoute hostnames, Helm value overrides, storage classes.

```bash
# Deploy to home environment
kubectl apply -k infrastructure/overlays/home/
kubectl apply -k apps/overlays/home/whoami/

# Deploy to remote environment
kubectl apply -k infrastructure/overlays/remote/
kubectl apply -k apps/overlays/remote/whoami/
```

### What Differs Per Environment

| Concern | Home | Remote | Local (k3d) |
|---------|------|--------|-------------|
| Runtime | Bare-metal k3s | Bare-metal k3s | k3d (k3s-in-Docker) |
| MetalLB | Yes (bare-metal LB) | No (NodePort) | No (NodePort via k3d) |
| k3s node IP | Dedicated alias (avoids TrueNAS port conflict) | Primary server IP | Container network |
| IP pool | 192.168.x.200-210 | N/A | N/A |
| Traefik service | LoadBalancer | NodePort (30080/30443) | NodePort (30080, host:80 via k3d) |
| TLS | cert-manager + Cloudflare | cert-manager + Cloudflare | HTTP only |
| Storage | democratic-csi (TrueNAS NFS) | Hetzner CSI / local-path | local-path |
| HTTPRoute domain | `*.k8s.home.example.com` | `*.k8s.example.com` | `*.k8s.local` |
| Argo CD | Yes | Yes | Optional |
| Argo Rollouts | Yes | Yes | Optional |
| Harbor | Yes | No (pull from home) | No (pull from home) |
| Argo Workflows | Yes | No | No |
| Argo Events | Yes | No | No |
| Rook-Ceph | Yes | No | No |

### Adding a New App

1. Create the base in `apps/base/myapp/` (deployment, service, namespace, kustomization.yaml)
2. For each environment, create `apps/overlays/{env}/myapp/` with an `httproute.yaml` and kustomization.yaml that references the base
3. Add the app to `apps/overlays/{env}/kustomization.yaml`

## Getting Started (Home Server)

### Prerequisites: Dedicated IP Alias for k3s

TrueNAS uses ports 80 and 443 on its primary IP for the web UI. k3s (and Traefik/MetalLB) also need these ports, so you must assign a **separate IP alias** on the same interface for k3s to bind to.

**On TrueNAS SCALE:**
1. Go to **System Settings → Network → Interfaces**
2. Select your network interface → **Add Alias**
3. Add a static IP on the same subnet (e.g., if primary is `192.168.1.100`, add `192.168.1.101/24`)
4. Make sure this IP is outside your router's DHCP range

The install script uses `--node-ip` and `--node-external-ip` to bind k3s to this alias IP, keeping TrueNAS web UI accessible on the primary IP.

### 1. Install k3s

```bash
cd kubernetes/bootstrap/home
cp env.example .env
# Edit .env:
#   K3S_SERVER_IP  = Primary TrueNAS LAN IP (e.g., 192.168.1.100)
#   K3S_NODE_IP    = Dedicated alias IP for k3s (e.g., 192.168.1.101)
./install-k3s.sh
```

### 2. Verify the cluster

```bash
kubectl get nodes        # Should show STATUS: Ready
kubectl get pods -A      # Should show coredns, local-path-provisioner, metrics-server
```

### 3. Copy kubeconfig to your local machine

```bash
scp user@server-ip:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Edit server URL: change 127.0.0.1 to your k3s node IP alias
# (the K3S_NODE_IP from .env, NOT the primary TrueNAS IP)
```

### 4. Install MetalLB

```bash
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system --create-namespace

# Wait for pods to be ready
kubectl -n metallb-system wait --for=condition=ready pod \
  -l app.kubernetes.io/name=metallb --timeout=120s

# Edit the IP range in the overlay, then apply
kubectl apply -k infrastructure/overlays/home/metallb/
```

### 5. Install Argo CD

```bash
cd kubernetes/bootstrap/home
./install-argocd.sh
```

This installs Argo CD via Helm with values from both base and home overlay, waits for it to be ready, and applies the HTTPRoute for `argocd.k8s.home.example.com`.

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### 6. Install Traefik (with Gateway API)

Traefik is configured as a Gateway API controller (the modern successor to Ingress).
The Helm chart automatically creates the GatewayClass and Gateway resources.
App routing uses HTTPRoute instead of Ingress/IngressRoute.

```bash
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik -n traefik --create-namespace \
  -f infrastructure/base/traefik/helm-values.yaml \
  -f infrastructure/overlays/home/traefik/helm-values.yaml

# Verify Traefik got a MetalLB IP
kubectl -n traefik get svc traefik

# Verify Gateway API resources were created
kubectl get gatewayclass
kubectl get gateway -n traefik
```

### 7. Install the CI/CD Stack (Home Only)

Harbor, Argo Workflows, Argo Events, Argo Rollouts, and Rook-Ceph only run on the home cluster.

```bash
# Argo Rollouts
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo-rollouts argo/argo-rollouts -n argo-rollouts --create-namespace \
  -f infrastructure/base/argo-rollouts/helm-values.yaml \
  -f infrastructure/overlays/home/argo-rollouts/helm-values.yaml

# Rook-Ceph Operator (S3-compatible object storage via Ceph RGW — replaces MinIO)
helm repo add rook-release https://charts.rook.io/release
helm install rook-ceph rook-release/rook-ceph -n rook-ceph --create-namespace \
  -f infrastructure/base/rook-ceph/helm-values.yaml \
  -f infrastructure/overlays/home/rook-ceph/helm-values.yaml

# Wait for operator to be ready
kubectl -n rook-ceph wait --for=condition=ready pod \
  -l app=rook-ceph-operator --timeout=300s

# Rook-Ceph Cluster (CephCluster, CephObjectStore, StorageClasses)
helm install rook-ceph-cluster rook-release/rook-ceph-cluster \
  -n rook-ceph --set operatorNamespace=rook-ceph \
  -f infrastructure/base/rook-ceph-cluster/helm-values.yaml \
  -f infrastructure/overlays/home/rook-ceph-cluster/helm-values.yaml

# Wait for Ceph cluster to be healthy (takes several minutes on first deploy)
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

# Argo Workflows
helm install argo-workflows argo/argo-workflows -n argo-workflows --create-namespace \
  -f infrastructure/base/argo-workflows/helm-values.yaml \
  -f infrastructure/overlays/home/argo-workflows/helm-values.yaml

# Argo Events
helm install argo-events argo/argo-events -n argo-events --create-namespace \
  -f infrastructure/base/argo-events/helm-values.yaml \
  -f infrastructure/overlays/home/argo-events/helm-values.yaml

# Harbor
helm repo add harbor https://helm.goharbor.io
helm install harbor harbor/harbor -n harbor --create-namespace \
  -f infrastructure/base/harbor/helm-values.yaml \
  -f infrastructure/overlays/home/harbor/helm-values.yaml
```

Apply HTTPRoutes and CI/CD pipeline resources:

```bash
# HTTPRoutes for all services
kubectl apply -k infrastructure/overlays/home/

# CI/CD pipeline (WorkflowTemplates, EventSources, Sensors)
kubectl apply -f cicd/workflow-templates/
kubectl apply -f cicd/event-sources/
kubectl apply -f cicd/sensors/
```

### 8. Deploy the test app

```bash
kubectl apply -k apps/overlays/home/whoami/

# Test directly
kubectl -n whoami port-forward svc/whoami 8080:80
# Visit http://localhost:8080

# Test via Gateway API
curl -H "Host: whoami.k8s.home.example.com" http://METALLB_IP

# Verify the HTTPRoute is attached to the Gateway
kubectl -n whoami get httproute

# Check the Argo Rollout status
kubectl argo rollouts get rollout whoami -n whoami
```

## Getting Started (Local — k3d)

Local development uses [k3d](https://k3d.io) to run k3s inside Docker. This avoids
WSL2 compatibility issues (cgroup parsing, Docker Desktop 9p mounts) and gives you
a one-command cluster that matches the k3s distribution used in home/remote.

### Prerequisites

- Docker (Docker Desktop or Docker Engine)
- [k3d](https://k3d.io): `brew install k3d` or `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`
- kubectl
- Helm

### 1. Create the k3d cluster

```bash
cd kubernetes/bootstrap/local
cp env.example .env   # Edit if you want to change cluster name or port
./install-k3s.sh
```

The script creates a k3d cluster with Traefik and ServiceLB disabled, maps
host port 80 to NodePort 30080 on the k3s node, waits for the node to be
Ready, and merges the kubeconfig into `~/.kube/config`.

### 2. Install Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

### 3. Install Traefik

```bash
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik -n traefik --create-namespace \
  -f infrastructure/base/traefik/helm-values.yaml \
  -f infrastructure/overlays/local/traefik/helm-values.yaml

# Verify
kubectl -n traefik get pods           # Should be Running
kubectl -n traefik get svc traefik    # Should be NodePort 80:30080
kubectl get gatewayclass              # Should show "traefik" (Accepted: True)
kubectl get gateway -n traefik        # Should show traefik-gateway (Programmed: True)
```

### 4. Deploy the test app

```bash
kubectl apply -k apps/overlays/local/whoami/
```

### 5. Test access

```bash
# Add hostname to /etc/hosts (WSL2: use the Windows hosts file too)
echo "127.0.0.1 whoami.k8s.local" | sudo tee -a /etc/hosts

# Test via Gateway API
curl -H "Host: whoami.k8s.local" http://localhost

# Or test via port-forward
kubectl -n whoami port-forward svc/whoami 8080:80
curl http://localhost:8080
```

### Destroy

```bash
k3d cluster delete local
```

## Getting Started (Remote Server)

```bash
# Bootstrap
cd kubernetes/bootstrap/remote
cp env.example .env && vim .env
./install-k3s.sh

# Infrastructure (no MetalLB on cloud)
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik -n traefik --create-namespace \
  -f infrastructure/base/traefik/helm-values.yaml \
  -f infrastructure/overlays/remote/traefik/helm-values.yaml

# Apps
kubectl apply -k apps/overlays/remote/whoami/
```

## CI/CD Pipeline

End-to-end flow from code push to production deployment:

```
Git push → Argo Events (webhook) → Argo Workflows (clone + Kaniko build → push to Harbor)
  → Update manifests in Git → Argo CD (sync) → Argo Rollouts (canary deploy)
```

### Components

| Component | Purpose | Namespace |
|-----------|---------|-----------|
| **Argo Events** | Listens for GitHub/Gitea webhooks | `argo-events` |
| **Argo Workflows** | Runs CI pipelines (clone, build, push) | `argo-workflows` |
| **Harbor** | Stores container images with vulnerability scanning | `harbor` |
| **Rook-Ceph** | S3-compatible object storage via Ceph RGW | `rook-ceph` |
| **Argo CD** | GitOps: syncs manifests from Git to cluster | `argocd` |
| **Argo Rollouts** | Progressive delivery: canary/blue-green deploys | `argo-rollouts` |

### Pipeline Templates

Templates live in `cicd/` and are applied to the home cluster:

- **`workflow-templates/build-and-push.yaml`** — WorkflowTemplate that clones a repo, builds with Kaniko, and pushes to Harbor
- **`event-sources/github-webhook.yaml`** — EventSource listening for GitHub push events on port 12000
- **`sensors/build-on-push.yaml`** — Sensor that triggers the build workflow when a push event is received

### Triggering a Build Manually

```bash
argo submit --from workflowtemplate/build-and-push \
  -p repo=https://github.com/user/app \
  -p branch=main \
  -p image=harbor.k8s.home.example.com/library/app \
  -p tag=latest
```

### Argo Rollouts (Canary Deployments)

Apps use `kind: Rollout` instead of `kind: Deployment`. During updates, traffic shifts gradually using Gateway API HTTPRoute weights:

```
20% → pause 30s → 50% → pause 30s → 80% → pause 30s → 100%
```

```bash
# Watch a rollout in progress
kubectl argo rollouts get rollout whoami -n whoami --watch

# Manually promote a paused rollout
kubectl argo rollouts promote whoami -n whoami

# Abort a rollout (rollback)
kubectl argo rollouts abort whoami -n whoami
```

### Service URLs (Home)

| Service | URL |
|---------|-----|
| Argo CD | `argocd.k8s.home.example.com` |
| Argo Workflows | `workflows.k8s.home.example.com` |
| Harbor | `harbor.k8s.home.example.com` |
| Ceph Dashboard | `ceph.k8s.home.example.com` |
| Webhooks | `webhooks.k8s.home.example.com/github` |

## Useful kubectl Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl top nodes

# Workloads
kubectl get pods -A
kubectl describe pod POD_NAME
kubectl logs POD_NAME
kubectl exec -it POD_NAME -- sh

# Gateway API
kubectl get gatewayclass                   # Should show traefik
kubectl get gateway -n traefik             # The Traefik gateway
kubectl get httproute -A                   # All routes across namespaces

# Debugging
kubectl get events -A --sort-by='.lastTimestamp'
kubectl port-forward svc/NAME LOCAL:REMOTE

# Kustomize preview (renders without applying)
kubectl kustomize apps/overlays/home/whoami/

# Argo Rollouts
kubectl argo rollouts list rollouts -A
kubectl argo rollouts get rollout whoami -n whoami
kubectl argo rollouts dashboard                    # Opens rollouts dashboard

# Argo Workflows
argo list -n argo-workflows
argo get WORKFLOW_NAME -n argo-workflows
argo logs WORKFLOW_NAME -n argo-workflows

# Argo CD
argocd app list
argocd app sync APP_NAME
argocd app get APP_NAME
```

## Learning Roadmap

| Phase | Topic | What You'll Learn |
|-------|-------|-------------------|
| 1 | Cluster + Manual Deploys | Pods, Deployments, Services, Gateway API, Helm |
| 2 | GitOps with Argo CD | App-of-apps pattern, Kustomize, cert-manager |
| 3 | CI/CD Pipeline | Harbor, Argo Workflows, Argo Events, Kaniko builds |
| 4 | Progressive Delivery | Argo Rollouts, canary/blue-green, AnalysisTemplates |
| 5 | Storage + Monitoring | PVCs, democratic-csi, Prometheus, Grafana |
| 6 | Autoscaling | HPA, VPA, KEDA, resource management |
| 7 | Advanced | Cilium, Network Policies, Sealed Secrets, multi-node |

## Uninstall

```bash
/usr/local/bin/k3s-uninstall.sh
```

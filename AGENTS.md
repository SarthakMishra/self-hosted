# Agent Guidelines

## Repository Structure

```
home-server/       # Ansible playbook for home lab
remote-server/     # Ansible playbook for VPS/cloud
kubernetes/        # k3s cluster configuration (base + overlays)
  ├── bootstrap/   # Per-environment setup scripts ({home,remote,local}/)
  ├── infrastructure/ # Core cluster infra (Traefik, Argo stack, Harbor, Rook-Ceph)
  │   ├── base/    # Shared defaults
  │   └── overlays/ # Environment overrides ({home,remote,local}/)
  ├── apps/        # Application workloads
  │   ├── base/    # Shared app definitions (Rollouts, not Deployments)
  │   └── overlays/ # Environment overrides ({home,remote,local}/)
  └── cicd/        # CI/CD pipeline definitions
      ├── workflow-templates/  # Argo WorkflowTemplates
      ├── event-sources/       # Argo EventSources
      └── sensors/             # Argo Sensors
service-templates/ # Docker Compose templates
  ├── home/        # Home network services
  ├── remote/      # Production/cloud services
  └── local/       # Development services
scripts/           # Validation scripts
```

## Pre-commit Hooks

12 hooks run automatically on commit. Run manually with:
```bash
pre-commit run --all-files
```

### Handling Hook Failures

| Hook | Fix |
|------|-----|
| `gitleaks` | Remove secrets, use `changeme` placeholder |
| `yamllint` | Fix indentation (2 spaces), line length (<200) |
| `ansible-lint` | Fix task naming, use FQCNs, add `changed_when` |
| `docker-compose-check` | Validate compose syntax |
| `check-env-placeholders` | Use standardized placeholders (see below) |

## Creating Service Templates

1. Create directory: `service-templates/{home,remote,local}/service-name/`
2. Required files:
   - `docker-compose.yml` - Service definition
   - `env.example` - Environment template

### env.example Conventions

**Placeholders:**
- Secrets/passwords: `changeme`
- Domains: `service.example.com`
- Emails: `admin@example.com`
- IPs: `192.168.1.x`

**Comment style:**
```bash
# Service Name Configuration

# === SECTION ===
# Generate with: openssl rand -hex 32
SECRET_KEY=changeme

# === DATABASE ===
DB_PASSWORD=changeme
```

## Ansible Playbooks

- Use FQCN modules: `ansible.builtin.apt`, `ansible.posix.authorized_key`
- Handler names: Start with uppercase (`Restart Docker`)
- Shell commands: Add `changed_when: true` or `changed_when: false`
- Escape Docker Go templates: `{% raw %}{{.Names}}{% endraw %}`

### Required Collections

```yaml
# requirements.yml
collections:
  - ansible.posix
  - community.docker
  - community.general
```

## Keeping Documentation Updated

**Always update `README.md` when:**
- Creating/removing service templates
- Changing repository structure
- Adding new top-level directories

### Service Template Changes

When adding a new service to `service-templates/{home,remote,local}/`:
1. Add entry to the corresponding table in README.md under "Service Templates"
2. Format: `| [service-name](service-templates/{category}/service-name/) | Brief description |`
3. Keep services alphabetically sorted within each table

When removing a service:
1. Remove its entry from the README.md service table

### Structure Changes

If modifying top-level directories:
1. Update the "Repository Structure" tree in both README.md and AGENTS.md
2. Ensure both files stay in sync

## Kubernetes Manifests

Directory: `kubernetes/`

### Base + Overlay Pattern

Uses Kustomize base/overlay pattern for multi-environment support:

- **`base/`** - Environment-agnostic resources (never applied directly)
- **`overlays/{home,remote,local}/`** - Environment-specific overrides and additions
- **`bootstrap/{home,remote,local}/`** - Per-environment cluster setup scripts

### Adding Infrastructure Components

1. Create base in `infrastructure/base/component/` (namespace.yaml, helm-values.yaml, kustomization.yaml)
2. Create overlays in `infrastructure/overlays/{env}/component/` with env-specific patches
3. Reference the base from each overlay's kustomization.yaml

### Adding Applications

1. Create base in `apps/base/appname/` (rollout.yaml, service, namespace, kustomization.yaml)
2. Create overlays in `apps/overlays/{env}/appname/` with env-specific `httproute.yaml` (Gateway API)
3. Add to `apps/overlays/{env}/kustomization.yaml`

### CI/CD Pipeline (cicd/)

- **WorkflowTemplates** go in `cicd/workflow-templates/` — reusable build pipelines
- **EventSources** go in `cicd/event-sources/` — webhook listeners
- **Sensors** go in `cicd/sensors/` — event-to-workflow triggers
- Pipeline resources are applied directly (not via Kustomize) to the home cluster only
- Use BuildKit rootless for container image builds (no Docker-in-Docker)
- Images are pushed to Harbor (`harbor.k8s.home.example.com`)

### Conventions

- Use Kustomize (`kustomization.yaml`) in every subdirectory
- Use Helm only for third-party charts; store only `helm-values.yaml` overrides
- Layer Helm values: `-f base/helm-values.yaml -f overlays/{env}/helm-values.yaml`
- Each component gets its own subdirectory with `namespace.yaml` + `kustomization.yaml`
- Bootstrap scripts use `env.example` with same placeholder conventions as Docker services
- Use Gateway API (HTTPRoute) for routing, not Ingress or IngressRoute
- Use `kind: Rollout` (Argo Rollouts) instead of `kind: Deployment` for apps with canary/blue-green strategy
- Canary traffic routing uses the Gateway API plugin (`argoproj-labs/gatewayAPI`)
- Validate manifests with `kubeconform` (pre-commit hook)

## File Conventions

- YAML indentation: 2 spaces (consistent within file)
- Line endings: LF (Unix)
- Trailing whitespace: None
- End of file: Single newline

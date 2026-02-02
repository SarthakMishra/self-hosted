# Self-Hosted Infrastructure

Ansible automation and Docker Compose templates for self-hosted server deployment.

## Repository Structure

```
home-server/       # Ansible playbook for home lab deployment
remote-server/     # Ansible playbook for VPS/cloud deployment
hetzner/           # Hetzner cloud-init configuration
service-templates/ # Docker Compose service templates
  ├── home/        # Home network services
  ├── remote/      # Production/cloud services
  └── local/       # Local development services
scripts/           # Utility scripts
```

## Quick Start

### 1. Clone and Setup

```bash
git clone <repo-url>
cd self-hosted
```

### 2. Deploy Infrastructure

```bash
# Home Server
cd home-server
cp secrets.example.yml secrets.yml  # Edit with your values
ansible-playbook -i inventory.yml playbook.yml

# Remote Server
cd remote-server
cp secrets.example.yml secrets.yml  # Edit with your values
ansible-playbook -i inventory.yml playbook.yml
```

### 3. Deploy Services

```bash
# Setup Docker context for remote deployment
docker context create myserver --docker "host=ssh://user@server"
docker context use myserver

# Deploy service
cd service-templates/remote/n8n
cp env.example .env  # Edit with your values
docker compose up -d
```

## Service Templates

### Home Services

| Service | Description |
|---------|-------------|
| [adguard](service-templates/home/adguard/) | DNS ad-blocking |
| [arr-stack](service-templates/home/arr-stack/) | Media automation suite |
| [frigate](service-templates/home/frigate/) | NVR with AI detection |
| [immich](service-templates/home/immich/) | Photo management |
| [portainer](service-templates/home/portainer/) | Docker management UI |
| [speedtest-tracker](service-templates/home/speedtest-tracker/) | Internet speed and uptime monitoring |
| [traefik](service-templates/home/traefik/) | Reverse proxy with Let's Encrypt |

### Remote Services

| Service | Description |
|---------|-------------|
| [traefik](service-templates/remote/traefik/) | Reverse proxy with CrowdSec |
| [vaultwarden](service-templates/remote/vaultwarden/) | Password manager |
| [n8n](service-templates/remote/n8n/) | Workflow automation |
| [umami](service-templates/remote/umami/) | Web analytics |
| [affine](service-templates/remote/affine/) | Knowledge base |
| [nocodb](service-templates/remote/nocodb/) | Database UI |
| [directus](service-templates/remote/directus/) | Headless CMS |
| [prefect](service-templates/remote/prefect/) | Workflow orchestration |
| [meilisearch](service-templates/remote/meilisearch/) | Search engine |
| [serpbear](service-templates/remote/serpbear/) | SEO rank tracking |
| [reacher](service-templates/remote/reacher/) | Email verification |
| [watchtower](service-templates/remote/watchtower/) | Container updates |

### Local Services

| Service | Description |
|---------|-------------|
| [traefik](service-templates/local/traefik/) | Local reverse proxy |
| [openwebui](service-templates/local/openwebui/) | LLM chat interface |
| [litellm-proxy](service-templates/local/litellm-proxy/) | LLM API gateway |
| [jupyter](service-templates/local/jupyter/) | Notebooks |
| [cronicle](service-templates/local/cronicle/) | Job scheduler |
| [searxng](service-templates/local/searxng/) | Search engine |
| [openhands](service-templates/local/openhands/) | AI coding agent |
| [qbittorrent](service-templates/local/qbittorrent/) | Torrent client with VPN |

## Development

### Pre-commit Hooks

This repo uses pre-commit hooks for code quality:

```bash
# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

Hooks include: gitleaks, yamllint, ansible-lint, docker-compose validation.

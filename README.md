# Self-Hosted Infrastructure

Complete automation for self-hosted server deployment with production-ready Docker services.

## 📦 Components

- **`home-server/`** - Ansible automation for home lab deployment
- **`remote-server/`** - Ansible automation for VPS/cloud deployment
- **`service-templates/`** - Production-ready Docker Compose services

---

## 🏠 Home Server

**Infrastructure**: Ansible automation for home lab setup with hardware optimization.

- [**Complete Setup Guide**](home-server/README.md) - Automated deployment
- [**Service Deployment**](home-server/docs/service-deployment-guide.md) - Deploy applications
- [**Manual Storage Setup**](home-server/docs/manual-storage.md) - Storage configuration

### Available Services

| Service | Description | Domain Example |
|---------|-------------|----------------|
| **[Traefik](service-templates/home/traefik/)** | Reverse proxy with SSL automation | `traefik.home.local` |
| **[AdGuard](service-templates/home/adguard/)** | Network-wide ad blocking & DNS | `dns.home.local` |
| **[Portainer](service-templates/home/portainer/)** | Docker container management | `portainer.home` |
| **[Immich](service-templates/home/immich/)** | Google Photos alternative | `photos.home.local` |
| **[Frigate](service-templates/home/frigate/)** | NVR with AI object detection | `nvr.home.local` |
| **[ARR Stack](service-templates/home/arr-stack/)** | Complete media automation suite | Multiple domains |

#### ARR Stack Components
- **Sonarr** - TV show management | `sonarr.home.local`
- **Radarr** - Movie management | `radarr.home.local`
- **Prowlarr** - Indexer management | `prowlarr.home.local`
- **Bazarr** - Subtitle management | `bazarr.home.local`
- **qBittorrent** - Torrent client with VPN | `qbt.home.local`
- **Plex** - Media streaming server | `plex.home.local`
- **Jellyseerr** - Media request management | `requests.home.local`

---

## ☁️ Remote Server

**Infrastructure**: Ansible automation for VPS deployment with enterprise security.

- [**Complete Setup Guide**](remote-server/README.md) - Automated deployment
- [**Service Deployment**](remote-server/docs/service-deployment-guide.md) - Deploy applications

### Available Services

| Service | Description | Use Case |
|---------|-------------|----------|
| **[Traefik](service-templates/remote/traefik/)** | Reverse proxy with CrowdSec security | Load balancer |
| **[Vaultwarden](service-templates/remote/vaultwarden/)** | Bitwarden-compatible password manager | Security |
| **[Umami](service-templates/remote/umami/)** | Privacy-focused web analytics | Analytics |
| **[Affine](service-templates/remote/affine/)** | Modern knowledge base & docs | Productivity |
| **[n8n](service-templates/remote/n8n/)** | Workflow automation platform | Automation |
| **[NocoDB](service-templates/remote/nocodb/)** | Airtable alternative database | Database |
| **[Prefect](service-templates/remote/prefect/)** | Modern data workflow orchestration | Data Engineering |
| **[Directus](service-templates/remote/directus/)** | Headless CMS with admin panel | Content Management |
| **[SerpBear](service-templates/remote/serpbear/)** | Search engine rank tracking | SEO |
| **[Watchtower](service-templates/remote/watchtower/)** | Automated container updates | Maintenance |

---

## 💻 Local Development

**Infrastructure**: Services for local development and AI workflows.

| Service | Description | Access |
|---------|-------------|---------|
| **[Traefik](service-templates/local/traefik/)** | Local reverse proxy | `traefik.local` |
| **[Open WebUI](service-templates/local/openwebui/)** | ChatGPT-like interface for LLMs | `chat.local` |
| **[LiteLLM Proxy](service-templates/local/litellm-proxy/)** | Universal LLM API gateway | `localhost:4000` |
| **[Jupyter](service-templates/local/jupyter/)** | Interactive notebooks | `localhost:8888` |
| **[Cronicle](service-templates/local/cronicle/)** | Visual cron job scheduler | `cron.local` |
| **[SearXNG](service-templates/local/searxng/)** | Privacy-focused search engine | `search.local` |
| **[Camoufox](service-templates/local/camoufox/)** | Stealth browser automation service | `localhost:3000` |

---

## 🚀 Quick Start

### 1. Infrastructure Deployment
```bash
# Home Server
cd home-server
ansible-playbook -i inventory/stage1-bootstrap.yml playbooks/bootstrap.yml

# Remote Server
cd remote-server
ansible-playbook -i inventory/stage1-system-setup.yml playbooks/system-setup.yml
```

### 2. Service Deployment
```bash
# Copy service template
cp -r service-templates/home/traefik /path/to/docker/services/

# Configure environment
cp env.example .env
# Edit .env with your settings

# Deploy
docker compose up -d
```

### 3. Production Services
```bash
# Deploy all services
ansible-playbook -i inventory/stage2-hardened.yml playbooks/services.yml
```

---

## 🔧 Architecture

### Network Design
- **Home**: Bridge networks with Traefik SSL termination
- **Remote**: App network with CrowdSec protection
- **Local**: Development network for local services

### Security Features
- **Remote**: CrowdSec intrusion prevention, security headers
- **Home**: DNS filtering, VPN integration, SSL automation
- **All**: Non-root containers, health checks, resource limits

### Storage Strategy
- **Persistent volumes**: Application data
- **Bind mounts**: Configuration files
- **Shared storage**: Multi-service data access

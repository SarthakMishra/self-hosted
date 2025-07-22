# Self-Hosted Infrastructure Automation

> [!WARNING] 
> ⚠️ **This entire project is AI-generated. Use with caution!**

Complete infrastructure-as-code solution using Ansible for automated deployment of production-ready, self-hosted server environments with reverse proxy and automatic SSL.

## Features

- **Smart connection detection with automatic fallback**
- **Fully idempotent and resumable deployment**
- System hardening with security best practices
- Admin user creation with SSH configuration
- Tailscale mesh VPN integration
- UFW firewall configuration with Docker security fix
- Docker installation with production configuration
- **MergerFS storage pool setup (interactive drive selection)**
- **Samba file sharing setup (interactive password configuration)**
- Nginx-proxy for local `.home` domain routing
- DNSmasq for local DNS resolution 
- Cloudflared tunnel for secure external access (automated service discovery)
- Log rotation and cleanup automation
- System validation and verification

## Quick Start

### Prerequisites

- Ansible installed (`pip install ansible`)
- Ubuntu 22.04+ Server installed on your home lab machine
- Network access to the server from your Ansible control machine  
- Cloudflare account with domain managed by Cloudflare

> **⚠️ Important**: During Ubuntu Server installation, **DO NOT** set up SSH keys. The playbook will handle SSH configuration automatically. Simply set a password for the default user (usually `ubuntu`) - this will be used for initial bootstrap only.

### Cloudflare Setup

1. **Enable Zero Trust** (free): Go to your Cloudflare dashboard → Zero Trust
2. **Create Tunnel**: Networks → Tunnels → Create a tunnel → Cloudflared
3. **Get Tunnel ID**: Copy the tunnel ID from the tunnel overview page
4. **Get API Token**: My Profile → API Tokens → Create Token
   - **Account permissions**: Cloudflare Tunnel → Edit
   - **Zone permissions**: DNS → Edit
5. **Get Account ID**: Found in the right sidebar of your Cloudflare dashboard

### Setup - Staged Deployment

```bash
# 1. Configure vault with all settings
cp group_vars/vault.yml.example group_vars/vault.yml
nano group_vars/vault.yml  # Configure bootstrap and production credentials

# 2. Stage 1: Bootstrap fresh Ubuntu server
ansible-playbook -i inventory/stage1-bootstrap.yml playbooks/bootstrap.yml

# 3. Stage 2: System setup (hardening, Tailscale, firewall)
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml

# 4. Manual reboot required
ssh <user>@<ip> "sudo reboot"  # Reboot to apply system changes remotely

# 5. Stage 3: Storage infrastructure (MergerFS + Samba) - OPTIONAL
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/storage.yml
# OR: Set up storage manually - see docs/manual-storage.md

# 6. Stage 4: Docker and services (Docker + networking + monitoring)
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml
```

The deployment uses **staged approach** for clean separation and easy troubleshooting:

### 🔄 Four-Stage Deployment Process

#### 🔐 Stage 1: Bootstrap (Fresh Ubuntu)
- **Inventory**: `stage1-bootstrap.yml` (password authentication)
- **Playbook**: `bootstrap.yml`
- **Purpose**: Create admin user, install SSH keys, disable password auth
- **Connection**: `ubuntu@IP` with password → SSH keys only

#### 🔧 Stage 2: System Setup (SSH Hardened)  
- **Inventory**: `stage2-hardened.yml` (SSH key authentication)
- **Playbook**: `system-setup.yml`
- **Purpose**: System hardening, Tailscale, firewall configuration
- **Connection**: `ubuntu@IP` with SSH keys → `admin@tailscale`
- **⚠️ Manual reboot required** after this stage

#### 💽 Stage 3: Storage Infrastructure (Storage Foundation) - **OPTIONAL**
- **Inventory**: `stage3-tailscale.yml` (admin via Tailscale)
- **Playbook**: `storage.yml`  
- **Purpose**: MergerFS storage pool + Samba file sharing
- **Connection**: `admin@tailscale` (production access)
- **Alternative**: Manual setup with full control - see [`docs/manual-storage.md`](docs/manual-storage.md)

#### 🐳 Stage 4: Docker and Services (Applications)
- **Inventory**: `stage3-tailscale.yml` (admin via Tailscale)
- **Playbook**: `services.yml`
- **Purpose**: Docker installation + Nginx-proxy, DNSmasq, Cloudflared, Netdata
- **Connection**: `admin@tailscale` (production access)

### ✅ Benefits of Staged Approach
- **Clear separation**: Each stage has distinct purpose and credentials
- **Manual reboot control**: Reboot when convenient between stages
- **Optional storage**: Use automated or manual storage setup as preferred
- **Storage foundation first**: Build storage before services that depend on it
- **Easy troubleshooting**: Issues isolated to specific stages
- **Flexible resumption**: Resume from any stage if needed
- **No complex state detection**: Simple, predictable progression

## Configuration

### Staged Inventory Files
Each stage uses a specific inventory file with appropriate connection settings:

#### Stage 1: Bootstrap (`inventory/stage1-bootstrap.yml`)
```yaml
all:
  children:
    bootstrap_servers:
      hosts:
        server:
          ansible_host: "{{ vault_bootstrap_host }}"  # Direct IP
  vars:
    ansible_user: "{{ vault_bootstrap_user }}"        # ubuntu
    ansible_ssh_pass: "{{ vault_bootstrap_password }}" # Password auth
```

#### Stage 2: Hardened (`inventory/stage2-hardened.yml`)  
```yaml
all:
  children:
    hardened_servers:
      hosts:
        server:
          ansible_host: "{{ vault_bootstrap_host }}"  # Still direct IP
  vars:
    ansible_user: "{{ vault_bootstrap_user }}"        # ubuntu (SSH keys)
    ansible_ssh_private_key_file: "{{ vault_ansible_ssh_private_key_file }}"
```

#### Stage 3: Production (`inventory/stage3-tailscale.yml`)
```yaml
all:
  children:
    production_servers:
      hosts:
        server:
          ansible_host: "{{ vault_production_host }}"  # Tailscale hostname
  vars:
    ansible_user: "{{ vault_production_user }}"       # admin user
    ansible_ssh_private_key_file: "{{ vault_ansible_ssh_private_key_file }}"
```

### group_vars/vault.yml
**Staged credentials configuration**:
```yaml
# STAGE 1: BOOTSTRAP CREDENTIALS (Fresh Ubuntu Install)
vault_bootstrap_host: "192.168.1.100"         # Server IP during initial setup
vault_bootstrap_user: "ubuntu"                # Default Ubuntu user  
vault_bootstrap_password: "your-password"     # Initial SSH password

# STAGE 3: PRODUCTION CREDENTIALS (After Complete Setup)
vault_production_host: "homeserver"           # Tailscale hostname (MagicDNS)
vault_production_user: "admin"                # Final admin user

# SSH Configuration
vault_admin_ssh_public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
vault_ansible_ssh_private_key_file: "~/.ssh/id_ed25519"

# Tailscale & Cloudflare Configuration
vault_tailscale_auth_key: "tskey-auth-xxxxx"
vault_cloudflared_tunnel_id: "12345678-1234-5678-9abc-123456789abc"
vault_cloudflared_api_token: "your-cloudflare-api-token"
vault_cloudflared_account_id: "your-cloudflare-account-id"
vault_cloudflared_external_domain: "yourdomain.com"
```

**🎯 Clean stage separation:**
- **Stage 1**: Bootstrap credentials for fresh Ubuntu
- **Stage 2**: Same user but with SSH keys (transition stage)
- **Stage 3**: Admin user via Tailscale (production access)

### SSH Agent Authentication (Recommended)

For enhanced security, use an SSH agent instead of private key files:

**Bitwarden SSH Agent:**
```bash
# 1. Store SSH keys in Bitwarden vault
# 2. Enable SSH agent in Bitwarden desktop client
# 3. Comment out vault_ansible_ssh_private_key_file in vault.yml
# 4. Run playbook - Bitwarden will prompt for authorization
```

**Traditional SSH Agent:**
```bash
# 1. Start SSH agent and add keys
ssh-agent bash
ssh-add ~/.ssh/id_ed25519

# 2. Comment out vault_ansible_ssh_private_key_file in vault.yml
# 3. Run playbook with SSH_AUTH_SOCK available
```

**Example Configuration:**
See `examples/vault-ssh-agent.yml` for a complete vault.yml template configured for SSH agent authentication.

## Deployment Options

### Complete Staged Setup (Recommended)
```bash
# Stage 1: Bootstrap fresh Ubuntu server (password → SSH keys)
ansible-playbook -i inventory/stage1-bootstrap.yml playbooks/bootstrap.yml

# Stage 2: System setup (hardening, Tailscale, Docker)
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml

# Stage 3: Services (storage, networking, monitoring)
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml
```

### Resume from Any Stage

Each stage is **idempotent** and can be safely re-run:

#### 🔐 Stage 1: Bootstrap (Fresh Ubuntu only)
```bash
ansible-playbook -i inventory/stage1-bootstrap.yml playbooks/bootstrap.yml
```
**Required for:**
- Fresh Ubuntu installation with password access
- Creates admin user and installs SSH keys
- Disables password authentication

#### 🔧 Stage 2: System Setup (After bootstrap or to update system)
```bash
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml
```
**Use for:**
- System updates and hardening
- Tailscale configuration changes
- Docker reinstallation or updates

#### 🚀 Stage 3: Services (Production updates)
```bash
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml
```
**Use for:**
- Adding/updating services
- Storage configuration changes
- Monitoring updates

### Connection Troubleshooting

Each stage has specific connection requirements:

- **Stage 1**: Requires password access to fresh Ubuntu
- **Stage 2**: Requires SSH key access to ubuntu user
- **Stage 3**: Requires SSH key access to admin user via Tailscale

If connection fails, check the appropriate credentials and network access for that stage.

### Partial Deployment (Using Tags)
```bash
# Stage 2: System preparation only
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml --tags "system_preparation"

# Stage 2: Reboot only (after system prep)
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml --tags "reboot"

# Stage 2: Docker setup only
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml --tags "docker_setup"

# Stage 3: Storage setup only (MergerFS + Samba)
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml --tags "storage_setup"

# Stage 3: Networking setup only (nginx-proxy + dnsmasq)
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml --tags "networking_setup"

# Stage 3: External access setup only (Cloudflared)
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml --tags "external_access_setup"

# Stage 3: Monitoring setup only (Netdata)
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml --tags "monitoring_setup"

# Skip specific components
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml --skip-tags "storage_setup"

## 📈 Expanding Storage Pool

When you add new drives to your server, use the expansion playbook:

```bash
# Option 1: Use helper script (recommended)
./scripts/expand-storage.sh

# Option 2: Run playbook directly
ansible-playbook -i inventory/hosts.yml playbooks/expand-storage.yml
```

**Features:**
- **🚀 Zero downtime** - Pool remains accessible during expansion
- **🔒 Data protection** - No risk to existing data
- **🎯 Interactive** - Select only new drives to add
- **⚡ Instant capacity** - New space available immediately
- **🔄 Automatic integration** - New drives included in pool seamlessly
```

## Deploying Applications

After setup, deploy any web application with both local and external access, plus integrated storage:

```yaml
# docker-compose.yml for any app
services:
  myapp:
    image: nginx:alpine
    networks:
      - home-network
    environment:
      # Local access via nginx-proxy
      - VIRTUAL_HOST=myapp.home
      - VIRTUAL_PORT=80
    volumes:
      # Direct access to unified storage pool
      - /srv/storage/media:/app/media
      - /srv/storage/downloads:/app/downloads
    labels:
      # Optional: External access via Cloudflare tunnel
      - "cloudflare.zero_trust.access.tunnel.public_hostname=myapp.gooffy.in"
      - "cloudflare.zero_trust.access.tunnel.service=http://myapp:80"

networks:
  home-network:
    external: true
```

**Access Methods:**
- **Local Web**: `http://myapp.home` (no SSL needed, resolved by local DNS)
- **External Web**: `https://myapp.gooffy.in` (automatic SSL + security via Cloudflare)
- **File Access**: `\\YOUR_SERVER_IP\storage` (Windows) - same files your Docker apps use!

**Popular Service Examples:**
```yaml
# Sonarr - TV show management
volumes:
  - /srv/storage/media/tv:/tv
  - /srv/storage/downloads:/downloads

# Immich - Photo management  
volumes:
  - /srv/storage/media/photos:/usr/src/app/upload

# qBittorrent - Download client
volumes:
  - /srv/storage/downloads:/downloads
```

## DNS Configuration

### 🎯 Recommended Setup: Tailscale MagicDNS

This is the **best approach** because it works automatically on all your devices (phone, laptop, etc.) when connected to Tailscale.

#### Step 1: Deploy Your Server
```bash
# Deploy with the Ansible playbook (includes Tailscale + dnsmasq)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml
```

#### Step 2: Configure Tailscale Admin Console
1. Go to [Tailscale Admin Console → DNS](https://login.tailscale.com/admin/dns)
2. **Enable MagicDNS** (toggle it on)
3. Click **Add nameserver**
4. Add: `100.x.x.x:53` (your server's Tailscale IP from playbook output)
5. **Restrict to domain**: `home`
6. Click **Save**

#### Step 3: Configure Search Domains
In the same DNS settings:
1. **Search domains**: Add `home`
2. **Save**

#### Step 4: Test on Any Device
```bash
# On any device connected to Tailscale
nslookup sonarr.home
# Should resolve to your server IP

# Browse to services
curl http://sonarr.home
curl http://plex.home
```

### 🌟 Why This is the Best Approach

✅ **Automatic**: Works on all Tailscale devices (phone, laptop, etc.)  
✅ **Secure**: Only works when connected to your Tailscale network  
✅ **No Router Changes**: Doesn't affect your home network  
✅ **Remote Access**: Works from anywhere with Tailscale  
✅ **Split DNS**: `.home` goes to your server, everything else normal  

### 🔧 How It Works

```
Your Phone/Laptop (with Tailscale)
        ↓ DNS Query: "plex.home"
    Tailscale MagicDNS
        ↓ Routes .home queries to your server
    Your Server DNSmasq (port 53)
        ↓ Resolves to server IP
    nginx-proxy (port 80)
        ↓ Routes to Plex container
    Plex responds
```

### 📱 Result

On any device with Tailscale:
- `http://sonarr.home` → works automatically
- `http://plex.home` → works automatically  
- `http://immich.home` → works automatically
- No DNS configuration needed per device!

**This is the cleanest, most automated solution.** Your `.home` domains will work on your phone, laptop, and any device connected to Tailscale! 🚀

### Alternative DNS Configuration Options

If you prefer not to use Tailscale MagicDNS, you have these options:

**Option 1: Router DHCP Configuration**
- Configure your router to use the server as DNS server for all devices
- Set Primary DNS to your home server IP (e.g., `192.168.1.100`)
- Set Secondary DNS to `8.8.8.8` (fallback)

**Option 2: Manual Device DNS**
- Set DNS on each device individually to your server IP
- Works for device-specific control but requires manual configuration

## Project Structure

```
├── inventory/hosts.yml           # Inventory (references vault.yml variables)
├── group_vars/
│   ├── all.yml                   # Global variables
│   ├── docker.yml               # Docker configuration
│   ├── mergerfs.yml             # MergerFS storage pool configuration
│   ├── nginx_proxy.yml          # Nginx-proxy configuration
│   ├── dnsmasq.yml              # DNSmasq configuration  
│   ├── cloudflared.yml          # Cloudflared tunnel configuration
│   └── vault.yml.example       # Secrets template
├── playbooks/
│   ├── setup.yml                # Complete server setup
│   └── expand-storage.yml       # Storage pool expansion
├── roles/                       # Ansible roles including nginx-proxy, dnsmasq, cloudflared
├── scripts/
│   └── expand-storage.sh        # Helper script for storage expansion
├── docs/                        # Additional documentation guides  
│   ├── service-deployment-guide.md  # Service deployment reference
│   └── ssh-agent-wsl-setup.md   # SSH agent setup for WSL
└── service-templates/           # Example application templates
```

## Storage & File Sharing

The automated setup includes both **MergerFS storage pooling** and **Samba file sharing** with interactive configuration:

### 💾 **MergerFS Storage Pool**
- **Interactive drive selection** during setup - choose which drives to pool
- **Zero-downtime expansion** - add more drives anytime with `./scripts/expand-storage.sh`
- **Mixed drive sizes** - combine 1TB, 2TB, 4TB drives seamlessly
- **No RAID overhead** - full capacity available, individual drive failure isolation
- **Optimized for media servers** - automatic file distribution and Docker integration

### 🗂️ **Samba Network File Sharing**
- **Interactive password setup** during deployment - secure SMB/CIFS access
- **Windows network drive** - Access your entire storage pool as `\\SERVER_IP\storage`
- **Cross-platform compatibility** - Works with Windows, macOS, Linux, mobile devices
- **Docker container integration** - Direct volume mounting to unified storage pool
- **Automatic subdirectory creation** - Pre-organized folders for media, downloads, backups

### 🔧 **How It Works Together**
1. **MergerFS** combines your drives into `/srv/storage` (unified pool)
2. **Samba** shares this entire pool as a network drive
3. **Result**: Windows sees one big drive, files automatically distribute across all physical drives

### 📁 **Access Your Files**
- **Network Share**: `\\YOUR_SERVER_IP\storage` (Windows) or `smb://YOUR_SERVER_IP/storage` (Mac/Linux)
- **Docker Volumes**: Mount `/srv/storage/media/movies`, `/srv/storage/downloads`, etc.
- **Direct Access**: SSH into server and access `/srv/storage/`

### ⚡ **Expansion Process**
When you add new drives:
```bash
# Zero-downtime expansion
./scripts/expand-storage.sh
# 1. Detects new drives automatically
# 2. Interactive selection of drives to add
# 3. Formats and integrates new drives
# 4. Increases pool capacity instantly
# 5. Samba share automatically includes new space
```

### Service Deployment

Ready-to-deploy Docker services are available in `service-templates/`:
- **arr-stack** - Sonarr, Radarr, Prowlarr, qBittorrent with VPN
- **immich** - Photo management and AI tagging
- **frigate** - NVR with AI object detection  
- **adguard** - DNS-based ad blocking
- **portainer** - Docker container management interface

## Security

Files are automatically gitignored:
- `inventory/hosts.yml` - Server IPs
- `group_vars/vault.yml` - Secrets

For CI/CD pipelines, encrypt vault file:
```bash
ansible-vault encrypt group_vars/vault.yml
ansible-playbook playbook.yml --vault-password-file .vault_pass
```

## After Deployment

Your server will have:
- Hardened system with admin user
- Tailscale VPN for secure access
- Production-ready Docker installation
- **MergerFS unified storage pool at `/srv/storage`**
- **Samba file sharing with network drive access**
- **Nginx-proxy for local .home domain access**
- **DNSmasq for local DNS resolution**
- **Cloudflared tunnel for secure external access**
- UFW firewall with Docker security
- Automated cleanup and log rotation

**Access points:**
- SSH: `ssh your-user@homeserver` (via Tailscale MagicDNS)
- **File Share**: `\\SERVER_IP\storage` (Windows) or `smb://SERVER_IP/storage` (Mac/Linux)
- **Web Services**: `http://service.home` (local) or `https://service.domain.com` (external)

**Management commands:**
- Docker status: `/usr/local/bin/docker-status`
- Docker cleanup: `/usr/local/bin/docker-cleanup`
- Storage pool status: `df -h /srv/storage`
- Balance storage pool: `mergerfs.balance /srv/storage`
- **Expand storage pool: `./scripts/expand-storage.sh`**
- **Samba status: `systemctl status smbd`**
- **Samba connections: `smbstatus`**
- Default directory: `/opt/docker`

## 🚀 Quick Reference

### Common Deployment Scenarios

```bash
# Fresh Ubuntu installation (complete 4-stage setup with automated storage)
ansible-playbook -i inventory/stage1-bootstrap.yml playbooks/bootstrap.yml
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml
ssh <user>@<ip> "sudo reboot"  # Manual reboot
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/storage.yml
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml

# Fresh Ubuntu installation (manual storage setup)
ansible-playbook -i inventory/stage1-bootstrap.yml playbooks/bootstrap.yml
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml
ssh <user>@<ip> "sudo reboot"  # Manual reboot
# Follow docs/manual-storage.md for custom storage setup
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml

# Update system configuration (stage 2)
ansible-playbook -i inventory/stage2-hardened.yml playbooks/system-setup.yml

# Update storage (stage 3) 
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/storage.yml

# Update services (stage 4)
ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml

# Add new drives to storage pool (if using automated storage)
./scripts/expand-storage.sh
```

### Staged Connection Methods
- **🔐 Stage 1**: `ubuntu@server-ip` with password (bootstrap)
- **🔧 Stage 2**: `ubuntu@server-ip` with SSH keys (hardened)
- **💽 Stage 3**: `admin@tailscale-hostname` with SSH keys (storage - optional)
- **🐳 Stage 4**: `admin@tailscale-hostname` with SSH keys (services)

### Access Your Server
- **SSH**: `ssh admin@homeserver` (Tailscale MagicDNS)
- **File Share**: `\\SERVER_IP\storage` (network drive)
- **Web Services**: `http://service.home` (local) or `https://service.domain.com` (external)

**Deploy anything with triple access** - local .home domains + secure external access via Cloudflare + network file sharing! 🚀

# Self-Hosted Infrastructure Automation

> [!WARNING] 
> ⚠️ **This entire project is AI-generated. Use with caution!**

Complete infrastructure-as-code solution using Ansible for automated deployment of production-ready, self-hosted server environments with reverse proxy and automatic SSL.

## Features

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

### Setup

```bash
# 1. Configure vault with all settings
cp group_vars/vault.yml.example group_vars/vault.yml
nano group_vars/vault.yml  # Configure initial bootstrap credentials and final setup

# 2. Deploy everything  
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml
```

The playbook will:
1. **Connect using initial Ubuntu credentials (password-based)**
2. **Set up SSH keys and disable password authentication**
3. **Create admin user with passwordless sudo**
4. **Set up Tailscale VPN and transition to secure access**
5. Harden the system and reboot automatically
6. Install and configure Docker
7. **Set up MergerFS storage pool (interactive drive selection)**
8. **Set up Samba file sharing (interactive password configuration)**
9. **Configure nginx-proxy for local .home domains**
10. **Set up DNSmasq for local DNS resolution**
11. **Deploy Cloudflared tunnel for secure external access**
12. Install Netdata monitoring
13. Validate everything is working

## Configuration

### inventory/hosts.yml
```yaml
all:
  children:
    docker_servers:
      hosts:
        server:
          ansible_host: YOUR_SERVER_IP
          node_type: server
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: "{{ vault_ansible_ssh_private_key_file }}"
    ansible_become: true
```

### group_vars/vault.yml
```yaml
# INITIAL BOOTSTRAP AUTHENTICATION (Fresh Ubuntu Install)
vault_ansible_init_host: "192.168.1.100"      # Server IP during initial setup
vault_ansible_init_user: "ubuntu"             # Default Ubuntu user  
vault_ansible_init_password: "your-password"  # Initial SSH password

# FINAL AUTHENTICATION (After Tailscale Setup)
vault_ansible_host: "homeserver"              # Tailscale hostname (MagicDNS enabled)
vault_ansible_user: "admin"                   # Final admin user (created during setup)

# SSH Configuration
vault_admin_ssh_public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."

# Optional: SSH private key file (can use SSH agent instead)
vault_ansible_ssh_private_key_file: "~/.ssh/id_ed25519"

# Tailscale Configuration
vault_tailscale_auth_key: "tskey-auth-xxxxx"

# Cloudflare tunnel configuration:
vault_cloudflared_tunnel_id: "12345678-1234-5678-9abc-123456789abc"
vault_cloudflared_api_token: "your-cloudflare-api-token"
vault_cloudflared_account_id: "your-cloudflare-account-id"
vault_cloudflared_external_domain: "yourdomain.com"
```

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

### Complete Setup (Recommended)
```bash
# Full server setup with automatic reboot + nginx-proxy + cloudflared
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml
```

### Partial Deployment (Using Tags)
```bash
# System preparation only
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "system_preparation"

# Reboot only (after system prep)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "reboot"

# Docker setup only (after system prep + reboot)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "docker_setup"

# MergerFS storage pool setup only
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "mergerfs_setup"

# Samba file sharing setup only
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "samba_setup"

# Local network setup only (nginx-proxy + dnsmasq)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "local_network_setup"

# Cloudflared tunnel setup only
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "cloudflared_setup"

# Skip storage setup (if no additional drives)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --skip-tags "mergerfs_setup"

# Skip reboot (for testing/development)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --skip-tags "reboot"

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
- **Web Services**: `http://service.home` (local) or `https://service.yourdomain.com` (external)

**Management commands:**
- Docker status: `/usr/local/bin/docker-status`
- Docker cleanup: `/usr/local/bin/docker-cleanup`
- Storage pool status: `df -h /srv/storage`
- Balance storage pool: `mergerfs.balance /srv/storage`
- **Expand storage pool: `./scripts/expand-storage.sh`**
- **Samba status: `systemctl status smbd`**
- **Samba connections: `smbstatus`**
- Default directory: `/opt/docker`

**Deploy anything with triple access** - local .home domains + secure external access via Cloudflare + network file sharing! 🚀

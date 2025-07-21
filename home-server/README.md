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
- Nginx-proxy for local `.home` domain routing
- DNSmasq for local DNS resolution 
- Cloudflared tunnel for secure external access (automated service discovery)
- Log rotation and cleanup automation
- System validation and verification

## Quick Start

### Prerequisites

- Ansible installed (`pip install ansible`)
- SSH access to target server
- Ubuntu 20.04+ or Debian 11+ server
- Cloudflare account with domain managed by Cloudflare

### Cloudflare Setup

1. **Enable Zero Trust** (free): Go to your Cloudflare dashboard → Zero Trust
2. **Create Tunnel**: Networks → Tunnels → Create a tunnel → Cloudflared
3. **Get Tunnel ID**: Copy the tunnel ID from the tunnel overview page
4. **Get API Token**: My Profile → API Tokens → Create Token (needs Tunnel:Edit and DNS:Edit permissions)
5. **Get Account ID**: Found in the right sidebar of your Cloudflare dashboard

### Setup

```bash
# 1. Configure inventory
cp inventory/hosts.yml.example inventory/hosts.yml
nano inventory/hosts.yml  # Edit YOUR_SERVER_IP

# 2. Configure secrets
cp group_vars/vault.yml.example group_vars/vault.yml
nano group_vars/vault.yml  # Add your Tailscale auth key, email, etc.

# 3. Deploy everything
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml
```

The playbook will:
1. Harden the system and create admin user
2. Reboot the server automatically
3. Install and configure Docker
4. **Set up nginx-proxy for local .home domains**
5. **Configure DNSmasq for local DNS resolution**
6. **Deploy Cloudflared tunnel for secure external access**
7. Install Netdata monitoring
8. Validate everything is working

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
# SSH Configuration (Option 1: Private key file)
vault_ansible_ssh_private_key_file: "~/.ssh/id_ed25519"
vault_admin_ssh_public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."

# SSH Configuration (Option 2: SSH agent - comment out private key line above)
# vault_admin_ssh_public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."

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

# Local network setup only (nginx-proxy + dnsmasq)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "local_network_setup"

# Cloudflared tunnel setup only
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "cloudflared_setup"

# Skip reboot (for testing/development)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --skip-tags "reboot"
```

## Deploying Applications

After setup, deploy any web application with both local and external access:

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
    labels:
      # Optional: External access via Cloudflare tunnel
      - "cloudflare.zero_trust.access.tunnel.public_hostname=myapp.gooffy.in"
      - "cloudflare.zero_trust.access.tunnel.service=http://myapp:80"

networks:
  home-network:
    external: true
```

**Access Methods:**
- **Local**: `http://myapp.home` (no SSL needed, resolved by local DNS)
- **External**: `https://myapp.gooffy.in` (automatic SSL + security via Cloudflare)

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
├── inventory/hosts.yml.example   # Inventory template
├── group_vars/
│   ├── all.yml                   # Global variables
│   ├── docker.yml               # Docker configuration
│   ├── nginx_proxy.yml          # Nginx-proxy configuration
│   ├── dnsmasq.yml              # DNSmasq configuration  
│   ├── cloudflared.yml          # Cloudflared tunnel configuration
│   └── vault.yml.example       # Secrets template
├── playbooks/
│   └── setup.yml                # Complete server setup
├── roles/                       # Ansible roles including nginx-proxy, dnsmasq, cloudflared
├── docs/                        # Documentation guides
│   └── mergerfs/               # MergerFS setup guide  
└── service-templates/           # Example application templates
```

## Documentation

### Storage Setup

**[MergerFS Guide](docs/mergerfs/)** - Pool multiple drives into a single mount point
- Perfect for home servers with mixed drive sizes (1TB + 2TB drives)  
- No RAID overhead, easy expansion, individual drive failure isolation
- Optimized configuration for media servers and Docker services

### Service Deployment

Ready-to-deploy Docker services are available in `service-templates/`:
- **arr-stack** - Sonarr, Radarr, Prowlarr, qBittorrent with VPN
- **immich** - Photo management and AI tagging
- **frigate** - NVR with AI object detection  
- **adguard** - DNS-based ad blocking

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
- **Nginx-proxy for local .home domain access**
- **DNSmasq for local DNS resolution**
- **Cloudflared tunnel for secure external access**
- UFW firewall with Docker security
- Automated cleanup and log rotation

**Access points:**
- SSH: `ssh admin@your-tailscale-ip`

**Management commands:**
- Docker status: `/usr/local/bin/docker-status`
- Docker cleanup: `/usr/local/bin/docker-cleanup`
- Default directory: `/opt/docker`

**Deploy anything with dual access** - local .home domains + secure external access via Cloudflare! 🚀

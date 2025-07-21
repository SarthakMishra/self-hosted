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
- Cloudflare API token with Tunnel:Edit and DNS:Edit permissions

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
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    ansible_become: true
```

### group_vars/vault.yml
```yaml
vault_tailscale_auth_key: "tskey-auth-xxxxx"
vault_admin_ssh_key: "ssh-rsa AAAAB3..."
# Cloudflare tunnel configuration:
vault_cloudflared_tunnel_id: "12345678-1234-5678-9abc-123456789abc"
vault_cloudflared_api_token: "your-cloudflare-api-token"
vault_cloudflared_account_id: "your-cloudflare-account-id"
vault_cloudflared_external_domain: "yourdomain.com"
```

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
└── service-templates/           # Example application templates
```

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

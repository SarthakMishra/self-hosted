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
- Traefik reverse proxy with Let's Encrypt SSL
- Log rotation and cleanup automation
- System validation and verification

## Quick Start

### Prerequisites

- Ansible installed (`pip install ansible`)
- SSH access to target server
- Ubuntu 20.04+ or Debian 11+ server
- Domain name pointing to your server (for SSL)

### Setup

```bash
# 1. Configure inventory
cp inventory/hosts.yml.example inventory/hosts.yml
nano inventory/hosts.yml  # Edit YOUR_SERVER_IP

# 2. Configure secrets
cp group_vars/vault.yml.example group_vars/vault.yml
nano group_vars/vault.yml  # Add your Tailscale auth key, email, etc.

# 3. Deploy everything (including Traefik!)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml
```

The playbook will:
1. Harden the system and create admin user
2. Reboot the server automatically
3. Install and configure Docker
4. **Set up Traefik reverse proxy with automatic SSL**
5. Validate everything is working

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
# Traefik configuration:
vault_traefik_acme_email: "your@email.com"
```

## Deployment Options

### Complete Setup (Recommended)
```bash
# Full server setup with automatic reboot + Traefik
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

# Traefik setup only (after Docker)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --tags "traefik_setup"

# Skip reboot (for testing/development)
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml --skip-tags "reboot"
```

## Deploying Applications

After setup, deploy any web application with automatic SSL:

```yaml
# docker-compose.yml for any app
services:
  myapp:
    image: nginx:alpine
    networks:
      - app-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host('myapp.yourdomain.com')"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"

networks:
  app-network:
    external: true
```

**That's it!** Automatic HTTPS at `https://myapp.yourdomain.com`

## Project Structure

```
├── inventory/hosts.yml.example   # Inventory template
├── group_vars/
│   ├── all.yml                   # Global variables
│   ├── docker.yml               # Docker configuration
│   ├── traefik.yml              # Traefik configuration
│   └── vault.yml.example       # Secrets template
├── playbooks/
│   └── setup.yml                # Complete server setup
├── roles/                       # Ansible roles including Traefik
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
- **Traefik reverse proxy with automatic SSL**
- UFW firewall with Docker security fix
- Automated cleanup and log rotation

**Access points:**
- SSH: `ssh admin@your-tailscale-ip`

**Management commands:**
- Docker status: `/usr/local/bin/docker-status`
- Docker cleanup: `/usr/local/bin/docker-cleanup`
- Default directory: `/opt/docker`

**Deploy anything with automatic HTTPS** - just add Traefik labels! 🚀

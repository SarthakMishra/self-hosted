# Remote Server Ansible Setup

2-stage deployment for Ubuntu servers with SSH key authentication.

## Prerequisites

- Ubuntu 20.04+ server with SSH key access
- Sudo-enabled user (ubuntu/admin)
- SSH private key configured

## Setup

### 1. Configure Vault

```bash
cp group_vars/vault.yml.example group_vars/vault.yml
nano group_vars/vault.yml  # Add server details and SSH keys
ansible-vault encrypt group_vars/vault.yml  # Optional
```

### 2. Stage 1: System Hardening

System hardening, user creation, and Tailscale:

```bash
ansible-playbook -i inventory/stage1-system-setup.yml playbooks/system-setup.yml
```

**Manual reboot required:**
```bash
ssh <admin_user>@<tailscale_machine_name> 'sudo reboot'
```

### 3. Stage 2: Services

CrowdSec security, Docker, Traefik reverse proxy, and monitoring:

```bash
ansible-playbook -i inventory/stage2-production.yml playbooks/services.yml
```

## Configuration

Key variables in `group_vars/vault.yml`:

```yaml
vault_bootstrap_host: "203.0.113.1"           # Server IP
vault_bootstrap_user: "ubuntu"                # Base user
vault_production_host: "myserver"             # Tailscale hostname
vault_production_user: "admin"                # Admin user to create
vault_admin_ssh_public_key: "ssh-ed25519 ..."
vault_ansible_ssh_private_key_file: "~/.ssh/id_ed25519"
vault_tailscale_auth_key: "tskey-auth-xxxxx..."
vault_traefik_acme_email: "your@email.com"
```

## Deploy Applications

Add Traefik labels for automatic SSL:

```yaml
services:
  myapp:
    image: myapp:latest
    labels:
      - traefik.enable=true
      - traefik.http.routers.myapp.rule=Host(`myapp.yourdomain.com`)
      - traefik.http.routers.myapp.entrypoints=websecure
      - traefik.http.routers.myapp.tls.certresolver=letsencrypt
```

## Access

- SSH: `ssh admin@myserver` (Tailscale) or `ssh admin@server-ip`
- Traefik: `https://traefik.yourdomain.com`
- Netdata: `http://myserver:19999`

## Management

```bash
# Docker
/usr/local/bin/docker-status
/usr/local/bin/docker-cleanup

# Security (CrowdSec)
sudo cscli collections list
sudo cscli alerts list
sudo cscli decisions list
```

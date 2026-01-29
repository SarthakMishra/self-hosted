# Remote Server Ansible Setup

Single-playbook deployment for Ubuntu servers with Docker, Tailscale, and UFW.

## Prerequisites

1. **Ubuntu Server** - Provision Ubuntu 20.04+ from any cloud provider (Hetzner, DigitalOcean, AWS, etc.)
2. **SSH Key Pair** - Generate with:
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com"
   ```
3. **Tailscale Account** - [Sign up here](https://tailscale.com/)
4. **Tailscale Auth Key** - Get from [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
5. **Ansible** - Install with `brew install ansible` or `apt install ansible`

## What It Does

- **Admin User**: Non-root user with SSH key and sudo access
- **Kernel Hardening**: Secure sysctl parameters
- **Docker CE**: With security configurations
- **Tailscale VPN**: Secure access via Tailscale SSH
- **UFW Firewall**: With Docker security fix (prevents Docker from bypassing firewall)
- **Automatic Updates**: Unattended security upgrades

## Files

```
remote-server/
├── ansible.cfg         # Ansible configuration
├── inventory.yml       # Server inventory
├── playbook.yml        # Main playbook (all config included)
├── secrets.example.yml # Template for secrets
└── README.md
```

## Usage

### 1. Configure Secrets

```bash
cp secrets.example.yml secrets.yml
nano secrets.yml
```

### 2. Run Playbook

```bash
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml
```

With encrypted secrets:
```bash
ansible-vault encrypt secrets.yml
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml --ask-vault-pass
```

### 3. Reboot

```bash
ssh admin@your-tailscale-hostname 'sudo reboot'
```

## Access

```bash
ssh admin@your-tailscale-hostname
```

## Management

```bash
# Docker
/usr/local/bin/docker-status
/usr/local/bin/docker-cleanup

# Firewall
sudo ufw status verbose

# Tailscale
tailscale status
```

## UFW + Docker

Docker normally bypasses UFW. This setup includes the UFW-Docker fix which:
- Blocks all Docker container ports by default
- Only allows ports 80/443
- To expose additional ports:

```bash
sudo ufw route allow proto tcp from any to any port 3000
```

## Tags

Run specific parts:
```bash
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml --tags docker
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml --tags firewall
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml --tags users,tailscale
```

Available: `users`, `packages`, `hardening`, `docker`, `tailscale`, `firewall`, `updates`, `security`

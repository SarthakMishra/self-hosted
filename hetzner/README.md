# Hetzner Cloud Server Setup

Cloud-init configuration for provisioning secure Ubuntu servers on Hetzner Cloud.

## What It Does

- **Admin User**: Non-root user with SSH key authentication and sudo access
- **Kernel Security**: Hardened sysctl parameters and system limits
- **Docker CE**: Full Docker installation with security configurations
- **Tailscale VPN**: Secure access via Tailscale SSH (no public SSH needed)
- **Automatic Updates**: Unattended security upgrades

## Prerequisites

1. **Hetzner Cloud Account** - [Sign up here](https://console.hetzner.cloud/)
2. **SSH Key Pair** - Generate with:
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com"
   ```
3. **Tailscale Account** - [Sign up here](https://tailscale.com/)
4. **Tailscale Auth Key** - Get from [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)

## Setup

### 1. Add SSH Key to Hetzner

1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Navigate to **Security** → **SSH Keys**
3. Click **Add SSH Key** and paste your public key

### 2. Create Hetzner Firewall

1. Go to **Firewalls** → **Create Firewall**
2. Name it `default-server-firewall`
3. Add **Inbound Rules**:

   | Protocol | Port | Source IPs | Description |
   |----------|------|------------|-------------|
   | TCP | 22 | 0.0.0.0/0, ::/0 | SSH (remove after Tailscale works) |
   | TCP | 80 | 0.0.0.0/0, ::/0 | HTTP |
   | TCP | 443 | 0.0.0.0/0, ::/0 | HTTPS |

> **Note**: Hetzner's firewall operates at the hypervisor level - Docker **cannot bypass** these rules.

### 3. Prepare Cloud Config

```bash
cp cloud-config.example.yml cloud-config.yml
```

Edit `cloud-config.yml` and replace the 4 placeholders:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `<ADMIN_USERNAME>` | Your admin username | `sarthak` |
| `<SSH_PUBLIC_KEY>` | Your full SSH public key | `ssh-ed25519 AAAA... email` |
| `<TAILSCALE_AUTH_KEY>` | Tailscale auth key | `tskey-auth-xxxxx-xxx...` |
| `<TAILSCALE_HOSTNAME>` | Hostname in Tailscale | `hetzner-prod` |

### 4. Create the Server

1. In Hetzner Console, click **Create Server**
2. **Image**: Ubuntu 24.04
3. **Type**: Choose size (e.g., `CX22`)
4. **SSH Keys**: Select your key
5. **Firewalls**: Select `default-server-firewall`
6. **Cloud config**: Toggle on, paste contents of `cloud-config.yml`
7. Click **Create & Buy now**

### 5. Wait for Provisioning

The server will:
1. Boot and run cloud-init (2-5 minutes)
2. Install packages and configure services
3. Connect to Tailscale
4. Reboot

Monitor in Hetzner Console → **Graphs** tab. Wait until CPU drops to near zero.

### 6. Verify Connection

```bash
# Check Tailscale sees the server
tailscale status

# SSH via Tailscale
ssh your-username@your-tailscale-hostname
```

### 7. Remove Public SSH (Recommended)

Once Tailscale SSH works:
1. Go to **Firewalls** → `default-server-firewall`
2. Delete the SSH (port 22) rule

## Using hcloud CLI

```bash
# Install
brew install hcloud

# Setup
hcloud context create my-project

# Create server
hcloud server create \
  --name prod-web-01 \
  --type cx22 \
  --image ubuntu-24.04 \
  --location nbg1 \
  --ssh-key your-key-name \
  --firewall default-server-firewall \
  --user-data-from-file cloud-config.yml
```

## Troubleshooting

### DNS Resolution Fails

If Docker can't pull images with DNS timeout errors, the cloud-config already sets `--accept-dns=false` for Tailscale. For existing servers:

```bash
sudo tailscale set --accept-dns=false
```

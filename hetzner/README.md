# Hetzner Cloud Server Setup

Automated cloud-init configuration for provisioning secure Ubuntu servers on Hetzner Cloud.

## Overview

This setup replaces the previous Ansible-based `remote-server` configuration with a cloud-init approach that configures the server during first boot. The configuration includes:

- **Admin User**: Non-root user with SSH key authentication and sudo access
- **Kernel Security**: Hardened sysctl parameters and system limits
- **Docker CE**: Full Docker installation with security configurations
- **Tailscale VPN**: Secure access via Tailscale SSH (no public SSH needed)
- **Automatic Updates**: Unattended security upgrades

## Prerequisites

Before launching a server, ensure you have:

1. **Hetzner Cloud Account** - [Sign up here](https://console.hetzner.cloud/)
2. **SSH Key Pair** - Generate with:
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_hetzner
   ```
3. **Tailscale Account** - [Sign up here](https://tailscale.com/)
4. **Tailscale Auth Key** - Get from [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
   - Create a **Reusable** key for easier provisioning
   - Enable **Ephemeral** if you want auto-cleanup when servers are deleted

---

## Manual Setup Steps

### Step 1: Add SSH Key to Hetzner

1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Select your project (or create a new one)
3. Navigate to **Security** → **SSH Keys**
4. Click **Add SSH Key**
5. Paste your public key:
   ```bash
   cat ~/.ssh/id_ed25519_hetzner.pub
   ```
6. Name it something memorable (e.g., `workstation-main`)

### Step 2: Create Hetzner Firewall

1. In Hetzner Cloud Console, go to **Firewalls**
2. Click **Create Firewall**
3. Name it `default-server-firewall`
4. Add the following **Inbound Rules**:

   | Protocol | Port | Source IPs | Description |
   |----------|------|------------|-------------|
   | TCP | 22 | 0.0.0.0/0, ::/0 | SSH (remove after Tailscale works) |
   | TCP | 80 | 0.0.0.0/0, ::/0 | HTTP |
   | TCP | 443 | 0.0.0.0/0, ::/0 | HTTPS |
   | ICMP | - | 0.0.0.0/0, ::/0 | Ping (optional) |

5. **Outbound Rules**: Leave empty (all outbound allowed by default)
6. Click **Create Firewall**

> **Note**: Hetzner's firewall operates at the hypervisor level, meaning Docker **cannot bypass** these rules (unlike UFW/iptables on the host).

### Step 3: Configure Secrets

1. Copy the secrets template:
   ```bash
   cd hetzner/
   cp secrets.yml.example secrets.yml
   ```

2. Edit `secrets.yml` with your values:
   ```bash
   nano secrets.yml
   ```

   ```yaml
   # Your admin username
   ADMIN_USERNAME: "your-username"
   
   # Your SSH public key (full contents of .pub file)
   SSH_PUBLIC_KEY: "ssh-ed25519 AAAA... your@email.com"
   
   # Tailscale auth key
   TAILSCALE_AUTH_KEY: "tskey-auth-xxxxx-xxxxxxxxxxxxxxxxxxxxxxxxx"
   
   # Hostname in Tailscale network
   TAILSCALE_HOSTNAME: "your-server-hostname"
   ```

### Step 4: Generate Cloud-Config

Run the generator script:

```bash
chmod +x generate-config.sh
./generate-config.sh
```

This creates `cloud-config-generated.yml` with your secrets substituted.

### Step 5: Create the Server

1. In Hetzner Cloud Console, click **Create Server**

2. **Location**: Choose your preferred region (e.g., `nbg1` - Nuremberg)

3. **Image**: Select **Ubuntu 24.04** (or latest LTS)

4. **Type**: Choose server size (e.g., `CX22` for small workloads)

5. **Networking**: 
   - Enable **Public IPv4** 
   - Enable **Public IPv6** (recommended)

6. **SSH Keys**: Select your SSH key from Step 1

7. **Firewalls**: Select `default-server-firewall` from Step 2

8. **Cloud config**: 
   - Toggle **Cloud config** on
   - Paste the entire contents of `cloud-config-generated.yml`:
     ```bash
     cat cloud-config-generated.yml
     # Or copy to clipboard:
     # Linux: cat cloud-config-generated.yml | xclip -selection clipboard
     # macOS: cat cloud-config-generated.yml | pbcopy
     ```

9. **Name**: Give your server a name (e.g., `prod-web-01`)

10. Click **Create & Buy now**

### Step 6: Wait for Provisioning

The server will:
1. Boot and run cloud-init (2-5 minutes)
2. Install all packages and configure services
3. Connect to Tailscale
4. Reboot to apply all changes

**Monitor progress** in Hetzner Console:
- Go to your server → **Graphs** tab
- Wait until CPU usage drops to near zero
- This indicates cloud-init has completed

### Step 7: Verify Connection

1. **Check Tailscale connection** (from your local machine):
   ```bash
   tailscale status
   ```
   You should see your new server listed.

2. **SSH via Tailscale**:
   ```bash
   ssh <ADMIN_USERNAME>@<TAILSCALE_HOSTNAME>
   # Example:
   ssh your-username@your-server-hostname
   ```

3. **Verify services are running**:
   ```bash
   # Check Docker
   docker --version
   docker ps
   
   # Check Tailscale
   tailscale status
   ```

### Step 8: Remove Public SSH Access (Recommended)

Once Tailscale SSH is confirmed working:

1. Go to **Firewalls** → `default-server-firewall`
2. **Delete** the SSH (port 22) inbound rule
3. Your server is now only accessible via Tailscale

---

## Alternative: Using hcloud CLI

Instead of the Hetzner Cloud Console, you can use the official `hcloud` CLI for automation.

### Install

```bash
# macOS/Linux
brew install hcloud

# Or download from https://github.com/hetznercloud/cli/releases
```

### Setup

```bash
# Create a context (prompts for API token from Hetzner Console → Security → API Tokens)
hcloud context create my-project
```

### Create Server via CLI

```bash
hcloud server create \
  --name prod-web-01 \
  --type cx22 \
  --image ubuntu-24.04 \
  --location nbg1 \
  --ssh-key workstation-main \
  --firewall default-server-firewall \
  --user-data-from-file cloud-config-generated.yml
```

### Other Useful Commands

```bash
# List servers
hcloud server list

# Delete server
hcloud server delete prod-web-01

# Manage firewalls
hcloud firewall list
hcloud firewall delete default-server-firewall
```

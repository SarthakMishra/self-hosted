# Home Server Ansible Setup

Single-playbook deployment for Ubuntu home servers with Docker, Tailscale, and optional ZFS/SAMBA storage.

## Prerequisites

1. **Ubuntu Server** - Install from [ubuntu.com/download/server](https://ubuntu.com/download/server) with OpenSSH enabled
2. **SSH Key Pair** - Generate with:
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com"
   ```
3. **Tailscale Account** - [Sign up here](https://tailscale.com/)
4. **Tailscale Auth Key** - Get from [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
5. **Ansible** - Install with `brew install ansible` or `apt install ansible`

## What It Does

**Core (always runs):**
- Admin user with SSH key and sudo access
- System updates and kernel hardening
- Docker installation and configuration
- Tailscale VPN for remote access
- NFS/CIFS client packages for mounting remote storage
- Automatic security updates

**Optional (via tags):**
- ZFS storage pool creation
- SAMBA file sharing

## Files

```
home-server/
├── ansible.cfg         # Ansible configuration
├── inventory.yml       # Server inventory
├── playbook.yml        # Main playbook
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

**Core only** (Docker host that mounts remote NAS):
```bash
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml
```

**Core + ZFS storage**:
```bash
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml --tags all,zfs
```

**Core + ZFS + SAMBA** (full NAS replacement):
```bash
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml --tags all,zfs,samba
```

**Just add SAMBA** to existing server:
```bash
ansible-playbook -i inventory.yml playbook.yml -e @secrets.yml --tags samba
```

### 3. Reboot

```bash
ssh admin@your-tailscale-hostname 'sudo reboot'
```

## Access

```bash
# SSH via Tailscale
ssh admin@home-server

# SAMBA shares (if enabled)
# Windows: \\home-server-ip\media
# Linux: smb://home-server-ip/media
```

## ZFS Configuration

Configure these in `secrets.yml` before running with `--tags zfs`:

```yaml
vault_zfs_pool_name: "tank"
vault_zfs_devices:
  - "/dev/disk/by-id/ata-WDC_WD40EFRX-001"
  - "/dev/disk/by-id/ata-WDC_WD40EFRX-002"
vault_zfs_raid_type: "mirror"  # mirror, raidz, raidz2, or empty for stripe
```

Find disk IDs with:
```bash
ls -la /dev/disk/by-id/
```

Created datasets:
- `/tank/media`
- `/tank/downloads`
- `/tank/backups`
- `/tank/docker`

## SAMBA Configuration

Configure these in `secrets.yml` before running with `--tags samba`:

```yaml
vault_samba_user: "admin"
vault_samba_password: "your-secure-password"
vault_samba_shares:
  - name: "media"
    path: "/tank/media"
  - name: "downloads"
    path: "/tank/downloads"
```

## Management Commands

```bash
# Docker
/usr/local/bin/docker-status
/usr/local/bin/docker-cleanup

# ZFS (if enabled)
zpool status
zfs list

# SAMBA (if enabled)
smbstatus
sudo systemctl status smbd

# Tailscale
tailscale status
```

## Mounting Remote Storage

If using a separate NAS (like TrueNAS), mount shares on the Docker host:

```bash
# Add to /etc/fstab for NFS
truenas-ip:/mnt/pool/media  /mnt/nas/media  nfs  defaults  0  0

# Or for SAMBA/CIFS
//truenas-ip/media  /mnt/nas/media  cifs  credentials=/etc/samba/credentials,uid=1000  0  0
```

Then mount in Docker containers:
```yaml
services:
  plex:
    volumes:
      - /mnt/nas/media:/media
```

## Tags Reference

| Tag | What it does |
|-----|--------------|
| (default) | Core setup: users, packages, Docker, Tailscale |
| `zfs` | Install ZFS, create pool and datasets |
| `samba` | Install Samba, configure shares |

## No Firewall

This playbook does not configure UFW because:
- Home server is behind router NAT
- External access is via Cloudflare tunnels or Tailscale
- No ports are exposed directly to the internet

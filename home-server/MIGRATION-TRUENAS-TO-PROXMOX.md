# TrueNAS → Proxmox VE Migration Guide

## Current System Inventory

This guide documents the migration path from TrueNAS SCALE 25.04.2.6 to Proxmox VE,
preserving all ZFS data and containerized services.

### Hardware

| Component | Details |
|-----------|---------|
| CPU | Intel Core i7-4770 @ 3.40GHz (4C/8T) |
| RAM | 16 GB |
| Motherboard | Intel H81 |
| Boot Drive | Foxin 256GB SSD (`sde`) |
| Virtualization | VT-x + VT-d (IOMMU enabled) |
| NIC 1 | `enp1s0` — 192.168.29.109/24 (active) |
| NIC 2 | `enp4s0` — down / unused |

### Storage Layout

#### Boot Pool

| Pool | Device | Size | Used | Type |
|------|--------|------|------|------|
| `boot-pool` | `sde3` | 236 GB | 11.9 GB | Single disk (SSD) |

#### Data Pool — `Data` (ZFS STRIPED / no redundancy)

> **⚠️ CRITICAL:** The `Data` pool is a **5-disk stripe (RAID-0)** — all 5 disks are
> individual top-level vdevs with NO parity or mirroring. Loss of ANY single disk
> destroys the entire pool. Handle with extreme care during migration.

| Disk | Device | Model | Serial | Size |
|------|--------|-------|--------|------|
| sdd | sdd1 | ST1000LM035-1RK172 | WSZ0GY8B | 931.5 GB |
| sdc | sdc1 | ST31000528AS | 6VPDB67B | 931.5 GB |
| sdb | sdb1 | WDC WD20EZBX-00AYRA0 | WD-WX12D55E5247 | 1.8 TB |
| sdf | sdf1 | WDC WD20EZBX-00AYRA0 | WD-WX12D55E5NF6 | 1.8 TB |
| sda | sda1 | ST1000LM037-1RC172 | WKPQBCRP | 931.5 GB |

**Total raw capacity:** ~6.34 TB | **Used:** ~4.52 TB (71%) | **Free:** ~1.83 TB

ZFS properties: `compression=lz4`, `atime=off`, `ashift=12`

### ZFS Datasets (Data Pool)

| Dataset | Used | Purpose |
|---------|------|---------|
| `Data/Shared_Storage` | 4.68 TB | Primary data — media, family files, service configs |
| `Data/ix-apps` | 34.6 GB | TrueNAS app configs, Docker state |
| `Data/.system` | 1.97 GB | TrueNAS system metadata |
| `Data/immich` | 370 MB | Immich photo uploads + database |
| `Data/Tailscale` | 96 KB | Tailscale state |
| `Data/.ix-virt` | 1.12 MB | TrueNAS virtualization (empty) |

### Media Data Breakdown (inside `Data/Shared_Storage/Rishi/Selfhosted/data/`)

| Directory | Size | Notes |
|-----------|------|-------|
| `tv/` | ~2.8 TB | TV shows (largest dataset) |
| `torrents/` | ~600 GB | Active/seeding torrents |
| `movies/` | ~393 GB | Movie library |
| `music/` | ~40 GB | Music library |
| `photos/` | unknown | Photo collection |
| `cctv/` | unknown | Security camera footage |
| `downloads/` | unknown | Completed downloads |

**Family data:** `Data/Shared_Storage/SKM/` — family photos (Canon, Sony, mobile)

### Running Services (Docker)

#### Media Stack (arr-stack + Plex)

| Container | Image | Bind Mounts |
|-----------|-------|-------------|
| plex | `plexinc/pms-docker` | config → `config/plex-config`, data → `data/` |
| sonarr | `ghcr.io/hotio/sonarr` | config → `config/sonarr-config`, data → `data/` |
| radarr | `ghcr.io/hotio/radarr` | config → `config/radarr-config`, data → `data/` |
| bazarr | `ghcr.io/hotio/bazarr` | config → `config/bazarr-config`, data → `data/` |
| prowlarr | `ghcr.io/hotio/prowlarr` | config → `config/prowlarr-config` |
| qbittorrent | `ghcr.io/hotio/qbittorrent` | config → `config/qbittorrent-config`, data → `data/` |
| seerr | `ghcr.io/seerr-team/seerr` | config → `config/seerr-config` |
| cleanuparr | `ghcr.io/cleanuparr/cleanuparr` | config → `config/cleanuparr-config`, downloads → `data/downloads` |
| flaresolverr | `ghcr.io/flaresolverr/flaresolverr` | Docker volume |

All configs and data bind-mount from `/mnt/Data/Shared_Storage/Rishi/Selfhosted/`.

#### Infrastructure Services

| Container | Image | Notes |
|-----------|-------|-------|
| traefik | `traefik:latest` | Reverse proxy, bound to 192.168.29.131:{80,443,8080} |
| adguardhome | `adguard/adguardhome` | DNS, bound to 192.168.29.131:{53,853,3030} |
| cloudflared-tunnel | `cloudflare/cloudflared` | Tunnel for external access |
| speedtest-tracker | `lscr.io/linuxserver/speedtest-tracker` | Internet monitoring |

#### Photo Management

| Container | Image | Notes |
|-----------|-------|-------|
| immich | `ghcr.io/immich-app/immich-server:release` | Personal instance |
| immich_machine_learning | `ghcr.io/immich-app/immich-machine-learning:release` | ML backend |
| immich_postgres | `ghcr.io/immich-app/postgres:14-*` | Immich DB |
| immich_redis | `valkey/valkey:8-bookworm` | Immich cache |
| ix-immich-* (4 containers) | Various immich images | TrueNAS-managed Immich (duplicate!) |

#### Other

| Container | Image | Notes |
|-----------|-------|-------|
| wekeep-app + supporting | `wekeep-preview:latest` | Custom app (postgres, redis, meilisearch, minio) |
| ix-tailscale-tailscale-1 | `ghcr.io/tailscale/tailscale` | TrueNAS-managed Tailscale |
| ix-cloudflared-cloudflared-1 | `cloudflare/cloudflared` | TrueNAS-managed Cloudflared (duplicate!) |

### Network Configuration

| Service | Bind Address | Ports |
|---------|-------------|-------|
| Plex | 192.168.29.131 | 32400, 32410-32414 |
| AdGuard | 192.168.29.131 | 53, 853, 3030, 8853 |
| Traefik | 192.168.29.131 | 80, 443, 8080 |
| Tailscale | 100.69.128.26 | — |

Multiple IPs on `enp1s0`: `.109` (primary), `.131` (services), `.132` (secondary)

### SMB Shares

| Share | Path | Guest |
|-------|------|-------|
| Shared_Storage | `/mnt/Data/Shared_Storage` | No |

---

## Why Proxmox Over Plain Ubuntu

Given your use case (media server + Docker experimentation + Kubernetes learning), Proxmox
is the better choice over plain Ubuntu because:

1. **ZFS is a first-class citizen** — Proxmox natively manages ZFS pools through the UI and CLI
2. **VM isolation when needed** — You can run a lightweight Ubuntu VM for Docker/k3s and pass
   the ZFS dataset through as a bind mount, or run containers directly on the host
3. **Snapshot & backup built-in** — Proxmox Backup Server integration, ZFS snapshots in the UI
4. **Web UI for management** — No need to SSH for basic operations
5. **Easy experimentation** — Spin up VMs to test k3s clusters, different OS configurations, etc.
6. **You already have VT-x + VT-d** — Your i7-4770 fully supports virtualization and IOMMU passthrough

---

## Migration Plan

### Phase 0: Pre-Migration Backup (CRITICAL)

Since your Data pool is a **RAID-0 stripe**, there is zero fault tolerance. Before touching
anything, create an off-server backup of irreplaceable data.

#### 0.1 — Identify irreplaceable vs re-downloadable data

```bash
# Irreplaceable (MUST backup externally):
# - Family photos/videos:    /mnt/Data/Shared_Storage/SKM/          (~unknown, likely small)
# - Personal photos:         /mnt/Data/Shared_Storage/Rishi/Selfhosted/data/photos/
# - Immich uploads:          /mnt/Data/immich/uploads/              (~228 MB)
# - CCTV footage:            /mnt/Data/Shared_Storage/Rishi/Selfhosted/data/cctv/
# - Service configs:         /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/
#
# Re-downloadable (lower priority):
# - Movies:    ~393 GB
# - TV:        ~2.8 TB
# - Torrents:  ~600 GB
# - Music:     ~40 GB
```

#### 0.2 — Backup irreplaceable data

Option A — External USB drive:

```bash
# On TrueNAS, plug in a USB drive and mount it
mkdir -p /mnt/backup-usb
mount /dev/sdX1 /mnt/backup-usb

# Backup family data
rsync -avhP /mnt/Data/Shared_Storage/SKM/ /mnt/backup-usb/SKM/
rsync -avhP /mnt/Data/Shared_Storage/Rishi/Selfhosted/data/photos/ /mnt/backup-usb/photos/
rsync -avhP /mnt/Data/immich/uploads/ /mnt/backup-usb/immich-uploads/
rsync -avhP /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/ /mnt/backup-usb/service-configs/
```

Option B — Rsync to another machine on the network:

```bash
rsync -avhP /mnt/Data/Shared_Storage/SKM/ user@other-machine:/backup/SKM/
rsync -avhP /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/ user@other-machine:/backup/service-configs/
rsync -avhP /mnt/Data/immich/uploads/ user@other-machine:/backup/immich-uploads/
```

#### 0.3 — Export service configurations

```bash
# Dump Immich PostgreSQL database
docker exec immich_postgres pg_dumpall -U postgres > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/immich-db-dump.sql

# Dump wekeep PostgreSQL database
docker exec wekeep-postgres pg_dumpall -U postgres > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/wekeep-db-dump.sql

# Export Docker volume data for named volumes that matter
docker run --rm -v traefik_letsencrypt:/data -v /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/traefik-certs:/backup alpine tar czf /backup/letsencrypt.tar.gz -C /data .
docker run --rm -v adguard_adguard_conf:/data -v /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/adguard-backup:/backup alpine tar czf /backup/adguard-conf.tar.gz -C /data .
docker run --rm -v adguard_adguard_work:/data -v /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/adguard-backup:/backup alpine tar czf /backup/adguard-work.tar.gz -C /data .
docker run --rm -v speedtest-tracker_speedtest-tracker-data:/data -v /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/speedtest-backup:/backup alpine tar czf /backup/speedtest.tar.gz -C /data .

# Record container configurations
docker ps --format '{{.Names}}' | while read name; do
  docker inspect "$name" > "/mnt/Data/Shared_Storage/Rishi/Selfhosted/config/docker-inspect-${name}.json"
done

# Save the Plex claim token / preferences if accessible
cp -r /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/plex-config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml \
  /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/plex-preferences-backup.xml 2>/dev/null || true
```

#### 0.4 — Record ZFS pool metadata

```bash
# Save pool configuration for reference during reimport
zpool status Data > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/zpool-status.txt
zfs list -o name,used,avail,refer,mountpoint > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/zfs-list.txt
zfs get all Data > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/zfs-properties-data.txt
zpool get all Data > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/zpool-properties-data.txt
zdb -C Data > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/zdb-config.txt

# Save disk-to-device mapping
ls -la /dev/disk/by-id/ > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/disk-by-id.txt
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINT > /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/lsblk.txt
```

#### 0.5 — Gracefully stop all services

```bash
# Stop all docker containers
docker stop $(docker ps -q)

# Export the ZFS pool cleanly (this unmounts everything)
# DO NOT do this yet — only right before shutdown for Proxmox install
# zpool export Data
```

---

### Phase 1: Install Proxmox VE

#### 1.1 — Create Proxmox USB installer

On your local machine:

```bash
# Download Proxmox VE ISO (latest 8.x)
# https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso

# Write to USB (Linux/macOS)
sudo dd if=proxmox-ve_8.x-x.iso of=/dev/sdX bs=4M status=progress
```

#### 1.2 — Prepare for installation

On TrueNAS, before shutting down:

```bash
# Final graceful export of Data pool
docker stop $(docker ps -q)
sleep 10
zpool export Data
sync
poweroff
```

#### 1.3 — Install Proxmox VE

1. Boot from USB installer
2. Select **Install Proxmox VE (Graphical)**
3. **Target disk:** Select only `sde` (Foxin 256GB SSD) — the boot drive
   - The installer will show disk selection — **make absolutely sure you pick the SSD**
   - You can identify it by size (238.5 GB) and model name
   - Use **ext4** or **ZFS (RAID0)** for the root filesystem on the single SSD
     - ext4 is simpler and wastes less space on a single SSD
     - ZFS single-disk is fine too if you want consistency with your data pool
4. **Country/timezone/keyboard** — set appropriately
5. **Password + email** — set the root password and admin email
6. **Network:**
   - Management interface: `enp1s0`
   - Hostname: `proxmox.home.local` (or your preference)
   - IP: `192.168.29.109/24` (keep the same IP as TrueNAS for minimal disruption)
   - Gateway: `192.168.29.1` (or your router's IP)
   - DNS: `192.168.29.1` (temporary — AdGuard will be restored later)
7. **Install** and reboot

#### 1.4 — Post-install access

- Web UI: `https://192.168.29.109:8006`
- SSH: `ssh root@192.168.29.109`
- Login with the root password you set during install

#### 1.5 — Remove enterprise repo (if no subscription)

```bash
# Disable enterprise repo
sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Remove subscription nag (optional)
sed -Ezi.bak "s/(Ext.Msg.show\(\{.*?title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Update
apt update && apt full-upgrade -y
```

---

### Phase 2: Import ZFS Data Pool

This is the most critical phase. Your existing `Data` pool is intact on the 5 data disks —
Proxmox (based on Debian) has native ZFS support and can import it directly.

#### 2.1 — Verify disks are visible

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
# You should see all 5 data disks plus your SSD boot drive
# The SSD will have the Proxmox partitions on it
```

#### 2.2 — Scan for importable pools

```bash
zpool import
# This should show your "Data" pool as available for import
# Note the pool ID and verify the disk list matches
```

#### 2.3 — Import the pool

```bash
# Import with the same mount structure
zpool import Data

# Verify it imported correctly
zpool status Data
zfs list
```

If the import shows the pool but complains about it being from a different system:

```bash
# Force import (safe — this just overrides the hostid check)
zpool import -f Data
```

#### 2.4 — Verify data integrity

```bash
# Check pool health
zpool status Data
# Should show ONLINE with no errors

# Verify key datasets are accessible
ls -la /mnt/Data/Shared_Storage/
ls -la /mnt/Data/Shared_Storage/Rishi/Selfhosted/config/
ls -la /mnt/Data/Shared_Storage/Rishi/Selfhosted/data/movies/ | head
ls -la /mnt/Data/immich/uploads/

# Run a scrub to verify all data on disk
zpool scrub Data
# Monitor with: zpool status Data (will take several hours on 4.5 TB)
```

#### 2.5 — Clean up TrueNAS-specific datasets

```bash
# These are TrueNAS-specific and won't be needed on Proxmox:
zfs destroy -r Data/.ix-virt
zfs destroy -r Data/.system
zfs destroy -r Data/ix-apps/truenas_catalog

# Keep Data/ix-apps/docker for now (has Docker volumes) — we'll migrate what we need
# Keep Data/ix-apps/app_mounts for Tailscale state if needed
```

#### 2.6 — Register the pool in Proxmox

The pool will auto-import on boot. Verify:

```bash
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs.target

# Test auto-import
zpool export Data && zpool import Data
```

You can also add it as a Proxmox storage backend via the web UI:
- **Datacenter → Storage → Add → ZFS**
- Pool: `Data`
- This lets Proxmox use it for VM disks, containers, etc.

For directory-based storage (to use existing datasets):
- **Datacenter → Storage → Add → Directory**
- Directory: `/mnt/Data/Shared_Storage`
- Content: select what you want (Container templates, ISO images, etc.)

---

### Phase 3: Architecture Decision

You have two approaches for running Docker services on Proxmox:

#### Option A: Docker directly on Proxmox host (Simpler)

```
┌─────────────────────────────────────────────┐
│  Proxmox VE Host (Debian 12)                │
│                                             │
│  ┌─────────────┐  ┌──────────────────────┐  │
│  │ Proxmox UI  │  │ Docker Engine        │  │
│  │ :8006       │  │  ├── Plex            │  │
│  │             │  │  ├── *arr stack      │  │
│  └─────────────┘  │  ├── Traefik         │  │
│                   │  ├── AdGuard         │  │
│  ZFS Pool: Data   │  ├── Immich          │  │
│  └── Shared_Storage  └── etc.            │  │
│  └── immich      │                       │  │
│  └── docker      │                       │  │
│                   └──────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Pros:** Minimal overhead on 16GB RAM, direct ZFS access, simplest setup
**Cons:** Docker on Proxmox host is not officially supported (it works fine but
Proxmox docs warn it can interfere with their networking)

#### Option B: Ubuntu VM for Docker + k3s (Recommended) ✅

```
┌──────────────────────────────────────────────────────┐
│  Proxmox VE Host                                     │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │  Ubuntu 24.04 VM (12-14 GB RAM, 6 cores)      │  │
│  │                                                │  │
│  │  Docker Engine                                 │  │
│  │   ├── Plex                                     │  │
│  │   ├── *arr stack (sonarr, radarr, etc.)        │  │
│  │   ├── Traefik                                  │  │
│  │   ├── AdGuard                                  │  │
│  │   ├── Immich                                   │  │
│  │   └── etc.                                     │  │
│  │                                                │  │
│  │  k3s (optional, for Kubernetes learning)       │  │
│  │                                                │  │
│  │  Mount: /mnt/data → 9p/virtiofs → ZFS pool    │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ZFS Pool: Data (managed by Proxmox host)            │
│  └── Shared_Storage                                  │
│  └── immich                                          │
└──────────────────────────────────────────────────────┘
```

**Pros:** Clean separation, your existing Ansible playbook works as-is, easy to
snapshot/backup the VM, can run k3s alongside Docker, can spin up additional VMs
for testing

**Cons:** ~5-10% overhead from virtualization, slightly more complex storage passthrough

**This guide follows Option B** since it aligns with your goals (Docker + Kubernetes
experimentation) and your existing `home-server/` Ansible playbook is designed for
Ubuntu.

---

### Phase 4: Create Ubuntu VM

#### 4.1 — Download Ubuntu ISO

Via Proxmox UI or CLI:

```bash
cd /var/lib/vz/template/iso/
wget https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso
```

#### 4.2 — Create the VM

Via Proxmox UI: **Create VM** with these settings:

| Setting | Value |
|---------|-------|
| **General** | |
| Name | `docker-host` |
| **OS** | |
| ISO | `ubuntu-24.04.2-live-server-amd64.iso` |
| **System** | |
| BIOS | Default (SeaBIOS) |
| Machine | q35 |
| SCSI Controller | VirtIO SCSI single |
| Qemu Agent | ✅ Enabled |
| **Disks** | |
| Bus | VirtIO Block |
| Storage | local-lvm (on SSD) |
| Disk size | 60 GB (OS + Docker images) |
| Discard | ✅ |
| **CPU** | |
| Cores | 6 (leave 2 for Proxmox) |
| Type | host |
| **Memory** | |
| Memory | 12288 MB (12 GB) |
| Ballooning | ✅ Minimum 4096 MB |
| **Network** | |
| Bridge | vmbr0 |
| Model | VirtIO |
| Firewall | ❌ (handle at router level) |

#### 4.3 — Install Ubuntu

1. Start VM and open the console
2. Install Ubuntu Server 24.04 (minimal install)
3. Set hostname: `docker-host`
4. Create user: `sarthak` (or your preferred admin user)
5. Enable OpenSSH server during install
6. **Do NOT install Docker during Ubuntu setup** — the Ansible playbook handles this
7. Reboot after install

#### 4.4 — Static IP configuration

In the VM, configure a static IP (to match the old TrueNAS service IP):

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```

```yaml
network:
  version: 2
  ethernets:
    enp6s18:  # Check actual interface name with `ip a`
      dhcp4: false
      addresses:
        - 192.168.29.131/24   # Services IP (was secondary on TrueNAS)
      routes:
        - to: default
          via: 192.168.29.1   # Your router
      nameservers:
        addresses:
          - 1.1.1.1           # Temporary until AdGuard is up
          - 8.8.8.8
```

```bash
sudo netplan apply
```

> **Note:** Use `192.168.29.131` (the old TrueNAS service IP) so that all clients
> (Plex, AdGuard DNS, etc.) continue to work without reconfiguration.

#### 4.5 — Install qemu-guest-agent

```bash
sudo apt update && sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

---

### Phase 5: Pass ZFS Storage to the VM

#### 5.1 — Create a dedicated ZFS dataset for the VM

On the Proxmox host:

```bash
# Create a clean dataset structure for the VM
zfs create Data/vm-docker-host
zfs set mountpoint=/mnt/Data/vm-docker-host Data/vm-docker-host
```

#### 5.2 — Set up a bind mount via Proxmox (9p/virtiofs)

The best approach for passing large media libraries is a **filesystem passthrough**.

**Option: 9P Virtio (stable, well-supported):**

On the Proxmox host, edit the VM config:

```bash
# Get the VM ID (e.g., 100)
qm list

# Add filesystem passthrough
# Share the main Shared_Storage directory
nano /etc/pve/qemu-server/100.conf
```

Append these lines to the VM config file:

```
args: -fsdev local,id=shared,path=/mnt/Data/Shared_Storage/Rishi/Selfhosted,security_model=mapped-xattr -device virtio-9p-pci,fsdev=shared,mount_tag=selfhosted
```

> **Note:** If 9p performance is insufficient for Plex (unlikely for streaming but
> possible for library scanning), consider NFS as an alternative — see Section 5.3.

Inside the VM, mount the share:

```bash
# Create mount point
sudo mkdir -p /mnt/data

# Test mount
sudo mount -t 9p -o trans=virtio selfhosted /mnt/data

# Verify
ls /mnt/data/config/
ls /mnt/data/data/movies/ | head

# Make persistent via fstab
echo "selfhosted /mnt/data 9p trans=virtio,version=9p2000.L,rw,_netdev 0 0" | sudo tee -a /etc/fstab

# Also mount immich data separately if needed
```

For the Immich dataset, add a second 9p share or handle it via the same mount.

#### 5.3 — Alternative: NFS passthrough (higher performance)

If 9p doesn't meet performance needs, use NFS:

On the Proxmox host:

```bash
apt install -y nfs-kernel-server

# Export the datasets to the VM only
cat >> /etc/exports << 'EOF'
/mnt/Data/Shared_Storage/Rishi/Selfhosted 192.168.29.131/32(rw,no_subtree_check,no_root_squash,async)
/mnt/Data/immich 192.168.29.131/32(rw,no_subtree_check,no_root_squash,async)
EOF

exportfs -ra
systemctl enable --now nfs-server
```

In the VM:

```bash
sudo apt install -y nfs-common
sudo mkdir -p /mnt/data /mnt/immich

# Mount
sudo mount -t nfs 192.168.29.109:/mnt/Data/Shared_Storage/Rishi/Selfhosted /mnt/data
sudo mount -t nfs 192.168.29.109:/mnt/Data/immich /mnt/immich

# Add to fstab
echo "192.168.29.109:/mnt/Data/Shared_Storage/Rishi/Selfhosted /mnt/data nfs rw,hard,intr,nfsvers=4 0 0" | sudo tee -a /etc/fstab
echo "192.168.29.109:/mnt/Data/immich /mnt/immich nfs rw,hard,intr,nfsvers=4 0 0" | sudo tee -a /etc/fstab
```

---

### Phase 6: Deploy Services with Ansible

#### 6.1 — Update the Ansible inventory

On your local machine, edit `home-server/inventory.yml`:

```yaml
---
all:
  hosts:
    server:
      ansible_host: "192.168.29.131"  # VM IP
  vars:
    ansible_user: "sarthak"
    ansible_ssh_private_key_file: "~/.ssh/id_ed25519"
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o ConnectTimeout=10'
    ansible_become: true
    ansible_python_interpreter: /usr/bin/python3
```

#### 6.2 — Update secrets/vars for the new setup

Edit `home-server/secrets.yml` — key changes:

```yaml
# Point to the VM's mount paths instead of TrueNAS paths
server_host: "192.168.29.131"
bootstrap_user: "sarthak"
admin_user: "sarthak"

# ZFS is managed by Proxmox host, not the VM
# Set empty to skip ZFS tasks in the playbook
zfs_devices: []
zfs_pool_name: ""

# Samba — run on Proxmox host or skip here
samba_shares: []
```

#### 6.3 — Run the playbook

```bash
cd home-server
ansible-playbook -i inventory.yml playbook.yml
```

This will:
- Configure the admin user + SSH
- Install Docker
- Set up Tailscale
- Configure unattended upgrades
- Skip ZFS and Samba (handled on Proxmox host)

#### 6.4 — Deploy Docker Compose services

Using the service templates from `service-templates/home/`:

```bash
# SSH into the VM
ssh sarthak@192.168.29.131

# Verify mounts are working
ls /mnt/data/config/
ls /mnt/data/data/movies/

# Clone or copy your self-hosted repo
git clone <your-repo-url> ~/self-hosted
cd ~/self-hosted
```

Deploy each service — update volume paths to point to `/mnt/data/`:

```bash
# Example: arr-stack
cd service-templates/home/arr-stack
cp env.example .env
# Edit .env — update paths:
#   CONFIG_ROOT=/mnt/data/config
#   DATA_ROOT=/mnt/data/data
nano .env
docker compose up -d

# Traefik
cd ../traefik
cp env.example .env
nano .env
docker compose up -d

# AdGuard
cd ../adguard
cp env.example .env
nano .env
docker compose up -d

# Immich
cd ../immich
cp env.example .env
# Point UPLOAD_LOCATION to /mnt/immich/uploads (or /mnt/data/data/photos)
nano .env
docker compose up -d

# Continue for other services...
```

#### 6.5 — Restore service data

```bash
# Plex — config is already in /mnt/data/config/plex-config/
# Just make sure the Plex container mounts it. Plex should pick up the library.

# Immich — restore the database
docker exec -i immich_postgres psql -U postgres < /mnt/data/config/immich-db-dump.sql

# AdGuard — restore config
docker run --rm -v adguard_adguard_conf:/data -v /mnt/data/config/adguard-backup:/backup alpine sh -c "cd /data && tar xzf /backup/adguard-conf.tar.gz"
docker run --rm -v adguard_adguard_work:/data -v /mnt/data/config/adguard-backup:/backup alpine sh -c "cd /data && tar xzf /backup/adguard-work.tar.gz"

# Traefik — restore Let's Encrypt certs
docker run --rm -v traefik_letsencrypt:/data -v /mnt/data/config/traefik-certs:/backup alpine sh -c "cd /data && tar xzf /backup/letsencrypt.tar.gz"

# wekeep — restore database
docker exec -i wekeep-postgres psql -U postgres < /mnt/data/config/wekeep-db-dump.sql
```

---

### Phase 7: Samba on Proxmox Host

Since SMB shares serve the whole network, run Samba directly on the Proxmox host
(not in the VM):

```bash
# On Proxmox host
apt install -y samba

cat > /etc/samba/smb.conf << 'EOF'
[global]
    workgroup = WORKGROUP
    server string = Proxmox NAS
    netbios name = proxmox
    security = user
    map to guest = never
    create mask = 0664
    directory mask = 0775

[Shared_Storage]
    path = /mnt/Data/Shared_Storage
    browseable = yes
    read only = no
    guest ok = no
    valid users = sarthak
EOF

# Create Samba user (match the TrueNAS password)
useradd -M -s /usr/sbin/nologin sarthak 2>/dev/null || true
smbpasswd -a sarthak

systemctl enable --now smbd nmbd
```

---

### Phase 8: Tailscale on Proxmox Host

For remote access to the Proxmox UI and direct NFS/SMB access:

```bash
# On Proxmox host
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --ssh --hostname=proxmox-home
```

Tailscale in the VM is handled by the Ansible playbook (Phase 6).

---

### Phase 9: Post-Migration Cleanup & Validation

#### 9.1 — Verify all services are running

```bash
# In the VM
docker ps --format 'table {{.Names}}\t{{.Status}}'

# Test key services:
# - Plex:      http://192.168.29.131:32400/web
# - AdGuard:   http://192.168.29.131:3030
# - Traefik:   http://192.168.29.131:8080
# - Sonarr:    via Traefik
# - Radarr:    via Traefik
# - Immich:    via Traefik
```

#### 9.2 — Verify Plex media library

Plex should detect the existing library if the mount paths match. If media paths
changed, you'll need to update the library paths in Plex settings:

1. Open Plex → Settings → Libraries
2. Verify TV/Movies/Music folders point to `/data/tv`, `/data/movies`, `/data/music`
3. Trigger a library scan

#### 9.3 — Verify DNS (AdGuard)

1. Confirm AdGuard is running on 192.168.29.131:53
2. Test: `dig @192.168.29.131 google.com`
3. Update your router DHCP to point DNS at 192.168.29.131

#### 9.4 — Verify SMB shares

From a Windows/Mac client:

```
\\192.168.29.109\Shared_Storage
```

Or from Linux:

```bash
smbclient //192.168.29.109/Shared_Storage -U sarthak
```

#### 9.5 — Clean up old TrueNAS datasets

Once everything is confirmed working (give it at least a week):

```bash
# On Proxmox host — remove TrueNAS Docker state (saves ~35 GB)
zfs destroy -r Data/ix-apps

# Remove old TrueNAS immich if you've migrated to the Docker Compose version
# Only if you've confirmed the new Immich is working with all data
# zfs destroy -r Data/immich
```

#### 9.6 — Clean up duplicate services

Your TrueNAS setup had duplicates:
- **Two Immich instances** (ix-immich-* and standalone immich) — pick one
- **Two Cloudflared tunnels** (ix-cloudflared-* and standalone) — pick one

In the new setup, only deploy one of each.

#### 9.7 — Set up Proxmox VM auto-start

Ensure the Docker VM starts automatically on boot:

In Proxmox UI: **VM → Options → Start at boot: Yes**

Or via CLI:

```bash
qm set 100 --onboot 1 --startup order=1,up=30
```

---

### Phase 10: Future Improvements

Now that you're on Proxmox, consider these improvements:

#### 10.1 — Fix the RAID-0 problem

Your data pool has **zero redundancy**. Any single disk failure kills 4.68 TB of data.
Plan a migration to a safer topology:

| Option | Capacity | Fault Tolerance | Approach |
|--------|----------|-----------------|----------|
| RAIDZ1 (5 disk) | ~4.5 TB | 1 disk | Requires pool recreation |
| Mirror pairs + hot spare | ~2.7 TB | 1 disk per pair | Requires pool recreation |
| Add mirror to each vdev | ~6.3 TB raw, same usable | 1 disk per mirror | Add 5 more disks |

**Recommended:** Buy 2x larger disks, create a RAIDZ1 pool, rsync data over, then
repurpose the old disks.

#### 10.2 — k3s cluster in VMs

With Proxmox, you can create multiple VMs for a proper k3s cluster:

```
┌─────────────────────────────────────────┐
│  Proxmox Host                           │
│                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐│
│  │k3s-master│ │k3s-node-1│ │k3s-node-2││
│  │ 2GB RAM  │ │ 4GB RAM  │ │ 4GB RAM  ││
│  │ 2 cores  │ │ 2 cores  │ │ 2 cores  ││
│  └──────────┘ └──────────┘ └──────────┘│
│                                         │
│  Shared: ZFS Data pool via NFS          │
└─────────────────────────────────────────┘
```

#### 10.3 — Proxmox Backup Server

Install PBS as an LXC container or VM for automated VM backups.

#### 10.4 — Migrate Docker Compose to Kubernetes

Use your `kubernetes/` directory structure to gradually move services from Docker
Compose to k3s, using ArgoCD for GitOps.

---

## Quick Reference: Path Mapping

| TrueNAS Path | Proxmox Host Path | VM Mount Path |
|--------------|--------------------|---------------|
| `/mnt/Data/Shared_Storage` | `/mnt/Data/Shared_Storage` | — (host only, SMB) |
| `/mnt/Data/Shared_Storage/Rishi/Selfhosted/config/` | `/mnt/Data/Shared_Storage/Rishi/Selfhosted/config/` | `/mnt/data/config/` |
| `/mnt/Data/Shared_Storage/Rishi/Selfhosted/data/` | `/mnt/Data/Shared_Storage/Rishi/Selfhosted/data/` | `/mnt/data/data/` |
| `/mnt/Data/immich/` | `/mnt/Data/immich/` | `/mnt/immich/` |
| `/mnt/.ix-apps/docker/volumes/` | — (destroyed after migration) | Docker volumes (recreated) |

## Quick Reference: IP Mapping

| Service | Old (TrueNAS) | New (Proxmox) |
|---------|---------------|---------------|
| Proxmox UI | — | 192.168.29.109:8006 |
| SSH (Proxmox) | — | 192.168.29.109:22 |
| Docker services (VM) | 192.168.29.131 | 192.168.29.131 |
| SMB shares | 192.168.29.109 | 192.168.29.109 |
| AdGuard DNS | 192.168.29.131:53 | 192.168.29.131:53 |
| Plex | 192.168.29.131:32400 | 192.168.29.131:32400 |
| Tailscale (host) | 100.69.128.26 | new Tailscale IP |
| Tailscale (VM) | — | new Tailscale IP |

## Estimated Timeline

| Phase | Duration | Downtime |
|-------|----------|----------|
| Phase 0: Backup | 2-4 hours | None |
| Phase 1: Install Proxmox | 30 min | **Starts here** |
| Phase 2: Import ZFS | 15 min | — |
| Phase 3-4: Create VM | 30 min | — |
| Phase 5: Storage passthrough | 30 min | — |
| Phase 6: Deploy services | 1-2 hours | — |
| Phase 7-8: Samba + Tailscale | 15 min | — |
| Phase 9: Validation | 1-2 hours | **Ends here** |
| **Total** | **5-9 hours** | **~3-5 hours** |

> **Tip:** Do Phase 0 (backup) a day before the migration. The actual migration
> (Phases 1-9) can be done in a single afternoon/evening session.

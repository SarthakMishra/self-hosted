# Manual Storage Setup Guide

This guide provides step-by-step instructions for manually setting up MergerFS storage pooling and Samba file sharing. Use this when you want full control over your storage configuration or have specific requirements not covered by the automated playbook.

## Prerequisites

- Ubuntu 22.04+ server with admin access
- Additional drives available for storage pool
- Basic familiarity with Linux command line

## Overview

We'll set up:
1. **MergerFS** - Unified storage pool from multiple drives
2. **Samba** - Network file sharing (SMB/CIFS)
3. **Firewall** - Secure access configuration

## Part 1: MergerFS Storage Pool Setup

### Step 1: Install Required Packages

```bash
# Update package list
sudo apt update

# Install MergerFS and tools
sudo apt install -y mergerfs parted util-linux xfsprogs
```

### Step 2: Identify Available Drives

```bash
# List all block devices
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE

# Check for LVM drives (to exclude)
sudo pvs 2>/dev/null || true

# Show detailed drive information
sudo fdisk -l
```

**⚠️ Important**: 
- **Never** include your boot drive or system drives
- Avoid drives with existing data you want to keep
- Skip drives that are part of LVM

### Step 3: Select and Prepare Drives

For each drive you want to include in the pool:

```bash
# Replace /dev/sdX with your actual drive
DRIVE="/dev/sdb"  # Example: Change this for each drive

# Check if drive has any partitions
sudo wipefs -a $DRIVE

# Create GPT partition table
sudo parted -s $DRIVE mklabel gpt

# Create primary partition using full drive
sudo parted -s $DRIVE mkpart primary 1MiB 100%

# Force kernel to re-read partition table
sudo partprobe $DRIVE

# Wait for device to be ready
sleep 3

# Verify partition was created
lsblk $DRIVE
```

### Step 4: Format Drives with XFS

```bash
# For each drive partition (e.g., /dev/sdb1, /dev/sdc1, etc.)
PARTITION="/dev/sdb1"  # Change for each partition

# Format with XFS filesystem
sudo mkfs.xfs -f $PARTITION

# Get UUID for mounting
blkid -s UUID -o value $PARTITION
```

### Step 5: Create Mount Points

```bash
# Create base directory for individual drives
sudo mkdir -p /mnt

# Create mount points for each drive
sudo mkdir -p /mnt/disk1
sudo mkdir -p /mnt/disk2
sudo mkdir -p /mnt/disk3
# Add more as needed

# Create MergerFS pool directory
sudo mkdir -p /srv/storage
sudo chown admin:admin /srv/storage
sudo chmod 755 /srv/storage
```

### Step 6: Configure /etc/fstab

Add entries to `/etc/fstab` for persistent mounting:

```bash
# Edit fstab
sudo nano /etc/fstab

# Add lines like these (replace UUIDs with your actual UUIDs):
UUID=12345678-1234-5678-9abc-123456789abc /mnt/disk1 xfs defaults,noatime 0 2
UUID=87654321-4321-8765-cba9-987654321abc /mnt/disk2 xfs defaults,noatime 0 2
UUID=abcdefgh-abcd-efgh-ijkl-abcdefghijkl /mnt/disk3 xfs defaults,noatime 0 2

# MergerFS pool (add after individual drives)
/mnt/disk* /srv/storage fuse.mergerfs defaults,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=mfs 0 0
```

### Step 7: Mount Everything

```bash
# Mount individual drives
sudo mount -a

# Verify individual drives are mounted
df -h /mnt/disk*

# Mount MergerFS pool
sudo mount /srv/storage

# Verify pool is mounted
df -h /srv/storage
```

### Step 8: Create Directory Structure

```bash
# Create organized subdirectories
sudo mkdir -p /srv/storage/{media/{movies,tv,music,photos},downloads,backups,docker}

# Set ownership to admin user
sudo chown -R admin:admin /srv/storage
sudo chmod -R 755 /srv/storage
```

### Step 9: Test MergerFS Pool

```bash
# Create test files
echo "Test file $(date)" | sudo tee /srv/storage/test-$(date +%s).txt

# Check where files are stored
find /mnt/disk* -name "test-*.txt" 2>/dev/null

# Verify pool capacity
df -h /srv/storage
```

## Part 2: Samba File Sharing Setup

### Step 1: Install Samba

```bash
# Install Samba packages
sudo apt install -y samba samba-common-bin cifs-utils
```

### Step 2: Create Samba User

```bash
# Create system user for Samba
sudo useradd -r -s /usr/sbin/nologin -d /nonexistent samba

# Set Samba password (you'll be prompted)
sudo smbpasswd -a samba

# Enable the user
sudo smbpasswd -e samba
```

### Step 3: Configure Samba

Backup original configuration and create new one:

```bash
# Backup original config
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# Create new configuration
sudo tee /etc/samba/smb.conf > /dev/null << 'EOF'
# Samba Configuration for Home Server
[global]
    # Network Settings
    workgroup = HOME
    server string = Home Server
    netbios name = HOMESERVER
    
    # Security Settings
    security = user
    map to guest = never
    guest account = nobody
    
    # Protocol Settings (disable SMB1 for security)
    server min protocol = SMB2
    client min protocol = SMB2
    
    # Authentication Settings
    ntlm auth = yes
    lanman auth = no
    
    # Performance Settings
    use sendfile = yes
    read raw = yes
    write raw = yes
    socket options = TCP_NODELAY IPTOS_LOWDELAY
    
    # Logging Configuration
    log level = 2
    log file = /var/log/samba/log.%m
    max log size = 1000
    
    # Security
    restrict anonymous = 2
    invalid users = root
    unix extensions = no
    wide links = no
    follow symlinks = no
    
    # Local network optimization
    bind interfaces only = no
    interfaces = lo eth0

[storage]
    comment = Shared Storage
    path = /srv/storage
    valid users = samba
    read only = no
    browseable = yes
    create mask = 0664
    directory mask = 0775
    force user = samba
    force group = samba
    guest ok = no
    public = no
    writable = yes
EOF
```

### Step 4: Set Directory Ownership

```bash
# Set ownership of storage to samba user
sudo chown -R samba:samba /srv/storage
sudo chmod -R 775 /srv/storage
```

### Step 5: Test Configuration

```bash
# Test Samba configuration
sudo testparm

# If no errors, restart Samba services
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd

# Check service status
sudo systemctl status smbd nmbd
```

## Part 3: Firewall Configuration

### Step 1: Configure UFW for Samba

```bash
# Allow Samba from local networks
sudo ufw allow from 192.168.0.0/16 to any port 445 proto tcp comment "Samba SMB"
sudo ufw allow from 10.0.0.0/8 to any port 445 proto tcp comment "Samba SMB"
sudo ufw allow from 172.16.0.0/12 to any port 445 proto tcp comment "Samba SMB"

# Allow NetBIOS
sudo ufw allow from 192.168.0.0/16 to any port 139 proto tcp comment "Samba NetBIOS"
sudo ufw allow from 10.0.0.0/8 to any port 139 proto tcp comment "Samba NetBIOS"
sudo ufw allow from 172.16.0.0/12 to any port 139 proto tcp comment "Samba NetBIOS"

# Allow NetBIOS UDP
sudo ufw allow from 192.168.0.0/16 to any port 137:138 proto udp comment "Samba NetBIOS UDP"
sudo ufw allow from 10.0.0.0/8 to any port 137:138 proto udp comment "Samba NetBIOS UDP"
sudo ufw allow from 172.16.0.0/12 to any port 137:138 proto udp comment "Samba NetBIOS UDP"

# If using Tailscale, also allow from Tailscale network
sudo ufw allow from 100.64.0.0/10 to any port 445 proto tcp comment "Samba SMB Tailscale"
sudo ufw allow from 100.64.0.0/10 to any port 139 proto tcp comment "Samba NetBIOS Tailscale"
sudo ufw allow from 100.64.0.0/10 to any port 137:138 proto udp comment "Samba NetBIOS UDP Tailscale"
```

## Part 4: Testing and Verification

### Step 1: Test Local Connectivity

```bash
# Test Samba connectivity locally
smbclient -L localhost -U samba

# Test share access (enter password when prompted)
smbclient //localhost/storage -U samba -c 'ls'
```

### Step 2: Test from Windows

1. Open File Explorer
2. Type in address bar: `\\YOUR_SERVER_IP\storage`
3. Enter credentials:
   - Username: `samba`
   - Password: [password you set]

### Step 3: Test from macOS/Linux

```bash
# Mount the share
sudo mkdir -p /mnt/homeserver
sudo mount -t cifs //YOUR_SERVER_IP/storage /mnt/homeserver -o username=samba,password=YOUR_PASSWORD

# Test access
ls -la /mnt/homeserver

# Unmount when done testing
sudo umount /mnt/homeserver
```

## Part 5: Expanding Storage Later

### Adding New Drives

When you want to add more drives to your pool:

1. **Prepare the new drive** (follow Steps 3-4 from Part 1)
2. **Add mount point**:
   ```bash
   sudo mkdir -p /mnt/disk4  # Next available number
   ```
3. **Add to /etc/fstab**:
   ```bash
   UUID=new-drive-uuid /mnt/disk4 xfs defaults,noatime 0 2
   ```
4. **Mount the drive**:
   ```bash
   sudo mount /mnt/disk4
   ```
5. **Remount MergerFS pool**:
   ```bash
   sudo umount /srv/storage
   sudo mount /srv/storage
   ```

The new capacity is immediately available!

## Management Commands

### Storage Pool Management

```bash
# Check pool status
df -h /srv/storage

# Check individual drives
df -h /mnt/disk*

# Balance files across drives (optional)
mergerfs.balance /srv/storage

# View MergerFS mount options
cat /proc/mounts | grep mergerfs
```

### Samba Management

```bash
# Check Samba status
sudo systemctl status smbd nmbd

# View active connections
sudo smbstatus

# Test configuration
sudo testparm

# Restart services
sudo systemctl restart smbd nmbd

# View logs
sudo tail -f /var/log/samba/log.smbd
```

### Troubleshooting

#### MergerFS Issues

```bash
# Check if individual drives are mounted
mount | grep /mnt/disk

# Check MergerFS pool
mount | grep mergerfs

# Remount pool if needed
sudo umount /srv/storage
sudo mount /srv/storage
```

#### Samba Issues

```bash
# Check Samba configuration
sudo testparm

# Check if ports are listening
sudo netstat -tlnp | grep -E ':(139|445)'

# Check firewall rules
sudo ufw status verbose

# Test local connectivity
smbclient -L localhost -N
```

## Security Considerations

1. **User Access**: Only the `samba` user can access the share
2. **Network Security**: Firewall rules limit access to local networks
3. **Protocol Security**: SMB1 is disabled, only SMB2+ allowed
4. **File Permissions**: Proper ownership and permissions set on directories

## Performance Tips

1. **XFS Filesystem**: Optimized for large files and good performance
2. **MergerFS Options**: 
   - `cache.files=partial` - Improves performance for media files
   - `dropcacheonclose=true` - Manages memory usage
   - `category.create=mfs` - Spreads new files across drives
3. **Network Optimization**: Socket options configured for better throughput

## Backup Recommendations

1. **Important Data**: Always backup critical data separately
2. **Configuration Backup**: Save copies of `/etc/fstab` and `/etc/samba/smb.conf`
3. **Drive Failure**: MergerFS provides no redundancy - consider periodic backups

---

## Next Steps

After setting up storage manually, you can:

1. **Deploy Docker services**: 
   ```bash
   ansible-playbook -i inventory/stage3-tailscale.yml playbooks/services.yml
   ```

2. **Mount storage in Docker containers**:
   ```yaml
   volumes:
     - /srv/storage/media:/app/media
     - /srv/storage/downloads:/app/downloads
   ```

3. **Access your files**:
   - **Windows**: `\\YOUR_SERVER_IP\storage`
   - **macOS**: `smb://YOUR_SERVER_IP/storage`
   - **Linux**: `smb://YOUR_SERVER_IP/storage`

Your manual storage setup is now complete and ready for use! 
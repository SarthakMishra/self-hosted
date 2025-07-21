# MergerFS Setup Guide

Complete guide for setting up MergerFS on your home server to pool 6 drives (4x 1TB + 2x 2TB) into a single mount point.

## Overview

MergerFS is a union filesystem that combines multiple drives into a single mount point without RAID overhead. Perfect for media servers where you want:
- ✅ **No redundancy** - Individual drive failure only loses that drive's data
- ✅ **Mixed drive sizes** - 1TB and 2TB drives work together  
- ✅ **Easy expansion** - Add drives without rebuilding
- ✅ **No stripe overhead** - Full capacity available (8TB total)

## Quick Setup

### 1. Install Latest MergerFS

```bash
# Download latest version (check GitHub for current release)
wget https://github.com/trapexit/mergerfs/releases/download/2.40.2/mergerfs_2.40.2.debian-bookworm_amd64.deb

# Install package
sudo dpkg -i mergerfs_2.40.2.debian-bookworm_amd64.deb

# Install dependencies if needed
sudo apt-get install -f
```

### 2. Prepare Your Drives

**Identify your 6 drives:**
```bash
lsblk
# Example output:
# sdb   8:16   0   931.5G  0 disk  # 1TB drive 1
# sdc   8:32   0   931.5G  0 disk  # 1TB drive 2  
# sdd   8:48   0   931.5G  0 disk  # 1TB drive 3
# sde   8:64   0   931.5G  0 disk  # 1TB drive 4
# sdf   8:80   0   1.8T    0 disk  # 2TB drive 1
# sdg   8:96   0   1.8T    0 disk  # 2TB drive 2
```

**Format drives if needed (⚠️ DESTROYS DATA):**
```bash
# Only run if drives need formatting
sudo mkfs.ext4 /dev/sdb
sudo mkfs.ext4 /dev/sdc
sudo mkfs.ext4 /dev/sdd
sudo mkfs.ext4 /dev/sde
sudo mkfs.ext4 /dev/sdf
sudo mkfs.ext4 /dev/sdg
```

### 3. Create Mount Points

```bash
# Create individual drive mount points
sudo mkdir -p /mnt/disk{1..6}

# Create unified pool mount point
sudo mkdir -p /srv/storage

# Set permissions
sudo chown -R $USER:$USER /mnt/disk* /srv/storage
```

### 4. Configure Automatic Mounting

**Get drive UUIDs for reliable mounting:**
```bash
sudo blkid | grep -E "sd[b-g]"
```

**Edit `/etc/fstab`:**
```bash
sudo nano /etc/fstab
```

**Add these lines (replace UUIDs with your actual UUIDs):**
```bash
# Individual drive mounts  
UUID=your-sdb-uuid-here /mnt/disk1 ext4 defaults,noatime 0 2
UUID=your-sdc-uuid-here /mnt/disk2 ext4 defaults,noatime 0 2  
UUID=your-sdd-uuid-here /mnt/disk3 ext4 defaults,noatime 0 2
UUID=your-sde-uuid-here /mnt/disk4 ext4 defaults,noatime 0 2
UUID=your-sdf-uuid-here /mnt/disk5 ext4 defaults,noatime 0 2
UUID=your-sdg-uuid-here /mnt/disk6 ext4 defaults,noatime 0 2

# MergerFS pool (optimized for media server)
/mnt/disk* /srv/storage fuse.mergerfs defaults,nonempty,allow_other,use_ino,moveonenospc=true,dropcacheonclose=true,category.create=mspmfs,minfreespace=10G,fsname=mergerfs 0 0
```

### 5. Mount Everything

```bash
# Mount individual drives
sudo mount -a

# Verify mounts
df -h
```

**Expected output:**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb        916G   77M  870G   1% /mnt/disk1
/dev/sdc        916G   77M  870G   1% /mnt/disk2  
/dev/sdd        916G   77M  870G   1% /mnt/disk3
/dev/sde        916G   77M  870G   1% /mnt/disk4
/dev/sdf        1.8T  177M  1.7T   1% /mnt/disk5
/dev/sdg        1.8T  177M  1.7T   1% /mnt/disk6
mergerfs        7.3T  462M  6.9T   1% /srv/storage
```

## Configuration Explained

**MergerFS Options Used:**
- `defaults` - Standard mount options
- `nonempty` - Allow mounting over non-empty directory  
- `allow_other` - Allow all users to access
- `use_ino` - Better inode handling
- `moveonenospc=true` - Move files when drive full
- `dropcacheonclose=true` - Better for media streaming
- `category.create=mspmfs` - Most free space + path preservation
- `minfreespace=10G` - Keep 10GB free on each drive
- `fsname=mergerfs` - Easy identification in df output

## Testing Your Setup

**Create test files:**
```bash
# Test file creation
echo "Test file 1" > /srv/storage/test1.txt
echo "Test file 2" > /srv/storage/test2.txt

# Check which drives they landed on
find /mnt/disk* -name "test*.txt" -exec ls -la {} \;
```

**Verify pool capacity:**
```bash
df -h /srv/storage
# Should show ~7.3TB total (after filesystem overhead)
```

## Integration with Services

**Update your Docker services to use `/srv/storage`:**
```yaml
# Example for arr-stack
services:
  sonarr:
    volumes:
      - /srv/storage/media/tv:/tv
      - /srv/storage/downloads:/downloads
```

**Create organized structure:**
```bash
mkdir -p /srv/storage/{media/{movies,tv,music},downloads,backups}
```

## Maintenance Commands

**Check pool status:**
```bash
df -h /srv/storage
```

**View individual drive usage:**
```bash
df -h /mnt/disk*
```

**Balance files across drives (if needed):**
```bash
# Install mergerfs-tools for balancing
sudo apt install mergerfs-tools

# Balance pool (runs in background)
mergerfs.balance /srv/storage
```

## Troubleshooting

**Pool not mounting on boot:**
```bash
# Check fstab syntax
sudo mount -a

# Check logs
sudo journalctl -u mergerfs
```

**Performance issues:**
```bash
# Add direct_io for better performance on some systems
# Edit /etc/fstab and add direct_io to options:
# /mnt/disk* /srv/storage fuse.mergerfs defaults,direct_io,...
```

**Drive failure:**
- Pool continues working with remaining drives
- Replace failed drive and add back to pool
- Only data on failed drive is lost

## Adding More Drives (Future Expansion)

One of MergerFS's biggest advantages is **zero downtime expansion**. You can add drives to your pool at any time without rebuilding or data migration.

### 🎯 **The Magic: Wildcard Mounting**

Your current `/etc/fstab` entry uses `/mnt/disk*` which automatically includes **any** mount point matching that pattern:

```bash
/mnt/disk* /srv/storage fuse.mergerfs defaults,nonempty,allow_other,use_ino,moveonenospc=true...
```

When you add `/mnt/disk7`, `/mnt/disk8`, etc., they're **automatically included** in the pool!

### 📝 **Step-by-Step Expansion Process**

#### **Step 1: Install New Drive**
```bash
# Power down system
sudo shutdown -h now

# Install new drive physically
# Boot system back up

# Verify new drive is detected
lsblk
# Look for new drive (e.g., /dev/sdh)
```

#### **Step 2: Partition and Format New Drive**
```bash
# Create partition (adjust device as needed)
sudo fdisk /dev/sdh
# Press: n, p, 1, [enter], [enter], w

# Format with ext4
sudo mkfs.ext4 /dev/sdh1

# Get UUID for reliable mounting
sudo blkid /dev/sdh1
# Copy the UUID value
```

#### **Step 3: Create Mount Point**
```bash
# Follow your existing naming convention
sudo mkdir -p /mnt/disk7

# Set permissions
sudo chown -R $USER:$USER /mnt/disk7
```

#### **Step 4: Update `/etc/fstab`**
```bash
# Edit fstab
sudo nano /etc/fstab

# Add new drive entry (replace with your actual UUID)
UUID=your-new-drive-uuid-here /mnt/disk7 ext4 defaults,noatime 0 2
```

**Your fstab will now look like:**
```bash
# Individual drive mounts  
UUID=your-sdb-uuid-here /mnt/disk1 ext4 defaults,noatime 0 2
UUID=your-sdc-uuid-here /mnt/disk2 ext4 defaults,noatime 0 2  
# ... existing drives ...
UUID=your-sdh-uuid-here /mnt/disk7 ext4 defaults,noatime 0 2  # NEW DRIVE

# MergerFS pool (unchanged - wildcard automatically includes disk7!)
/mnt/disk* /srv/storage fuse.mergerfs defaults,nonempty,allow_other,use_ino,moveonenospc=true,dropcacheonclose=true,category.create=mspmfs,minfreespace=10G,fsname=mergerfs 0 0
```

#### **Step 5: Mount and Verify**
```bash
# Mount new drive
sudo mount /mnt/disk7

# Remount MergerFS pool to include new drive
sudo umount /srv/storage
sudo mount /srv/storage

# Verify expansion worked
df -h /srv/storage
# Should show increased total capacity!

# Check all drives are included
findmnt -t fuse.mergerfs
```

### 🚀 **Advanced Expansion Scenarios**

#### **Adding Multiple Drives at Once**
```bash
# Format multiple drives
sudo mkfs.ext4 /dev/sdh1
sudo mkfs.ext4 /dev/sdi1
sudo mkfs.ext4 /dev/sdj1

# Create mount points
sudo mkdir -p /mnt/disk{7..9}

# Add all UUIDs to fstab at once
sudo blkid | grep -E "sd[hij]1" >> uuid_list.txt
# Edit fstab with all new entries

# Mount everything
sudo mount -a
sudo umount /srv/storage && sudo mount /srv/storage
```

#### **Mixed Drive Types**
```bash
# You can mix different drive types and sizes:
# /mnt/disk1 - 1TB HDD
# /mnt/disk2 - 2TB HDD  
# /mnt/disk7 - 4TB HDD    # New larger drive
# /mnt/disk8 - 1TB SSD    # New SSD for faster access

# MergerFS handles this seamlessly with mspmfs policy
```

### 📊 **Verifying Your Expansion**

```bash
# Check total pool capacity
df -h /srv/storage

# View individual drive usage
df -h /mnt/disk*

# Test file creation on new drives
echo "Test file" > /srv/storage/test_expansion.txt
find /mnt/disk* -name "test_expansion.txt"
# Should show which drive received the file based on mspmfs policy
```

### ⚖️ **Rebalancing After Expansion**

After adding drives, your pool might be **unbalanced** (old drives full, new drives empty):

```bash
# Install mergerfs-tools for balancing
sudo apt install mergerfs-tools

# Balance files across all drives (runs in background)
mergerfs.balance /srv/storage

# Monitor progress
watch -n 5 'df -h /mnt/disk*'
```

### 🔧 **Troubleshooting Expansion**

**New drive not showing in pool:**
```bash
# Check if drive mounted correctly
mount | grep disk7

# Check MergerFS mount
findmnt -t fuse.mergerfs

# Remount pool if needed
sudo umount /srv/storage
sudo mount /srv/storage
```

**Capacity not increased:**
```bash
# Verify drive is actually mounted
df -h /mnt/disk7

# Check fstab syntax
sudo mount -a
# Should show no errors

# Force remount
sudo systemctl daemon-reload
sudo umount /srv/storage && sudo mount /srv/storage
```

### 💡 **Best Practices for Expansion**

1. **🔄 Always test mount with `sudo mount -a`** before rebooting
2. **📊 Plan capacity** - Add drives before existing ones fill up completely  
3. **⚖️ Balance periodically** - Especially after adding multiple drives
4. **🏷️ Label drives physically** - Makes future maintenance easier
5. **📝 Document changes** - Keep track of when drives were added
6. **🔍 Monitor health** - Use `smartctl` to check new drive health

### 🎉 **Why This Is Amazing**

**Traditional RAID limitations:**
- ❌ Must add drives in groups (RAID5 = 4 drives minimum)  
- ❌ Rebuild times (hours/days for large arrays)
- ❌ Risk of failure during rebuild
- ❌ Fixed stripe size limitations

**MergerFS advantages:**
- ✅ **Add single drives** anytime
- ✅ **Zero downtime** - services keep running  
- ✅ **Instant expansion** - capacity available immediately
- ✅ **Mix any drive sizes** - 1TB + 8TB works perfectly
- ✅ **Individual drive failure** - only affects that drive's data

## References

- [MergerFS GitHub](https://github.com/trapexit/mergerfs) - Official documentation
- [Perfect Media Server](https://perfectmediaserver.com/02-tech-stack/mergerfs/) - Detailed configuration guide
- [Full Metal Brackets Guide](https://fullmetalbrackets.com/blog/two-drives-mergerfs/) - Practical setup examples
- [OMV MergerFS Plugin Guide](https://wiki.omv-extras.org/doku.php?id=omv6:omv6_plugins:mergerfs) - GUI-based setup alternative

## Next Steps

After MergerFS is working:
1. **Set up Samba** - For Windows network access
2. **Configure services** - Update arr-stack, Immich, Frigate to use `/srv/storage`  
3. **Add monitoring** - Set up disk health monitoring
4. **Plan expansion** - Follow the expansion guide above when you need more storage
5. **Consider SnapRAID** - Add parity protection for your growing pool 
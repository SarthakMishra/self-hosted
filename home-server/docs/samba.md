# Samba SMB/CIFS Setup Guide

**Prerequisites:** Complete [MergerFS Setup](./mergerfs.md) first - this guide assumes you have `/srv/storage` pool ready.

## Overview

After setting up your MergerFS pool at `/srv/storage`, Samba provides network file sharing to access your **entire pooled storage**:

### 📁 What You'll Get
- **MergerFS** combined your drives into `/srv/storage` (e.g., 6x drives → 8TB pool)
- **Samba** shares this entire pool as `\\YOUR_SERVER_IP\storage`
- **Result:** Windows sees one big drive, but files are spread across all your physical drives

- ✅ **Windows network drives** - Access your complete `/srv/storage` pool from Windows Explorer
- ✅ **Docker containers** - Direct volume mounting to pooled storage  
- ✅ **Cross-platform access** - Linux, macOS, mobile devices can access the pool
- ✅ **Secure authentication** - User-based access control
- ✅ **Full pool access** - No subdirectory restrictions, access everything

## 🎯 Recommended Approach: Host Installation

**Host installation is preferred** for better performance, security, and Docker integration.

### Quick Setup (Host Installation)

#### **Step 1: Install Samba**
```bash
sudo apt update
sudo apt install samba samba-common-bin
```

#### **Step 2: Create Samba User**
```bash
# Add system user (no login shell)
sudo useradd -r -s /usr/sbin/nologin samba

# Set Samba password
sudo smbpasswd -a samba
sudo smbpasswd -e samba
```

#### **Step 3: Configure Samba (`/etc/samba/smb.conf`)**
```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
sudo nano /etc/samba/smb.conf
```

**Essential secure configuration:**
```ini
[global]
    # Network settings
    workgroup = HOME
    server string = Home Server
    netbios name = homeserver
    
    # Security settings  
    security = user
    map to guest = never
    guest account = nobody
    
    # Protocol settings (disable SMB1)
    server min protocol = SMB2
    client min protocol = SMB2
    
    # Encryption and signing
    smb encrypt = desired
    server signing = mandatory
    
    # Logging
    log level = 2
    log file = /var/log/samba/log.%m
    max log size = 1000
    
    # Performance
    socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
    use sendfile = yes

# Complete MergerFS pool share (entire /srv/storage)
[storage]
    comment = MergerFS Pooled Storage
    path = /srv/storage
    valid users = samba
    read only = no
    browseable = yes
    create mask = 0664
    directory mask = 0775
    force user = samba
    force group = samba
```

#### **Step 4: Set Permissions for MergerFS Pool**
```bash
# Set ownership of entire MergerFS pool to samba user
sudo chown -R samba:samba /srv/storage

# Set proper permissions for the pool
sudo chmod -R 775 /srv/storage

# Verify permissions on the pool
ls -la /srv/storage

# Create any subdirectories you need (optional)
# The samba user will own the entire pool and can create folders as needed
sudo mkdir -p /srv/storage/{media/{movies,tv,music},downloads,backups}
sudo chown -R samba:samba /srv/storage
```

#### **Step 5: Configure Firewall**
```bash
# Allow Samba through firewall (local network only)
sudo ufw allow from 192.168.0.0/16 to any port 445
sudo ufw allow from 10.0.0.0/8 to any port 445
sudo ufw allow from 172.16.0.0/12 to any port 445

# For Tailscale (if using)
sudo ufw allow from 100.64.0.0/10 to any port 445
```

#### **Step 6: Start and Enable Samba**
```bash
# Test configuration
sudo testparm

# Start services
sudo systemctl enable smbd nmbd
sudo systemctl start smbd nmbd

# Check status
sudo systemctl status smbd
```

### Docker Container Access to MergerFS Pool

**Key advantage of host installation:** Docker containers can directly access your entire `/srv/storage` MergerFS pool without additional configuration.

**Example Docker Compose integration:**
```yaml
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    volumes:
      - /srv/storage/media/tv:/tv          # Direct access to pooled storage
      - /srv/storage/downloads:/downloads   # Downloads across all drives
      
  # All services can access the same unified pool
  immich:
    volumes:
      - /srv/storage/media/photos:/usr/src/app/upload  # Photos stored across all drives
```

### Windows Network Access to MergerFS Pool

**Connect from Windows:**
1. Open Windows Explorer
2. Type in address bar: `\\YOUR_SERVER_IP\storage`
3. Enter credentials: `samba` / `your_password`
4. **You now have access to your entire MergerFS pool** (all drives combined)
5. Map as network drive for permanent access

**PowerShell connection:**
```powershell
# Map your entire MergerFS pool as Z: drive
net use Z: \\YOUR_SERVER_IP\storage /user:samba

# List available shares
net view \\YOUR_SERVER_IP

# Access files across all your pooled drives
dir Z:\
```

## 🔒 Security Best Practices

### Essential Security Settings

```ini
# In /etc/samba/smb.conf [global] section:

# Disable guest access completely
map to guest = never
guest account = nobody

# Require strong authentication
ntlm auth = disabled
lanman auth = no

# Force encryption for sensitive data
smb encrypt = required  # or 'desired' for compatibility

# Enable message signing
server signing = mandatory
client signing = mandatory

# Restrict to secure protocols only
server min protocol = SMB2_10
client min protocol = SMB2

# Disable unnecessary features
unix extensions = no
wide links = no
follow symlinks = no
```

### Network Security

```bash
# Restrict access to local networks only
sudo ufw deny 445
sudo ufw allow from 192.168.0.0/16 to any port 445
sudo ufw allow from 10.0.0.0/8 to any port 445

# Monitor access attempts
sudo tail -f /var/log/samba/log.*
```

### User Management

```bash
# Create dedicated users for different services
sudo useradd -r -s /usr/sbin/nologin media_user
sudo smbpasswd -a media_user

# List Samba users  
sudo pdbedit -L

# Remove user
sudo smbpasswd -x username
sudo pdbedit -x username
```

## 📊 Testing and Verification

### Test Samba Configuration
```bash
# Validate config syntax
sudo testparm

# Test SMB connectivity locally
smbclient -L localhost -U samba

# Test from another machine
smbclient //YOUR_SERVER_IP/storage -U samba
```

### Performance Testing
```bash
# Monitor Samba processes
sudo smbstatus

# Check connections
sudo smbstatus -S

# View locked files
sudo smbstatus -L
```

### Docker Integration Test
```bash
# Test container can write to shared storage
docker run --rm -v /srv/storage:/test alpine sh -c "echo 'test' > /test/docker_test.txt"

# Verify file is accessible via Samba
ls -la /srv/storage/docker_test.txt
```

## 🔧 Troubleshooting

**Connection refused (Windows):**
```bash
# Check if service is running
sudo systemctl status smbd

# Check firewall
sudo ufw status

# Check ports are listening
sudo netstat -tlnp | grep :445
```

**Permission denied:**
```bash
# Check ownership
ls -la /srv/storage

# Fix permissions
sudo chown -R samba:samba /srv/storage
sudo chmod -R 775 /srv/storage
```

**SMB1 errors:**
```ini
# Add to [global] section if legacy clients needed
server min protocol = NT1  # NOT recommended for security
```

**Performance issues:**
```ini
# Optimize for local network in [global]
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
use sendfile = yes
read raw = yes
write raw = yes
```

## 📈 Monitoring and Maintenance

### Log Monitoring
```bash
# Watch Samba logs
sudo tail -f /var/log/samba/log.smbd

# Check for authentication failures  
sudo grep "authentication failure" /var/log/samba/log.*
```

### Regular Maintenance
```bash
# Update Samba regularly
sudo apt update && sudo apt upgrade samba

# Backup configuration
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.$(date +%Y%m%d)

# Clean old logs (optional)
sudo find /var/log/samba -name "*.old" -delete
```

## 🚀 Integration Examples

All services access your unified MergerFS pool through Samba:

### Arr-Stack Integration
```yaml
# In service-templates/home/arr-stack/docker-compose.yml
services:
  sonarr:
    volumes:
      - /srv/storage/media/tv:/tv              # Access pooled storage
      - /srv/storage/downloads:/downloads       # Downloads across all drives
  qbittorrent:
    volumes:
      - /srv/storage/downloads:/downloads       # Same pool, automatic load balancing
```

### Immich Integration  
```yaml
# In service-templates/home/immich/docker-compose.yml  
services:
  immich:
    volumes:
      - /srv/storage/media/photos:/usr/src/app/upload  # Photos across all drives
```

### The Result: Unified Access
- **Windows:** `Z:\` drive shows all your pooled storage
- **Docker:** All containers share the same unified storage pool  
- **MergerFS:** Automatically balances files across your drives
- **Samba:** Provides secure network access to everything

### Windows 10/11 Auto-Mount
```batch
REM Create .bat file for auto-mounting
net use Z: \\YOUR_SERVER_IP\storage /user:samba PASSWORD /persistent:yes
```

## References

- [Samba Official Documentation](https://www.samba.org/samba/docs/)
- [Samba Security Hardening Guide](https://wiki.samba.org/index.php/Hardening_Samba_as_an_AD_DC) - Security best practices
- [Docker Samba Container](https://github.com/dockur/samba) - Alternative containerized approach

## Next Steps

After Samba is working with your MergerFS pool:
1. **Test Windows access** - Verify you can access your entire pooled storage
2. **Configure Docker services** - Update arr-stack, Immich to use `/srv/storage`
3. **Add more drives** - Follow [MergerFS expansion guide](./mergerfs.md#adding-more-drives-future-expansion) when needed
4. **Set up monitoring** - Monitor access logs and pool performance
5. **Plan backups** - Ensure both Samba and MergerFS configurations are backed up
6. **Consider VPN access** - Use Tailscale for secure remote access to your pool 
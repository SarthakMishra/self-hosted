# Local Backup Sync Service

Minimal, robust reverse SSH backup synchronization service that pulls Restic backups from remote Docker Swarm servers to your local machine, providing minimal data loss protection and complete disaster recovery capabilities.

## 🎯 Overview

This Docker Compose stack provides:
- **Automated Reverse SSH Sync**: Pulls backups from remote server every 15 minutes
- **Minimal Data Loss**: Maximum 15-minute Recovery Point Objective (RPO)
- **Complete Disaster Recovery**: Local repository can restore entire infrastructure
- **Independent Local Backups**: Additional protection for local data
- **Health Monitoring**: Simple health check endpoints for service status
- **Intelligent Coordination**: Prevents conflicts between remote backups and sync operations

## 🏗️ Architecture

```
┌─────────────────────────┐    SSH Tunnel     ┌─────────────────────────┐
│     Local Machine       │ ◄─────────────────► │    Remote Server        │
│                         │                     │                         │
│  ┌─────────────────┐   │                     │  ┌─────────────────┐   │
│  │ Restic Sync     │   │                     │  │ Remote Restic   │   │
│  │ Service         │   │                     │  │ Repository      │   │
│  │                 │   │                     │  │                 │   │
│  │ • Pull every    │   │                     │  │ • Docker Swarm  │   │
│  │   15 minutes    │   │                     │  │   backups       │   │
│  │ • Verify        │   │                     │  │ • Daily schedule│   │
│  │ • Cleanup       │   │                     │  │ • Auto cleanup  │   │
│  └─────────────────┘   │                     │  └─────────────────┘   │
│                         │                     │                         │
│  ┌─────────────────┐   │                     │                         │
│  │ Local Master    │   │                     │                         │
│  │ Repository      │   │                     │                         │
│  │                 │   │                     │                         │
│  │ • Complete copy │   │                     │                         │
│  │ • Point-in-time │   │                     │                         │
│  │ • Independent   │   │                     │                         │
│  │   local backups │   │                     │                         │
│  └─────────────────┘   │                     │                         │
└─────────────────────────┘                     └─────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- SSH access to remote server (Tailscale recommended)
- At least 50GB free disk space for local repository

### 1. Initial Setup

```bash
# Clone or download this directory
git clone <your-repo>/local-backup-sync
cd local-backup-sync

# Create required directories
mkdir -p data/{local-repository,logs,local-backups}
mkdir -p config/ssh

# Copy SSH keys for remote server access
cp ~/.ssh/id_rsa config/ssh/
cp ~/.ssh/id_rsa.pub config/ssh/
chmod 600 config/ssh/id_rsa
```

### 2. Configuration

**Configure environment variables:**
```bash
# Create .env file
cat > .env <<EOF
# Remote Server Configuration
REMOTE_HOST=your-server-tailscale-ip-or-hostname
REMOTE_USER=admin
REMOTE_BACKUP_PATH=/opt/docker-swarm/backup

# Sync Settings
SYNC_INTERVAL=900
BANDWIDTH_LIMIT=10M
MAX_RETRIES=3
EOF
```

**Configure Restic password:**
```bash
# Create the same password used on remote server
echo "your-restic-password" > config/restic-password
chmod 600 config/restic-password
```

**Test SSH connection:**
```bash
# Verify you can connect to remote server
ssh -i config/ssh/id_rsa admin@your-server-ip "echo 'Connection successful'"
```

### 3. Deploy Services

```bash
# Start the backup sync stack
docker-compose up -d

# Verify services are running
docker-compose ps

# Check logs for initial sync
docker-compose logs -f restic-sync
```

### 4. Access Health Endpoints

- **Health Check**: http://localhost:8080/health
- **Service Status**: http://localhost:8080/status

## 📊 Service Monitoring

### Health Check Endpoints

**Simple health monitoring:**
- `GET /health` - Basic health status (returns 200 if healthy, 503 if unhealthy)
- `GET /status` - Detailed service information including repository status

### Service Status

**Health checks monitor:**
- Recent log activity (service must be active within last 30 minutes)
- Repository accessibility and integrity
- Service configuration status

## 🔧 Management Commands

### Manual Operations

```bash
# Force immediate sync
docker-compose restart restic-sync

# Check local repository integrity
docker-compose exec restic-sync restic check --read-data-subset=5%

# List available snapshots
docker-compose exec restic-sync restic snapshots

# View sync service logs
docker-compose logs restic-sync

# Check service health
curl http://localhost:8080/health
```

### Repository Management

```bash
# View repository statistics
docker-compose exec restic-sync restic stats

# List snapshots from specific host
docker-compose exec restic-sync restic snapshots --host docker-swarm-hostname

# Restore specific files (example)
docker-compose exec restic-sync restic restore latest --target /tmp/restore --include "*/docker-compose.yml"
```

### Maintenance Tasks

```bash
# Clean old logs
docker-compose exec restic-sync find /app/logs -name "*.log" -mtime +30 -delete

# Prune old snapshots (local repository)
docker-compose exec restic-sync restic forget --keep-last 20 --keep-daily 30 --keep-weekly 12 --keep-monthly 6 --prune

# Update service
docker-compose pull
docker-compose up -d
```

## 🔄 Disaster Recovery

### Complete Remote Server Loss

**If remote server is completely lost:**

1. **Assess local repository status:**
```bash
# Check repository integrity
docker-compose exec restic-sync restic check

# List available snapshots
docker-compose exec restic-sync restic snapshots --compact

# Get latest snapshot info
docker-compose exec restic-sync restic snapshots --latest 1
```

2. **Restore data to new server:**
```bash
# Restore complete Docker Swarm configuration
docker-compose exec restic-sync restic restore <snapshot-id> --target /tmp/recovery

# Copy restored data to new server
rsync -avz /tmp/recovery/ admin@new-server:/
```

3. **Rebuild remote server:**
- Use restored data to rebuild Docker Swarm
- Reinitialize backup system
- Resume normal sync operations

### Point-in-Time Recovery

**Restore to specific point in time:**

```bash
# Find snapshots from specific date
docker-compose exec restic-sync restic snapshots --compact | grep "2024-01-15"

# Restore specific snapshot
docker-compose exec restic-sync restic restore <snapshot-id> --target /tmp/restore-point

# Extract specific service data
docker-compose exec restic-sync restic restore <snapshot-id> --target /tmp/restore \
  --include "*/volumes/service-name/*"
```

## 🛡️ Security Considerations

### Access Control
- SSH key-based authentication only
- Repository encrypted with strong password
- Tailscale network isolation recommended
- No direct internet exposure of sync services

### Network Security
- Persistent SSH connections with heartbeat
- Connection multiplexing for efficiency
- Bandwidth limiting to prevent network saturation
- Automatic reconnection on connection loss

### Data Protection
- End-to-end encryption via Restic
- Local repository access controls
- Secure credential storage
- Audit logging of all operations

## 🔧 Troubleshooting

### Common Issues

**Sync Service Won't Start:**
```bash
# Check SSH connectivity
ssh -i config/ssh/id_rsa admin@your-server "echo test"

# Verify SSH key permissions
ls -la config/ssh/
chmod 600 config/ssh/id_rsa

# Check container logs
docker-compose logs restic-sync
```

**Repository Sync Failures:**
```bash
# Check remote repository status
ssh admin@your-server "systemctl status restic-backup"

# Verify disk space on both ends
df -h data/
ssh admin@your-server "df -h /opt/docker-swarm/backup"

# Test rsync connectivity
rsync -avz --dry-run admin@your-server:/opt/docker-swarm/backup/repository/ data/local-repository/
```

**High Sync Lag:**
```bash
# Check network bandwidth
docker-compose exec restic-sync cat /app/logs/sync-service.log | grep "transfer rate"

# Adjust bandwidth limit
# Edit .env file and restart: BANDWIDTH_LIMIT=20M
docker-compose up -d restic-sync

# Check for backup conflicts
ssh admin@your-server "ls -la /opt/docker-swarm/backup/sync-in-progress"
```

### Health Checks

**Service Health Endpoints:**
- `GET /health` - Basic health status
- `GET /status` - Detailed service information

**Log Analysis:**
```bash
# Real-time sync monitoring
docker-compose logs -f restic-sync | grep "sync"

# Error analysis
docker-compose logs restic-sync | grep -i error

# Performance metrics
docker-compose logs restic-sync | grep "duration\|transferred"
```

## 📈 Performance Tuning

### Bandwidth Optimization
```bash
# Adjust bandwidth limit based on connection
BANDWIDTH_LIMIT=50M  # For fast connections
BANDWIDTH_LIMIT=5M   # For slower connections
```

### Sync Frequency Tuning
```bash
# More frequent sync (5 minutes) for critical systems
SYNC_INTERVAL=300

# Less frequent sync (30 minutes) for stable systems
SYNC_INTERVAL=1800
```

### Repository Optimization
```bash
# Periodic repository maintenance
docker-compose exec restic-sync restic prune --max-unused 10%
docker-compose exec restic-sync restic rebuild-index
```

## 📚 Additional Resources

- [Restic Documentation](https://restic.readthedocs.io/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 🆘 Support

### Getting Help
1. Check service logs: `docker-compose logs`
2. Verify health endpoints: `curl localhost:8080/health`
3. Review configuration files for errors
4. Test SSH connectivity manually

### Backup Strategy Validation
- Regularly test disaster recovery procedures
- Verify backup integrity with sample restores
- Monitor sync lag and adjust frequency as needed
- Keep local repository pruned but retain adequate history

---

**🔐 This minimal service provides robust protection against data loss with automated reverse sync and complete disaster recovery capabilities.** 
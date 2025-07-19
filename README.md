# Self-Hosted Infrastructure Automation

Complete infrastructure-as-code solution using Ansible for automated deployment of production-ready, self-hosted environments. This project automates the entire process from system preparation to Docker Swarm cluster setup, including essential services, security hardening, backup automation, and disaster recovery capabilities.

## ✨ Key Features

- ✅ Complete system hardening with security best practices
- ✅ Admin user creation with proper SSH configuration
- ✅ Tailscale mesh VPN integration for secure networking
- ✅ UFW firewall configuration with Docker integration
- ✅ System update automation with security patches
- ✅ Glances monitoring with web interface
- ✅ Docker CE installation with production configuration
- ✅ Docker Swarm initialization and cluster management
- ✅ Automated cluster scaling with worker and manager node addition
- ✅ Encrypted overlay networks creation
- ✅ Whalewall UFW/Docker integration
- ✅ Production log rotation and cleanup automation
- ✅ Traefik reverse proxy with Cloudflare integration
- ✅ Direct Docker CLI service management with remote context support
- ✅ GitOps automation with GitHub Actions for CI/CD deployments
- ✅ Automated Restic backup with local repository
- ✅ Minimal local backup sync service with 15-minute RPO
- ✅ Complete disaster recovery capabilities
- ✅ Complete Docker environment validation

## 📁 Project Structure

```
├── inventory/
│   └── hosts.yml                 # Ansible inventory configuration
├── group_vars/
│   ├── all.yml                   # Global variables
│   └── docker.yml               # Docker-specific configuration
├── playbooks/
│   ├── docker-setup.yml          # Main Docker setup playbook
│   ├── single-node-docker.yml    # Single node Docker setup
│   ├── multi-node-docker.yml     # Multi-node Docker setup
│   ├── scale-add-workers.yml     # Add worker nodes to existing cluster
│   ├── scale-add-managers.yml    # Add manager nodes for HA
│   ├── node-maintenance.yml      # Node maintenance operations
│   ├── disaster-recovery.yml     # Complete system restoration
│   └── point-in-time-recovery.yml # Intelligent point-in-time recovery
├── roles/
│   # System Preparation Roles
│   ├── system_prep/              # System hardening and user setup
│   ├── admin_user/               # Admin user creation and SSH setup
│   ├── tailscale/                # Tailscale mesh VPN configuration
│   ├── firewall/                 # UFW firewall and Cloudflare rules
│   ├── ssh_hardening/            # SSH security configuration
│   ├── kernel_hardening/         # Kernel security parameters
│   ├── system_update/            # System updates and Glances monitoring
│   # Docker Infrastructure Roles
│   ├── docker_install/           # Docker CE installation and configuration
│   ├── docker_swarm/             # Docker Swarm cluster initialization
│   ├── docker_networks/          # Encrypted overlay network creation
│   ├── docker_security/          # Whalewall UFW/Docker integration
│   ├── docker_maintenance/       # Log rotation and cleanup automation
│   ├── docker_services/          # Traefik reverse proxy deployment
│   ├── restic_backup/            # Automated backup & disaster recovery
│   └── docker_validation/        # Docker verification
├── local-backup-sync/            # Local backup sync service (Docker Compose)
│   ├── docker-compose.yml        # Main sync service stack
│   ├── scripts/                  # Sync and monitoring scripts
│   ├── config/                   # Configuration files
│   └── README.md                 # Local service documentation
├── service-deployment-guide.md   # Zero-downtime deployment procedures
├── scaling-guide.md              # Automated Docker Swarm cluster scaling
└── README.md                     # This documentation
```

## 🎯 Ansible Roles Overview

### System Preparation Roles
- **roles/system_prep/**: System hardening, essential packages, security updates
- **roles/admin_user/**: Admin user creation, SSH key setup, sudo configuration
- **roles/tailscale/**: Tailscale VPN installation, authentication, network setup
- **roles/firewall/**: UFW firewall configuration with Cloudflare IP allowlisting
- **roles/ssh_hardening/**: SSH security configuration, disable root/password auth
- **roles/kernel_hardening/**: Kernel security parameters and system limits
- **roles/system_update/**: System updates, automatic security patches, Glances installation

### Docker Infrastructure Roles
- **roles/docker_install/**: Docker CE installation, daemon configuration, user permissions
- **roles/docker_swarm/**: Swarm initialization, join tokens, cluster management
- **roles/docker_networks/**: Encrypted overlay networks for service communication
- **roles/docker_security/**: Whalewall firewall integration, network security
- **roles/docker_maintenance/**: Log rotation, cleanup automation, system optimization
- **roles/docker_services/**: Traefik reverse proxy deployment with Cloudflare integration
- **roles/restic_backup/**: Automated backup system with local repository, monitoring, and sync coordination
- **roles/docker_validation/**: Docker installation verification, functionality testing

### Docker Setup Playbooks  
- **playbooks/docker-setup.yml**: Complete Docker installation and configuration
- **playbooks/single-node-docker.yml**: Docker setup for single server deployment
- **playbooks/multi-node-docker.yml**: Docker Swarm cluster setup across multiple servers

### Scaling Playbooks
- **playbooks/scale-add-workers.yml**: Add worker nodes to existing Docker Swarm cluster
- **playbooks/scale-add-managers.yml**: Add manager nodes for high availability
- **playbooks/node-maintenance.yml**: Node maintenance operations (drain, activate, pause)

### Disaster Recovery Playbooks
- **playbooks/disaster-recovery.yml**: Complete infrastructure restoration from local backups
- **playbooks/point-in-time-recovery.yml**: Intelligent point-in-time recovery with automatic backup source detection and fallback

### Disaster Recovery Components
- **local-backup-sync/**: Minimal Docker Compose stack for automated reverse SSH backup sync from remote servers
- **playbooks/disaster-recovery.yml**: Complete infrastructure restoration from local backup repository
- **playbooks/point-in-time-recovery.yml**: Intelligent granular recovery with automatic remote/local backup source detection and fallback

## 🚀 Quick Start

### Prerequisites

- Ansible installed on local machine (`pip install ansible`)
- SSH access to target servers
- Target servers running Ubuntu 20.04+ or Debian 11+

### 1. Configure Inventory

```bash
# Copy and customize inventory with your server details
cp inventory/hosts.yml.example inventory/hosts.yml
nano inventory/hosts.yml  # Add your server IPs and configuration
```

### 2. Set Up Sensitive Variables

```bash
# Copy and customize vault template with your secrets
cp group_vars/vault.yml.example group_vars/vault.yml
nano group_vars/vault.yml  # Add your real API keys, passwords, etc.

# Encrypt the vault file (IMPORTANT!)
ansible-vault encrypt group_vars/vault.yml

# Store vault password securely
echo "your-vault-password" > .vault_pass
chmod 600 .vault_pass
# NOTE: .vault_pass is gitignored for security
```

### 3. Deploy Infrastructure

```bash
# Single node deployment
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml --ask-vault-pass

# Multi-node cluster deployment  
ansible-playbook -i inventory/hosts.yml playbooks/multi-node-docker.yml --ask-vault-pass

# Or use vault password file
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml --vault-password-file .vault_pass
```

## 🔧 Configuration Examples

### Basic Single Server Setup

**inventory/hosts.yml:**
```yaml
docker:
  hosts:
    server1:
      ansible_host: 10.1.0.100
      node_type: single
      admin_username: admin
      admin_public_key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
      tailscale_auth_key: "{{ vault_tailscale_auth_key }}"
```

### Multi-Node Cluster Setup

**inventory/hosts.yml:**
```yaml
docker:
  hosts:
    manager1:
      ansible_host: 10.1.0.100
      node_type: manager
      swarm_role: manager
    worker1:
      ansible_host: 10.1.0.101
      node_type: worker
      swarm_role: worker
    worker2:
      ansible_host: 10.1.0.102
      node_type: worker
      swarm_role: worker
```

## 🔄 Deployment Process

The deployment follows a structured, idempotent process:

### Phase 1: System Preparation
- System hardening and security updates
- Admin user creation with SSH access
- Tailscale VPN setup for secure networking
- UFW firewall configuration

### Phase 2: Security Hardening
- SSH security configuration
- Kernel security hardening
- System monitoring setup

### Phase 3: Docker Installation
- Docker CE installation and configuration
- User permission setup
- Docker daemon optimization

### Phase 4: Cluster Setup
- Docker Swarm initialization (managers)
- Worker node joining
- Encrypted overlay network creation

### Phase 5: Essential Services
- Traefik reverse proxy deployment
- Direct Docker CLI service management setup
- Service health validation

### Phase 6: Backup & Monitoring
- Restic backup automation
- Repository initialization
- Backup scheduling and monitoring

### Phase 7: Validation
- Complete system verification
- Service connectivity testing
- Backup system validation

## 🔒 Security Features

- **System Hardening**: Automated security updates, UFW firewall, kernel hardening
- **Network Security**: Tailscale mesh VPN, encrypted Docker networks
- **Access Control**: SSH key authentication, admin user isolation
- **Service Security**: Traefik security headers, direct CLI management
- **Backup Security**: Encrypted Restic repositories, secure sync protocols

## 📋 Service Management

### Services Access
- **Traefik**: Dashboard on port 8080 (if enabled)
- **Glances**: Web interface on port 61208
- **Docker CLI**: Direct service management via SSH and Docker commands
- Services: Traefik reverse proxy, direct CLI-based stack deployments

### Service Deployment
- **Zero-downtime deployments**: Rolling updates via Docker Swarm
- **Service management**: Direct Docker CLI commands
- **Stack management**: Docker Compose files with Swarm deployment
- **Remote management**: Docker Context setup for local development with remote deployment
- **GitOps automation**: GitHub Actions workflows for CI/CD with multi-environment support
- **See**: service-deployment-guide.md for complete setup and deployment procedures

### Backup Management
- **Automated Backups**: Daily at 2 AM with local repository
- **Sync Service**: 15-minute intervals to local machine
- **Monitoring**: Health checks and service status
- **Recovery**: Point-in-time and complete disaster recovery

### Common Commands

```bash
# Check Docker Swarm status
docker node ls

# View running services
docker service ls

# Check Tailscale connectivity
tailscale status

# Monitor system resources
glances

# Backup operations
systemctl status restic-backup.timer
```

---

**Results:** Production-ready infrastructure with essential services deployed in minutes. Includes system hardening, Docker Swarm, Traefik reverse proxy with Cloudflare integration, direct Docker CLI service management, Glances monitoring, automated backups, and complete disaster recovery capabilities. All automated with comprehensive validation and error checking.

## 🔄 Disaster Recovery

**Complete infrastructure recovery from local backups:**

### Local Backup Sync Service
Set up minimal automated reverse SSH sync to pull backups from remote servers:
```bash
# Set up local backup sync service (run on your local machine)
cd local-backup-sync
# Follow setup instructions in local-backup-sync/README.md
docker-compose up -d
```

### Immediate Disaster Recovery
Restore complete infrastructure from local repository:
```bash
# Complete system restoration
ansible-playbook -i inventory/hosts.yml playbooks/disaster-recovery.yml \
  -e local_restic_repository=/path/to/local-backup-sync/data/local-repository

# Point-in-time recovery to specific timestamp (auto-detect backup source)
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml \
  -e local_restic_repository=/path/to/local-backup-sync/data/local-repository \
  -e recovery_timestamp="2024-01-15T10:30:00"

# Force recovery from remote backup (if available)
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml \
  -e recovery_timestamp="2024-01-15T10:30:00" \
  -e recovery_source="remote"

# Force recovery from local backup only
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml \
  -e local_restic_repository=/path/to/local-backup-sync/data/local-repository \
  -e recovery_timestamp="2024-01-15T10:30:00" \
  -e recovery_source="local"

# Service-specific recovery with auto-fallback
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml \
  -e local_restic_repository=/path/to/local-backup-sync/data/local-repository \
  -e recovery_timestamp="2024-01-15T10:30:00" \
  -e recovery_service="traefik"
```

**Key Features:**
- **15-minute RPO**: Maximum data loss window
- **Complete automation**: One-command disaster recovery
- **Point-in-time restore**: Restore to any snapshot in history
- **Intelligent backup source selection**: Auto-detect remote backups with local fallback
- **Service-specific recovery**: Restore individual services
- **Verification**: Automatic integrity checks and validation

### Backup Source Options

**Point-in-time recovery supports multiple backup sources:**

| Source | Description | Use Case |
|--------|-------------|----------|
| `auto` (default) | Try remote first, fallback to local | Normal operations, maximum data freshness |
| `remote` | Use remote repository only | When remote server is available and you want latest data |
| `local` | Use local repository only | When remote server is down or for testing |

**Recovery Source Priority:**
1. **Remote backup** - Most recent data, direct access to server repository
2. **Local backup** - Fallback option, synced every 15 minutes (max 15min lag)

### Common Recovery Scenarios

**Scenario 1: Normal Point-in-Time Recovery**
```bash
# Auto-detect best backup source (recommended)
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml \
  -e local_restic_repository=/path/to/local-backup-sync/data/local-repository \
  -e recovery_timestamp="2024-01-15T10:30:00"
```

**Scenario 2: Remote Server Partially Down (Services Down, SSH Works)**
```bash
# Force local backup to avoid accessing potentially corrupted remote repo
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml \
  -e local_restic_repository=/path/to/local-backup-sync/data/local-repository \
  -e recovery_timestamp="2024-01-15T10:30:00" \
  -e recovery_source="local"
```

**Scenario 3: Network Issues but Server Accessible**
```bash
# Force remote backup for most recent data
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml \
  -e recovery_timestamp="2024-01-15T10:30:00" \
  -e recovery_source="remote"
```

**Scenario 4: Complete Remote Server Loss**
```bash
# Local backup only (remote will auto-fail to local anyway)
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml \
  -e local_restic_repository=/path/to/local-backup-sync/data/local-repository \
  -e recovery_timestamp="2024-01-15T10:30:00" \
  -e recovery_source="local"
```

## 🔒 Security & Privacy

### Protected Files
This repository uses comprehensive `.gitignore` to prevent sensitive data exposure:

**Critical Files (Never Committed):**
- `inventory/hosts.yml` - Server IPs and hostnames
- `group_vars/vault.yml` - Encrypted secrets (API keys, passwords)
- SSH keys, certificates, and auth tokens
- Backup repositories and data
- Environment files with sensitive configuration

**Template Files (Safe to Commit):**
- `inventory/hosts.yml.example` - Inventory template
- `group_vars/vault.yml.example` - Vault template with instructions
- Configuration examples and documentation

### Setting Up Secrets Securely

1. **Copy Templates:**
   ```bash
   cp inventory/hosts.yml.example inventory/hosts.yml
   cp group_vars/vault.yml.example group_vars/vault.yml
   ```

2. **Configure Your Infrastructure:**
   - Edit `inventory/hosts.yml` with your server details
   - Edit `group_vars/vault.yml` with your secrets
   - Never commit these files unencrypted

3. **Encrypt Sensitive Data:**
   ```bash
   ansible-vault encrypt group_vars/vault.yml
   ```

4. **Use Vault in Deployments:**
   ```bash
   ansible-playbook playbook.yml --ask-vault-pass
   # or
   ansible-playbook playbook.yml --vault-password-file .vault_pass
   ```

### Repository Safety
- ✅ **Safe to fork/share** - No sensitive data in version control
- ✅ **Template-based setup** - Clear instructions for configuration
- ✅ **Ansible Vault integration** - Industry-standard secret encryption
- ✅ **Comprehensive gitignore** - Covers all infrastructure file types

**Before making repository public:**
- Verify no `.env` files with real values are committed
- Confirm `inventory/hosts.yml` contains no real IPs
- Ensure all secrets are in encrypted `vault.yml` only
- Check backup directories are excluded from git 
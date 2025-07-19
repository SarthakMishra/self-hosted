# Self-Hosted Infrastructure Automation

> [!WARNING] 
> ⚠️ **This entire project is AI-generated. Use with caution!**
>
> I (the author) have no real-world experience with IT infrastructure or configuration. Please review everything carefully before using in production. Mistakes or misconfigurations are possible—double-check all settings and security!

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


## 🚀 Quick Start (Single Node - Default)

### Prerequisites

- Ansible installed on local machine (`pip install ansible`)
- SSH access to target server
- Ubuntu 20.04+ or Debian 11+ server

### 1. Configure Your Server

```bash
# Copy and customize inventory with your server details
cp inventory/hosts.yml.example inventory/hosts.yml
nano inventory/hosts.yml  # Edit YOUR_SERVER_IP with your actual server IP

# The default single-node setup is ready to use!
# Just replace YOUR_SERVER_IP with your server's IP address
```

**Default configuration works for most cloud providers:**
- ✅ **AWS, DigitalOcean, Linode**: `ansible_user: ubuntu` (default)
- ✅ **Debian images**: Change to `ansible_user: debian`
- ✅ **Uses sudo** - no root login required

### 2. Set Up Your Secrets

```bash
# Copy and customize vault with your API keys
cp group_vars/vault.yml.example group_vars/vault.yml
nano group_vars/vault.yml  # Add your Tailscale auth key, Cloudflare tokens, etc.

# File is automatically gitignored - ready to use!
# No encryption needed for personal use
```

### 3. Deploy Complete Infrastructure (2 Commands)

```bash
# Step 1: System preparation (security, admin user, Tailscale, firewall)
ansible-playbook -i inventory/hosts.yml playbooks/system-preparation.yml

# Step 2: Docker infrastructure (Docker Swarm, networks, Traefik, services)
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml
```

---

## 🏗️ Advanced: Multi-Node Cluster

**When you need high availability or more resources:**

### 1. Switch to Multi-Node Configuration
```bash
# Edit inventory to uncomment production section
nano inventory/hosts.yml
# Comment out single_node section
# Uncomment production section and add your manager/worker IPs
```

### 2. Deploy Multi-Node Cluster
```bash
# Step 1: System preparation on all nodes
ansible-playbook -i inventory/hosts.yml playbooks/multi-node.yml

# Step 2: Docker Swarm cluster setup
ansible-playbook -i inventory/hosts.yml playbooks/multi-node-docker.yml
```

---

## 🔐 Optional: Vault Encryption

**Encryption is optional** since vault files are gitignored. Only needed for:

**✅ CI/CD Pipelines:**
```bash
ansible-vault encrypt group_vars/vault.yml
ansible-playbook playbooks/system-preparation.yml --vault-password-file .vault_pass
```

**✅ Team Collaboration:**
- Share encrypted secrets via git
- Multiple developers access same infrastructure

## 🔧 Configuration Examples

### Default Single Node Setup

**inventory/hosts.yml:**
```yaml
all:
  children:
    single_node:
      hosts:
        standalone:
          ansible_host: 10.1.0.100    # Your server IP
          node_type: single
          traefik_enabled: true

  vars:
    ansible_user: ubuntu              # Works for AWS, DigitalOcean, Linode
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    ansible_become: true              # Use sudo for root privileges
```

**group_vars/vault.yml:**
```yaml
vault_tailscale_auth_key: "tskey-auth-xxxxx"      # From Tailscale admin console
vault_cloudflare_email: "you@domain.com"          # Your Cloudflare email
vault_cloudflare_dns_token: "xxxxx"               # Cloudflare DNS API token
vault_restic_password: "secure-backup-password"   # For encrypted backups
vault_production_admin_ssh_key: "ssh-rsa AAAAB3..." # Your SSH public key
```

### Advanced Multi-Node Cluster

**When scaling beyond single node:**

**inventory/hosts.yml:**
```yaml
all:
  children:
    production:
      children:
        swarm_managers:
          hosts:
            manager1:
              ansible_host: 10.1.0.100
              node_type: manager
              traefik_enabled: true    # Only one node gets public access
        swarm_workers:
          hosts:
            worker1:
              ansible_host: 10.1.0.101
              node_type: worker
              traefik_enabled: false   # Workers are internal only
            worker2:
              ansible_host: 10.1.0.102
              node_type: worker
              traefik_enabled: false
```

## 🔄 Deployment Process

The deployment follows a **two-phase approach**: **System Preparation** followed by **Docker Infrastructure**.

### 🎯 Default Single Node Deployment (Recommended)

**Complete Infrastructure in 2 Commands:**
```bash
# Step 1: System preparation (hardening, admin user, Tailscale, firewall)
ansible-playbook -i inventory/hosts.yml playbooks/system-preparation.yml

# Step 2: Docker infrastructure (Docker Swarm, networks, services)
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml
```

### 🏗️ Advanced Multi-Node Cluster

**When you need high availability or scaling:**
```bash
# Step 1: System preparation on all nodes
ansible-playbook -i inventory/hosts.yml playbooks/multi-node.yml

# Step 2: Docker Swarm cluster setup
ansible-playbook -i inventory/hosts.yml playbooks/multi-node-docker.yml
```

---

### 📋 Playbook Reference Guide

#### **System Preparation Playbooks** (Run First)

| Playbook | Purpose | Target Hosts | What It Includes |
|----------|---------|--------------|------------------|
| `system-preparation.yml` | **General system prep** | `all` | System updates, admin user, Tailscale, firewall, SSH hardening |
| `single-node.yml` | **Single-node optimized prep** | `single_node` | Same as system-preparation.yml + single-node specific configs |
| `multi-node.yml` | **Multi-node optimized prep** | `production` | Same as system-preparation.yml + cluster-specific configs |

**Commands:**
```bash
# General system preparation
ansible-playbook -i inventory/hosts.yml playbooks/system-preparation.yml

# Single-node optimized
ansible-playbook -i inventory/hosts.yml playbooks/single-node.yml

# Multi-node optimized  
ansible-playbook -i inventory/hosts.yml playbooks/multi-node.yml
```

#### **Docker Infrastructure Playbooks** (Run Second)

| Playbook | Purpose | Target Hosts | Prerequisites |
|----------|---------|--------------|---------------|
| `docker-setup.yml` | **General Docker setup** | `all` | System prep completed |
| `single-node-docker.yml` | **Single-node Docker** | `single_node` | System prep completed |
| `multi-node-docker.yml` | **Multi-node Docker cluster** | `production` | System prep completed |

**Commands:**
```bash
# General Docker installation
ansible-playbook -i inventory/hosts.yml playbooks/docker-setup.yml

# Single-node Docker (with Traefik)
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml

# Multi-node Docker cluster
ansible-playbook -i inventory/hosts.yml playbooks/multi-node-docker.yml
```

---

### 🔧 Individual Phase Commands (Docker Only)

**Phase 1: Docker Installation**
```bash
# Docker CE installation and configuration
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml --tags "docker_installation,docker_configuration"
```

**Phase 2: Cluster Setup**
```bash
# Docker Swarm and encrypted networks
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml --tags "docker_swarm,docker_networks"
```

**Phase 3: Production Configuration**
```bash
# Production settings, Whalewall security, services
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml --tags "docker_production,whalewall,docker_services"
```

**Phase 4: Backup & Monitoring**
```bash
# Restic backup automation
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml --tags "restic_backup"
```

**Phase 5: Validation**
```bash
# Complete system verification
ansible-playbook -i inventory/hosts.yml playbooks/single-node-docker.yml --tags "docker_validation"
```

---

### 📈 Cluster Scaling Commands

**Add Worker Nodes:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/scale-add-workers.yml
```

**Add Manager Nodes:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/scale-add-managers.yml
```

**Node Maintenance:**
```bash
# Drain node for maintenance
ansible-playbook -i inventory/hosts.yml playbooks/node-maintenance.yml -e maintenance_action=drain -e target_node=worker1

# Activate node after maintenance
ansible-playbook -i inventory/hosts.yml playbooks/node-maintenance.yml -e maintenance_action=active -e target_node=worker1
```

---

### 🚨 Disaster Recovery Commands

**Complete System Recovery:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/disaster-recovery.yml -e local_restic_repository=/path/to/local-backup-sync/data/local-repository
```

**Point-in-Time Recovery:**
```bash
# Auto-detect backup source (recommended)
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml -e local_restic_repository=/path/to/local-backup-sync/data/local-repository -e recovery_timestamp="2024-01-15T10:30:00"

# Force local backup only
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml -e local_restic_repository=/path/to/local-backup-sync/data/local-repository -e recovery_timestamp="2024-01-15T10:30:00" -e recovery_source="local"

# Service-specific recovery
ansible-playbook -i inventory/hosts.yml playbooks/point-in-time-recovery.yml -e local_restic_repository=/path/to/local-backup-sync/data/local-repository -e recovery_timestamp="2024-01-15T10:30:00" -e recovery_service="traefik"
```


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
   - Files are automatically gitignored for security

3. **Deploy Without Encryption (Default):**
   ```bash
   # Ready to use - no encryption needed for local development
   ansible-playbook -i inventory/hosts.yml playbooks/system-preparation.yml
   ```

### When to Use Vault Encryption

**Encryption is optional for most users** since vault files are properly gitignored. Consider encryption only when:

#### **✅ CI/CD Pipelines & GitHub Actions**
```bash
# Encrypt vault to safely commit to git for automated deployments
ansible-vault encrypt group_vars/vault.yml
git add group_vars/vault.yml  # Now safe to commit encrypted file
git commit -m "Add encrypted infrastructure secrets"

# In GitHub Actions
- name: Deploy Infrastructure
  run: ansible-playbook -i inventory/hosts.yml playbooks/system-preparation.yml --vault-password-file <(echo "$VAULT_PASS")
  env:
    VAULT_PASS: ${{ secrets.ANSIBLE_VAULT_PASS }}
```


**Use Vault in Deployments (when encrypted):**
```bash
ansible-playbook playbook.yml --ask-vault-pass
# or
ansible-playbook playbook.yml --vault-password-file .vault_pass
```

## 📁 Project Structure

```
├── inventory/
│   └── hosts.yml                 # Ansible inventory configuration
├── group_vars/
│   ├── all.yml                   # Global variables
│   └── docker.yml               # Docker-specific configuration
├── playbooks/
│   # System Preparation Playbooks
│   ├── system-preparation.yml    # General system preparation (all hosts)
│   ├── single-node.yml           # Single-node system preparation
│   ├── multi-node.yml            # Multi-node system preparation
│   # Docker Infrastructure Playbooks  
│   ├── docker-setup.yml          # General Docker setup playbook
│   ├── single-node-docker.yml    # Single node Docker setup (Docker only)
│   ├── multi-node-docker.yml     # Multi-node Docker setup (Docker only)
│   # Cluster Scaling Playbooks
│   ├── scale-add-workers.yml     # Add worker nodes to existing cluster
│   ├── scale-add-managers.yml    # Add manager nodes for HA
│   ├── node-maintenance.yml      # Node maintenance operations
│   # Disaster Recovery Playbooks
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

### System Preparation Playbooks
- **playbooks/system-preparation.yml**: General system preparation (system hardening, admin user, Tailscale, firewall, SSH hardening)
- **playbooks/single-node.yml**: Single-node optimized system preparation with Traefik configuration
- **playbooks/multi-node.yml**: Multi-node optimized system preparation with cluster-specific settings

### Docker Infrastructure Playbooks  
- **playbooks/docker-setup.yml**: General Docker installation and configuration (requires system prep)
- **playbooks/single-node-docker.yml**: Single-node Docker Swarm setup (Docker components only)
- **playbooks/multi-node-docker.yml**: Multi-node Docker Swarm cluster setup (Docker components only)

### Cluster Scaling Playbooks
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

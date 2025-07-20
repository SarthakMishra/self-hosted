# CrowdSec Security Engine Role

This Ansible role installs and configures CrowdSec, a modern collaborative security engine that provides real-time protection against attacks through community-powered threat intelligence.

## Features

- 🛡️ **Comprehensive Protection**: SSH brute force, HTTP attacks, CVE exploitation prevention
- 🌐 **Community Intelligence**: Real-time threat data from global CrowdSec network
- 🔥 **UFW Integration**: Seamless firewall integration with Docker protection
- 📊 **Multi-source Monitoring**: System logs, auth logs, UFW, Docker, web servers
- 🚀 **Production Ready**: Automatic configuration and security collections
- ⚙️ **Highly Configurable**: Extensible log sources and custom scenarios

## What Gets Installed

### Core Components
- **CrowdSec Engine**: Main security analysis engine
- **Firewall Bouncer**: iptables/UFW integration for network-level blocking
- **Security Collections**: Pre-configured detection scenarios

### Security Collections
- `crowdsecurity/linux` - System-level protection
- `crowdsecurity/sshd` - SSH brute force protection  
- `crowdsecurity/http-cve` - HTTP vulnerability protection
- `crowdsecurity/traefik` - Traefik-specific monitoring
- `crowdsecurity/iptables` - Network-level attack detection

### Log Sources Monitored
- System logs (`/var/log/syslog`, `/var/log/kern.log`)
- SSH authentication (`/var/log/auth.log`)
- UFW firewall logs (`/var/log/ufw.log`)
- Docker container logs (via journald)
- Web server logs (nginx/apache)

## Configuration

### Basic Configuration (`group_vars/crowdsec.yml`)

```yaml
# Enable/disable CrowdSec installation
crowdsec_enabled: true

# Additional security collections
crowdsec_additional_collections:
  - crowdsecurity/nginx
  - crowdsecurity/apache2

# Custom log sources
crowdsec_additional_log_sources:
  - description: "Application logs"
    type: "file"
    filenames:
      - "/var/log/myapp/*.log"
    parser_type: "syslog"

# Performance tuning
crowdsec_bouncer_log_level: "info"
crowdsec_monitoring_enabled: false
```

### Advanced Configuration

```yaml
# Custom IP whitelist
crowdsec_custom_whitelist_ips:
  - "192.168.1.0/24"    # Local network
  - "10.0.0.0/8"        # Private network

# Database configuration (default: SQLite)
crowdsec_database_type: "mysql"
crowdsec_database_config:
  host: "localhost"
  user: "crowdsec"
  password: "password"
  database: "crowdsec"

# Notifications
crowdsec_notifications_enabled: true
crowdsec_notification_webhook: "https://hooks.slack.com/..."
```

## Integration with Infrastructure

### UFW/Docker Integration
- Automatically configures `DOCKER-USER` chain for container protection
- Integrates with UFW rules without conflicts
- Protects both host and containerized applications

### Traefik Integration
- Monitors Traefik access logs for web attacks
- Protects against HTTP-based exploits
- Compatible with reverse proxy setups

### Monitoring Integration
- Optional Prometheus metrics export
- Status monitoring commands
- Integration with existing log rotation

## Management Commands

```bash
# Check security status
sudo cscli collections list        # Installed collections
sudo cscli bouncers list          # Active bouncers
sudo cscli decisions list         # Currently blocked IPs
sudo cscli alerts list            # Recent security alerts

# View metrics
sudo cscli metrics               # Performance metrics
sudo ipset list crowdsec-blacklists-0  # Blocked IP list

# Manual management
sudo cscli decisions add --ip 1.2.3.4  # Block specific IP
sudo cscli decisions delete --ip 1.2.3.4  # Unblock IP
```

## File Locations

```
/etc/crowdsec/
├── config.yaml                    # Main configuration
├── acquis.yaml                    # Log acquisition rules
└── bouncers/
    └── crowdsec-firewall-bouncer.yaml  # Bouncer configuration

/var/log/
├── crowdsec.log                   # Engine logs
└── crowdsec-firewall-bouncer.log  # Bouncer logs
```

## Security Features

### Network Protection
- **Layer 3/4 Blocking**: iptables-based IP blocking
- **Docker Integration**: Protects containerized services
- **UFW Compatibility**: Works with existing UFW rules

### Attack Detection
- **Brute Force**: SSH, HTTP authentication attempts
- **CVE Exploitation**: Known vulnerability patterns
- **Scanning**: Port scans, vulnerability scanners
- **Web Attacks**: SQL injection, XSS, path traversal

### Community Intelligence
- **Global Blocklist**: 14K+ IPs from community reports
- **Real-time Updates**: Automatic threat intelligence updates
- **Collaborative Defense**: Share attack data (opt-in)

## Dependencies

- Ubuntu 20.04+ (automatically handled)
- UFW firewall (configured by firewall role)
- iptables (system package)

## Tags

Use these tags to run specific parts of the role:

```bash
# Install only
ansible-playbook -t crowdsec,installation

# Configuration only  
ansible-playbook -t crowdsec,configuration

# Collections management
ansible-playbook -t crowdsec,collections

# Status and validation
ansible-playbook -t crowdsec,validation
```

## Role Variables

See `defaults/main.yml` for complete variable reference.

Key variables:
- `crowdsec_enabled`: Enable/disable installation
- `crowdsec_collections`: Security collections to install
- `crowdsec_log_sources`: Log sources to monitor
- `crowdsec_additional_*`: Extend default configurations

## Example Usage

```yaml
# In your playbook
- name: Install CrowdSec security engine
  include_role:
    name: crowdsec
  vars:
    crowdsec_additional_collections:
      - crowdsecurity/nginx
    crowdsec_monitoring_enabled: true
```

## Troubleshooting

### Service Issues
```bash
sudo systemctl status crowdsec
sudo systemctl status crowdsec-firewall-bouncer
sudo journalctl -u crowdsec -f
```

### Configuration Issues
```bash
sudo cscli config show
sudo cscli parsers list
sudo cscli scenarios list
```

### Network Issues
```bash
sudo iptables -L | grep -i crowdsec
sudo ipset list
```

## License

MIT License - See project root LICENSE file. 
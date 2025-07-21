# Service Deployment Guide

Complete guide for deploying services on your home server with nginx-proxy, dnsmasq, and Cloudflare tunnel integration.

> **Prerequisites**: Server deployed with: `ansible-playbook -i inventory/hosts.yml playbooks/setup.yml`

## 🏗️ Home Server Architecture

Your server provides **dual access patterns**:

- **Local Access**: `service.home` domains via nginx-proxy + dnsmasq
- **External Access**: `service.yourdomain.com` via Cloudflare tunnel (optional)
- **Remote Management**: Tailscale VPN for secure administration

## 🌐 Network Configuration

### Automatic DNS Resolution (Tailscale MagicDNS)

After setting up Tailscale MagicDNS in the admin console:

```bash
# Test DNS resolution from any Tailscale device
nslookup sonarr.home
# Should resolve to your server IP

# Access services directly
curl http://sonarr.home
curl http://plex.home
```

### Manual DNS Configuration

If not using Tailscale MagicDNS:

```bash
# Set DNS on your devices to your server IP
# Then access services via .home domains
```

## 📦 Service Deployment Patterns

### Standard Service Template

```yaml
---
services:
  myapp:
    image: myapp:latest
    container_name: myapp
    environment:
      - TZ=UTC
      - VIRTUAL_HOST=myapp.home
      - VIRTUAL_PORT=3000
    volumes:
      - ${BASE_CONFIG_PATH}/myapp-config:/config
      - ${BASE_DATA_PATH}/myapp:/data
    restart: unless-stopped
    networks:
      - home-network
    labels:
      # Optional: External access via Cloudflare tunnel
      - "cloudflare.zero_trust.access.tunnel.public_hostname=myapp.yourdomain.com"
      - "cloudflare.zero_trust.access.tunnel.service=http://myapp:3000"

networks:
  home-network:
    external: true
```

### Environment Configuration

```bash
# Required in .env file
BASE_CONFIG_PATH=/opt/docker/config
BASE_DATA_PATH=/opt/docker/data
TZ=UTC

# Access Methods:
# - Local: http://myapp.home
# - External: https://myapp.yourdomain.com (if configured)
# - Direct: http://server-tailscale-ip:port (troubleshooting)
```

## 🛠️ Available Service Templates

### 📺 Media Stack (arr-stack)

```bash
# Deploy complete media automation stack
cd service-templates/home/arr-stack/
cp env.example .env
nano .env  # Configure your settings

docker compose up -d
```

**Services provided:**
- `sonarr.home` - TV show management
- `radarr.home` - Movie management  
- `bazarr.home` - Subtitle management
- `prowlarr.home` - Indexer management (VPN protected)
- `qbittorrent.home` - Torrent client (VPN protected)
- `jellyseerr.home` - Media requests
- `plex.home` - Media server
- `flaresolverr.home` - Cloudflare solver

### 📷 Security System (frigate)

```bash
# Deploy AI-powered security system
cd service-templates/home/frigate/
cp env.example .env
nano .env  # Configure camera credentials

docker compose up -d
```

**Services provided:**
- `frigate.home` - AI security monitoring

### 📸 Photo Management (immich)

```bash
# Deploy photo management system
cd service-templates/home/immich/
cp env.example .env
nano .env  # Configure database password

docker compose up -d
```

**Services provided:**
- `immich.home` - Photo backup and management

## 🔐 VPN-Protected Services

Some services (prowlarr, qbittorrent) use VPN protection via Gluetun:

### VPN Configuration

```bash
# In your .env file, configure WireGuard:
VPN_PRIVATE_KEY=your-private-key-here
VPN_ADDRESS=10.10.227.121
VPN_DNS=10.0.0.243
VPN_PUBLIC_KEY=your-public-key-here
VPN_ALLOWED_IPS=0.0.0.0/0
VPN_ENDPOINT=your-vpn-endpoint:port
VPN_KEEPALIVE=25
```

### VPN Service Management

```bash
# Check VPN status
docker compose logs gluetun

# Test VPN connectivity
docker compose exec gluetun curl ifconfig.me

# Restart VPN if needed
docker compose restart gluetun
```

## 🚀 Deployment Commands

### Remote Deployment via Tailscale

```bash
# Connect via Tailscale and deploy
ssh admin@server-tailscale-ip

# Navigate to service directory
cd /opt/docker/services/myapp/

# Deploy or update
docker compose pull
docker compose up -d

# Check status
docker compose ps
docker compose logs -f
```

### Using Docker Context

```bash
# Create remote context
docker context create homeserver --docker "host=ssh://admin@server-tailscale-ip"
docker context use homeserver

# Deploy from local machine
docker compose -f service-templates/home/arr-stack/docker-compose.yml up -d

# Switch back to local
docker context use default
```

## 🔧 Service Management

### Common Operations

```bash
# View all services
docker ps

# Check service logs
docker compose logs service-name --tail=50

# Update services
docker compose pull && docker compose up -d

# Restart specific service
docker compose restart service-name

# Stop services
docker compose down
```

### Health Monitoring

```bash
# Check service health
curl http://sonarr.home/api/v3/system/status

# View resource usage
docker stats

# Check nginx-proxy routing
curl -H "Host: myapp.home" http://localhost
```

### Volume Management

```bash
# List volumes
docker volume ls

# Backup volume
docker run --rm -v myapp_data:/data -v $(pwd):/backup alpine tar czf /backup/myapp_backup.tar.gz /data

# Restore volume
docker run --rm -v myapp_data:/data -v $(pwd):/backup alpine tar xzf /backup/myapp_backup.tar.gz -C /
```

## 🌍 External Access Configuration

### Cloudflare Tunnel (Optional)

To expose services externally, add labels to your services:

```yaml
labels:
  - "cloudflare.zero_trust.access.tunnel.public_hostname=myapp.yourdomain.com"
  - "cloudflare.zero_trust.access.tunnel.service=http://myapp:3000"
```

The cloudflare-manager service automatically detects these labels and configures the tunnel.

### Security Considerations

- **Internal Only**: By default, all services are internal-only
- **VPN Protection**: Sensitive services (torrenting) use VPN
- **No Open Ports**: No ports 80/443 exposed externally
- **Tailscale Access**: Secure remote management via Tailscale

## 📁 File Organization

```
/opt/docker/
├── nginx-proxy/          # Reverse proxy (managed by Ansible)
├── dnsmasq/              # Local DNS (managed by Ansible)  
├── cloudflared/          # External tunnel (managed by Ansible)
├── config/               # Service configurations
│   ├── sonarr-config/
│   ├── radarr-config/
│   └── ...
├── data/                 # Service data
│   ├── media/
│   ├── downloads/
│   └── ...
└── services/             # Your deployed services
    ├── arr-stack/
    ├── frigate/
    └── immich/
```

## 🔍 Troubleshooting

### DNS Resolution Issues

```bash
# Test DNS resolution
nslookup myapp.home server-ip

# Check dnsmasq logs
docker compose -f /opt/docker/dnsmasq/docker-compose.yml logs

# Test nginx-proxy routing
curl -H "Host: myapp.home" http://server-ip
```

### Service Access Issues

```bash
# Check service is running
docker compose ps

# Verify VIRTUAL_HOST configuration
docker inspect container-name | grep VIRTUAL_HOST

# Check nginx-proxy configuration
docker compose -f /opt/docker/nginx-proxy/docker-compose.yml logs
```

### Network Issues

```bash
# Verify home-network exists
docker network ls | grep home-network

# Check container network connectivity
docker compose exec service-name ping nginx-proxy
```

### VPN Issues

```bash
# Check VPN connection
docker compose exec gluetun curl ifconfig.me

# View VPN logs
docker compose logs gluetun

# Test container connectivity through VPN
docker compose exec prowlarr curl ifconfig.me
```

## 📋 Best Practices

### Service Deployment
- Always use the `home-network` for service connectivity
- Set `VIRTUAL_HOST=service.home` for nginx-proxy routing
- Use environment variables for configuration
- Follow the established file structure in `/opt/docker/`

### Security
- Keep VPN-protected services behind Gluetun
- Use strong passwords for service databases
- Regularly update service images
- Monitor service logs for unusual activity

### Maintenance
- Use `docker compose pull && docker compose up -d` for updates
- Backup important volumes regularly
- Monitor disk space in `/opt/docker/`
- Test services after updates

### Access Patterns
- **Development/Testing**: Direct IP access (`http://server-ip:port`)
- **Daily Use**: Domain access (`http://service.home`)
- **External Access**: Only when necessary via Cloudflare tunnel
- **Management**: Always via Tailscale VPN

## 🚀 Quick Reference

```bash
# Deploy new service
cd /opt/docker/services/
mkdir myapp && cd myapp
# Create docker-compose.yml with home-network and VIRTUAL_HOST
docker compose up -d

# Update all services
find /opt/docker/services -name "docker-compose.yml" -execdir docker compose pull \;
find /opt/docker/services -name "docker-compose.yml" -execdir docker compose up -d \;

# Check system status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Access services
# Local: http://service.home
# External: https://service.yourdomain.com (if configured)
# Management: ssh admin@server-tailscale-ip
```

Your home server provides a complete self-hosted infrastructure with secure access patterns and automated service discovery! 🎉 
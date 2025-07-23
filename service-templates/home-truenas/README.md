# Home Lab HTTPS Stack - Step CA + nginx-proxy

> **🔐 Complete private certificate authority with automated reverse proxy**

Internal reference for deploying Step CA + nginx-proxy with automatic HTTPS certificates, AdGuard integration, and Tailscale split DNS support.

## Overview

This template provides:
- **Step CA**: Private ACME certificate authority for `.home` domains
- **nginx-proxy**: Automatic reverse proxy with service discovery
- **Automatic HTTPS**: Zero-configuration SSL certificates for all services
- **AdGuard Integration**: Works seamlessly with AdGuard DNS on same Docker network (requires AdGuard deployment)
- **Tailscale Split DNS**: Optional local/remote access using same domains
- **Optimized Docker Networking**: Internal communication uses container names without certificate verification

## Configuration

### Step CA (.env in step-ca/)

```bash
# Step CA Identity
STEP_CA_NAME=Home Server CA
STEP_CA_PROVISIONER_NAME=admin@homeserver.local

# Network Configuration
STEP_CA_DNS_NAMES=ca.home,step-ca,localhost,192.168.1.100
HOME_SERVER_IP=192.168.1.100

# Certificate Configuration  
DEFAULT_CERT_DURATION=720h  # 30 days
MAX_CERT_DURATION=8760h     # 1 year

# ACME Configuration
ACME_PROVISIONER_NAME=acme
ACME_EMAIL=admin@homeserver.local
```

**Important:** Create `secrets/ca_password.txt` with a secure password before deployment.

### nginx-proxy (.env in nginx-proxy/)

```bash
# Network Configuration
HOME_SERVER_IP=192.168.1.100
DOMAIN_SUFFIX=home
DEFAULT_HOST=home

# AdGuard DNS
ADGUARD_HOST=adguardhome
ADGUARD_WEB_PORT=80

# HTTPS Configuration
HTTPS_METHOD=redirect
SSL_POLICY=Mozilla-Intermediate
STEP_CA_URL=https://step-ca:9000  # Uses container name for internal Docker communication
ACME_EMAIL=admin@homeserver.local

# Auto-certificate domains (same as step-ca)
AUTO_CERT_DOMAINS=proxy.home portainer.home netdata.home ca.home sonarr.home radarr.home plex.home immich.home frigate.home
```

## Prerequisites

**Required Services:**
- AdGuard Home container running on `home-network` (deploy from `service-templates/home/adguard/` if needed)
- Docker context configured for TrueNAS server

## Step-by-Step Deployment

### 1. AdGuard DNS Setup

**AdGuard Admin → Filters → DNS rewrites:**

```
# A Record for nginx-proxy
proxy.home → 192.168.1.100

# Wildcard A Record for all services (or individual A records)
*.home → 192.168.1.100
```

**Router DHCP:** Set primary DNS to your home server IP (192.168.1.100) where AdGuard is running

**AdGuard Initial Setup:**
1. Access `https://adguard.home` after deployment
2. Complete initial setup wizard
3. Configure DNS rewrites as shown above
4. Set upstream DNS servers (1.1.1.1, 8.8.8.8, etc.)

### 2. Configure Step CA Secrets

```bash
# Create CA password file (required for initialization)
cd service-templates/home-truenas/step-ca/secrets
cp ca_password.txt.example ca_password.txt

# Edit password file with your secure password
nano ca_password.txt
# Replace 'your-secure-ca-password-here' with a strong password
```

### 3. Deploy Step CA

```bash
# Set docker context to TrueNAS server
docker context use truenas

# Deploy Step CA first
cd service-templates/home-truenas/step-ca
docker compose up -d step-ca

# Check initialization logs
docker compose logs -f step-ca

# Wait for Step CA to initialize (creates certificates)
```

### 4. Request Initial Certificates

```bash
# Stop nginx-proxy if running (frees port 80 for ACME challenge)
cd ../nginx-proxy
docker compose stop nginx-proxy 2>/dev/null || true

# Request certificates for all configured domains
cd ../step-ca
docker compose run --rm step-ca-acme-manager

# Or use nginx-proxy cert manager
cd ../nginx-proxy
docker compose run --rm cert-manager
```

### 5. Deploy nginx-proxy

```bash
# Start nginx-proxy with certificates
cd service-templates/home-truenas/nginx-proxy
docker compose up -d

# Verify both services are running
docker compose ps
cd ../step-ca && docker compose ps
```

### 6. Deploy AdGuard Home (if not already running)

```bash
# Check if AdGuard Home is already running
docker ps | grep adguard

# If not running, deploy AdGuard Home on same network
cd service-templates/home/adguard
docker compose up -d

# Wait for AdGuard to start
docker compose logs -f adguardhome

# Verify AdGuard is on home-network and accessible
docker network inspect home-network | grep adguardhome
curl -f http://adguardhome:3000  # Initial setup port
curl -f http://localhost:3080    # Direct dashboard access (host port 3080)
```

**Note:** After deployment, access `https://adguard.home` to complete initial setup wizard and configure DNS rewrites as described in step 1.

### 7. Verify HTTPS Access

```bash
# Test Step CA
curl -k https://ca.home:9000/health

# Test nginx-proxy
curl -k https://proxy.home

# Test AdGuard Home via nginx-proxy
curl -k https://adguard.home

# Test service discovery (if services configured)
curl -k https://portainer.home
```

## Certificate Management

### Automatic Renewal Setup

```bash
# Set up cron job for renewal
crontab -e

# Add renewal job (every 12 hours)
0 */12 * * * docker --context truenas compose -f /opt/docker/services/home-truenas/nginx-proxy/docker-compose.yml run --rm cert-renewer
```

### Manual Certificate Operations

```bash
# Request new certificates
cd service-templates/home-truenas/nginx-proxy
docker compose run --rm cert-manager

# Renew existing certificates
docker compose run --rm cert-renewer

# Check certificate status
docker compose run --rm cert-renewer portainer.home
```

## Service Configuration

### Adding New Services

Configure any service for automatic HTTPS:

```yaml
services:
  myservice:
    environment:
      - VIRTUAL_HOST=myservice.home
      - VIRTUAL_PORT=3000              # If non-80
    networks:
      - home-network
```

### Common Examples

```yaml
# AdGuard Home
- VIRTUAL_HOST=adguard.home
- VIRTUAL_PORT=80

# Portainer
- VIRTUAL_HOST=portainer.home
- VIRTUAL_PORT=9000

# Plex (HTTPS backend)
- VIRTUAL_HOST=plex.home
- VIRTUAL_PORT=32400
- VIRTUAL_PROTO=https

# Sonarr/Radarr
- VIRTUAL_HOST=sonarr.home
- VIRTUAL_PORT=8989
```

## Split DNS for Tailscale (Optional)

### AdGuard Configuration

```bash
# AdGuard Admin → DNS Settings → DNS rewrites
# Configure conditional responses based on client groups or access settings
# Or add multiple A records for same domain with different IPs

# Local network access
proxy.home → 192.168.1.100

# Alternative: Configure AdGuard access settings for Tailscale subnet
# to return different IP ranges for different client networks
```

### Tailscale Admin Console

- **DNS → Add nameserver**
- **Nameserver:** AdGuard container IP (from home-network) or external IP
- **Domain:** `home`

**Result:** AdGuard returns appropriate IP based on client configuration or access rules.

## Device Trust Setup

### Get Root CA Certificate

```bash
# Download root certificate from Step CA
curl -k https://ca.home/roots.pem -o root_ca.crt

# Or extract from Docker volume
docker run --rm -v step-ca-data:/data alpine cat /data/certs/root_ca.crt > root_ca.crt
```

Install Step CA root certificate on client devices:

### Windows
```powershell
# Download from https://ca.home/roots.pem and import
Import-Certificate -FilePath "root_ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

### Ubuntu/macOS
```bash
# Ubuntu
sudo cp root_ca.crt /usr/local/share/ca-certificates/step-ca-root.crt
sudo update-ca-certificates

# macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain root_ca.crt
```

### Mobile
- **iOS**: Email cert → Install → Settings → General → About → Certificate Trust Settings
- **Android**: Settings → Security → Install CA certificate

## Troubleshooting

### DNS Resolution
```bash
# Test local resolution
nslookup service.home

# Test via AdGuard directly (use container IP or external IP)
nslookup service.home adguardhome

# Test via Tailscale (if configured)
nslookup service.home 100.100.100.100
```

### Step CA Issues
```bash
# Check Step CA health (internal Docker network)
curl -k https://step-ca:9000/health

# Check Step CA health (external via nginx-proxy)
curl -k https://ca.home:9000/health

# View ACME directory
curl -k https://step-ca:9000/acme/acme/directory

# Step CA logs
cd service-templates/home-truenas/step-ca
docker compose logs step-ca
```

### nginx-proxy Issues
```bash
# Check nginx-proxy routing
cd service-templates/home-truenas/nginx-proxy
docker compose exec nginx-proxy cat /etc/nginx/conf.d/default.conf | grep service.home

# Main services logs
docker compose logs nginx-proxy
docker compose logs nginx-proxy-gen

# Certificate services logs
docker compose logs cert-manager
docker compose logs cert-renewer
```

### Certificate Issues
```bash
# Check certificate files
ls -la /opt/docker/config/nginx-proxy-certs/live/

# Test specific domain
openssl s_client -connect service.home:443 -servername service.home

# Manual certificate request
cd service-templates/home-truenas/nginx-proxy
docker compose run --rm cert-manager
```

## Key Endpoints

- **Step CA Web**: `https://ca.home`
- **nginx-proxy**: `https://proxy.home`
- **AdGuard Home**: `https://adguard.home` (via nginx-proxy)
- **ACME Directory**: `https://ca.home:9000/acme/acme/directory`
- **Health Check**: `https://ca.home:9000/health`

## Security Features

- **Private Certificate Authority (Step CA)**
- **Automatic HTTPS with valid certificates**
- **Security headers:** `X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection`
- **Modern TLS:** TLS 1.2/1.3 with secure cipher suites
- **Local network access only** (no public exposure)
- **Certificate renewal automation**
- **Docker context deployment ready**

All `.home` services automatically receive valid SSL certificates with proper security headers and HTTP/2 support. 
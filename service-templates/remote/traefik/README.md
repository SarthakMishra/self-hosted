# Traefik Production Setup with Cloudflare and CrowdSec

Production-ready Traefik reverse proxy with automatic SSL certificates via Cloudflare DNS-01 challenge and CrowdSec security integration.

> [!NOTE]
> Using Dockerfiles because there was an issue with mounting local files when using docker context for remote server

## Features

- **Automatic SSL**: Let's Encrypt with Cloudflare DNS-01 challenge
- **Cloudflare IP Whitelisting**: UFW configured to only allow Cloudflare proxy IPs
- **Security Integration**: CrowdSec for real-time threat detection via Traefik plugin
- **Production Hardened**: Dashboard disabled, security headers, resource limits
- **Dynamic IP Updates**: Script to automatically fetch latest Cloudflare IP ranges

## Prerequisites

1. **Domain with Cloudflare**: Domain managed by Cloudflare with proxy enabled
2. **Cloudflare API Key**: Global API key with DNS edit permissions
3. **Docker & Docker Compose**: Installed on production server
4. **External Network**: `app-network` must exist

## Quick Setup

### 1. Create External Network
```bash
docker network create app-network
```

### 2. Configure Environment
```bash
cp env.example .env
nano .env
```

### 3. Generate CrowdSec API Key
```bash
openssl rand -hex 32
```

### 4. Configure Cloudflare DNS
1. Add A record: `yourdomain.com` → `YOUR_SERVER_IP`
2. Add CNAME record: `*.yourdomain.com` → `yourdomain.com`
3. Enable Cloudflare proxy (orange cloud)
4. Set SSL/TLS mode to "Full (strict)"

### 5. Deploy
```bash
docker-compose up -d
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `CLOUDFLARE_EMAIL` | Your Cloudflare account email | Yes |
| `CLOUDFLARE_API_KEY` | Cloudflare Global API Key | Yes |
| `LETSENCRYPT_EMAIL` | Email for certificate notifications | Yes |
| `CROWDSEC_API_KEY` | API key for Traefik plugin integration | Yes |

### Service Integration Labels

For other services, add these labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.servicename.rule=Host(`service.yourdomain.com`)"
  - "traefik.http.routers.servicename.entrypoints=websecure"
  - "traefik.http.routers.servicename.tls.certresolver=letsencrypt"
  - "traefik.http.services.servicename.loadbalancer.server.port=PORT"
  - "traefik.http.routers.servicename.middlewares=security-headers@file,crowdsec@file,crowdsec@file"
```

**Note**: The `crowdsec@file` middleware provides real-time threat protection. All services using this middleware will be protected by CrowdSec's threat detection.

## API Key Authentication Middleware

### Overview

The API key authentication middleware (`traefik-api-key-auth`) allows you to protect specific routes or services with an API key. Requests must provide a valid API key via header, bearer token, query parameter, or path segment, or they will receive a 403 Forbidden response.

This is useful for protecting internal APIs, admin endpoints, or any service that should require a secret key for access.

### Configuration

The middleware is defined in `middlewares.example.yml` and can be enabled for any service by adding the appropriate label. You can customize accepted keys and which methods are allowed (header, bearer, query param, path segment).

#### Example middleware definition (see `middlewares.example.yml`):

```yaml
api-key-auth:
  plugin:
    traefik-api-key-auth:
      enabled: true
      authenticationHeaderEnabled: true
      authenticationHeaderName: "X-API-KEY"
      bearerHeader: true
      bearerHeaderName: "Authorization"
      queryParam: true
      queryParamName: "token"
      keys:
        - "your-very-secret-api-key"
```

#### Example service labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapi.rule=Host(`api.yourdomain.com`)"
  - "traefik.http.routers.myapi.entrypoints=websecure"
  - "traefik.http.routers.myapi.tls.certresolver=letsencrypt"
  - "traefik.http.services.myapi.loadbalancer.server.port=8080"
  - "traefik.http.routers.myapi.middlewares=security-headers@file,crowdsec@file,api-key-auth@file"
```

**Security Note:**
- Use strong, unique API keys and rotate them regularly.
- Do not expose sensitive endpoints without authentication.
- This middleware can be combined with CrowdSec and security headers for layered protection.

## UFW Management

### Automatic Cloudflare IP Whitelisting

Use the included `ufw-manager.sh` script to configure UFW for Cloudflare-only access:

```bash
# Copy and run the script
scp ufw-manager.sh user@xx.xx.xx.xx:/opt/myscripts/
ssh user@xx.xx.xx.xx "sudo bash /opt/myscripts/ufw-manager.sh"
```

**What the script does:**
- Fetches latest Cloudflare IP ranges dynamically
- Resets UFW to default state
- Configures basic security (SSH, Tailscale allowed)
- Adds Cloudflare IP ranges for ports 80/443
- Adds ufw route rules for Docker container access
- Verifies ufw-docker integration

### Manual UFW Commands

```bash
# Check UFW status
sudo ufw status numbered

# Check Docker route rules
sudo iptables -L ufw-user-forward -n -v

# Update Cloudflare IPs manually
sudo ufw route delete allow proto tcp from any to any port 80
sudo ufw route delete allow proto tcp from any to any port 443
# Then add new ranges as needed
```

## Security Features

### Cloudflare IP Whitelisting
- **UFW Protection**: Only Cloudflare proxy IPs can reach your server
- **Dynamic Updates**: Script fetches latest IP ranges automatically
- **DDoS Protection**: Cloudflare handles attacks before they reach your server
- **IP Hiding**: Server's real IP is hidden from the internet

### CrowdSec Integration
- **Real-time Protection**: Monitors logs and blocks malicious IPs
- **Plugin Architecture**: Native Traefik plugin for maximum efficiency
- **Stream Mode**: Optimized performance with 60-second cache updates
- **Community Intelligence**: Shares threat data with global community

### Security Headers
- **HSTS**: Strict Transport Security with preload
- **XSS Protection**: Browser XSS filtering
- **Content Type**: Prevents MIME type sniffing
- **Frame Options**: Prevents clickjacking
- **Referrer Policy**: Controls referrer information

## Monitoring

### Check Status
```bash
# Traefik health
docker-compose ps

# CrowdSec metrics
docker exec crowdsec cscli metrics

# Certificate status
docker exec traefik cat /letsencrypt/acme.json | jq .
```

### View Logs
```bash
# Traefik logs
docker-compose logs -f traefik

# CrowdSec logs
docker-compose logs -f crowdsec
```

### CrowdSec Management
```bash
# View blocked IPs
docker exec crowdsec cscli decisions list

# Add IP to whitelist
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 1h --reason "whitelist"

# Remove IP from blacklist
docker exec crowdsec cscli decisions delete --ip 1.2.3.4
```

## Troubleshooting

### Certificate Issues
1. **Check Cloudflare API key**: Verify permissions and validity
2. **DNS Propagation**: Wait 24-48 hours after DNS changes
3. **Rate Limits**: Check Let's Encrypt limits (50 certs/week)

### CrowdSec Issues
1. **Database Connectivity**: Check MySQL container health
2. **API Key**: Verify CrowdSec API key is correct
3. **Log Access**: Ensure `/var/log` is accessible

### Common Commands
```bash
# Restart services
docker-compose restart

# Rebuild and restart
docker-compose up -d --force-recreate

# Check network connectivity
docker network inspect app-network

# Update UFW with latest Cloudflare IPs
sudo bash ufw-manager.sh
```

## Backup and Recovery

### Backup Certificates
```bash
# Backup Let's Encrypt certificates
docker cp traefik:/letsencrypt ./backup/

# Backup CrowdSec data
docker cp crowdsec:/etc/crowdsec ./backup/
docker cp crowdsec:/var/lib/crowdsec ./backup/
```

### Restore
```bash
# Restore certificates
docker cp ./backup/letsencrypt traefik:/

# Restore CrowdSec data
docker cp ./backup/crowdsec crowdsec:/etc/
docker cp ./backup/crowdsec crowdsec:/var/lib/
```

## Performance Tuning

### Resource Limits
- **Traefik**: 512MB limit, 256MB reservation
- **CrowdSec**: Uses default limits
- **MySQL**: Optimized for CrowdSec workload

### CrowdSec Optimization
- Stream mode for optimal performance
- 60-second cache update intervals
- Internal SQLite database (no external dependencies)
- Automatic threat detection and blocking

## Security Best Practices

1. **Regular Updates**: Keep Traefik and CrowdSec updated
2. **Strong Passwords**: Use complex API keys
3. **API Key Rotation**: Regularly rotate CrowdSec API keys
4. **Monitoring**: Monitor logs for suspicious activity
5. **Backup**: Regular backups of certificates and data
6. **Firewall**: Only Cloudflare IPs can access ports 80/443
7. **Cloudflare IP Updates**: Run ufw-manager.sh monthly to keep IP ranges current
8. **Proxy Verification**: Ensure all domain records use Cloudflare proxy

## How UFW + Docker Works

### UFW Rules vs UFW Route Rules
- **UFW Rules** (`ufw allow`): Control access to the host system
- **UFW Route Rules** (`ufw route allow`): Control access to Docker containers

### Why Both Are Needed
1. **UFW Rules**: Allow Cloudflare to reach your server's ports 80/443
2. **Route Rules**: Allow that traffic to pass through to Docker containers

**Flow**: `Internet → Cloudflare → UFW Rules → UFW Route Rules → Docker Containers`

### Testing
To verify the setup is working:
1. Try accessing your domain via Cloudflare proxy (should work)
2. Try accessing your server's IP directly (should be blocked)
3. Check UFW logs: `sudo ufw status numbered`

## Support

For issues:
1. Check logs: `docker-compose logs -f`
2. Verify configuration: `docker-compose config`
3. Test connectivity: `curl -I https://yourdomain.com`
4. Check CrowdSec: `docker exec crowdsec cscli health`
5. Check UFW status: `sudo ufw status numbered`

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [CrowdSec Documentation](https://docs.crowdsec.net/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
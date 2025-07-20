# Service Deployment Guide

Docker deployments with reverse proxy setup.

> **Note**: This guide assumes you've already set up your server using: `ansible-playbook -i inventory/hosts.yml playbooks/setup.yml`

## Remote Docker Management

### Setup Docker Context
```bash
# Create context for remote server
docker context create remote --docker "host=ssh://admin@tailscale-ip"
docker context use remote

# Verify connection
docker info
docker ps

# Switch back to local
docker context use default
```

### Multiple Environments
```bash
docker context create staging --docker "host=ssh://admin@staging-ip"
docker context create production --docker "host=ssh://admin@prod-ip"

# Use specific context
docker --context production ps
docker --context production compose -f compose.yml up -d
```

## GitOps with Tailscale

### Basic Workflow (`.github/workflows/deploy.yml`)
```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      
      - name: Connect to Tailscale
        uses: tailscale/github-action@v3
        with:
          oauth-client-id: ${{ secrets.TS_OAUTH_CLIENT_ID }}
          oauth-secret: ${{ secrets.TS_OAUTH_SECRET }}
          tags: tag:ci

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.8.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Deploy
        run: |
          docker context create remote --docker "host=ssh://admin@${{ secrets.SERVER_TAILSCALE_IP }}"
          docker context use remote
          docker compose -f docker-compose.yml up -d
```

### Required GitHub Secrets
```bash
TS_OAUTH_CLIENT_ID=<from-tailscale-oauth>
TS_OAUTH_SECRET=<from-tailscale-oauth>
SERVER_TAILSCALE_IP=100.x.x.x
SSH_PRIVATE_KEY=<ssh-key-content>
```

## Docker Compose Deployment

### Basic Commands
```bash
# Deploy services
docker compose up -d

# Update service
docker compose pull && docker compose up -d

# Scale service
docker compose up -d --scale web=3

# Check status
docker compose ps
docker compose logs -f

# Stop services
docker compose down
```

### Remote Deployment
```bash
# Using context
docker context use remote
docker compose -f compose.yml up -d

# Direct SSH
ssh admin@server-ip "cd /opt/docker/myapp && docker compose up -d"
```

## Domain Management

### Reverse Proxy Setup

Set up your own reverse proxy (Traefik, Nginx, Caddy) separately. Common patterns:

#### Traefik Labels
```yaml
services:
  web:
    image: myapp:latest
    labels:
      - traefik.enable=true
      - traefik.http.routers.app.rule=Host(`app.domain.com`)
      - traefik.http.routers.app.entrypoints=websecure
      - traefik.http.routers.app.tls.certresolver=letsencrypt
      - traefik.http.services.app.loadbalancer.server.port=3000
```

#### Nginx Proxy Manager
```yaml
services:
  web:
    image: myapp:latest
    expose:
      - "3000"
    environment:
      - VIRTUAL_HOST=app.domain.com
      - LETSENCRYPT_HOST=app.domain.com
```

#### Caddy
```yaml
services:
  web:
    image: myapp:latest
    labels:
      - caddy=app.domain.com
      - caddy.reverse_proxy={{upstreams 3000}}
```

## Compose Template

```yaml
version: '3.8'
services:
  web:
    image: app:latest
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

  db:
    image: postgres:15
    restart: unless-stopped
    environment:
      - POSTGRES_DB=app
      - POSTGRES_USER=app
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    volumes:
      - db_data:/var/lib/postgresql/data
    secrets:
      - db_password

volumes:
  db_data:

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

## Deployment Strategies

### Rolling Updates
```bash
# Pull new images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Zero-downtime with multiple replicas
docker compose up -d --scale web=2
# Wait for health checks
docker compose up -d --scale web=1 --no-recreate
```

### Blue-Green Deployment
```bash
# Deploy new version
docker compose -f compose-v2.yml -p app-v2 up -d

# Test new version
curl http://localhost:3001/health

# Switch proxy to new version (update reverse proxy config)
# Remove old version
docker compose -p app down
```

## Troubleshooting

### Container Issues
```bash
# Check container status
docker ps -a

# View logs
docker compose logs service-name --tail=50

# Execute into container
docker compose exec service-name bash

# Check resource usage
docker stats
```

### Network Issues
```bash
# Check networks
docker network ls

# Inspect network
docker network inspect bridge

# Test connectivity
docker compose exec web ping db
```

### Context Issues
```bash
# Test SSH connection
ssh admin@server-ip "docker info"

# Check contexts
docker context ls

# Recreate context
docker context rm remote
docker context create remote --docker "host=ssh://admin@server-ip"
```

## File Organization

### Recommended Structure
```
/opt/docker/
├── traefik/              # Reverse proxy setup
│   ├── docker-compose.yml
│   └── config/
├── monitoring/           # Monitoring stack
│   ├── docker-compose.yml
│   └── config/
├── myapp/               # Your application
│   ├── docker-compose.yml
│   ├── .env
│   └── data/
└── backup/              # Backup scripts/data
    └── scripts/
```

### Environment Management
```bash
# Production
cp .env.example .env.prod
docker compose --env-file .env.prod up -d

# Staging
cp .env.example .env.staging
docker compose --env-file .env.staging -p staging up -d
```

## Best Practices

- Use specific image tags, not `latest`
- Implement health checks for all services
- Set resource limits and reservations
- Use secrets for sensitive data
- Backup persistent volumes regularly
- Monitor container logs and metrics
- Test deployments in staging first
- Use restart policies (`unless-stopped`)
- Keep images small and secure
- Document deployment procedures 
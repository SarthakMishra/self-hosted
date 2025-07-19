# Service Deployment Guide

Zero-downtime Docker Swarm deployments with Traefik reverse proxy.

## Remote Docker Management

### Setup Docker Context
```bash
# Create context for remote server
docker context create remote --docker "host=ssh://admin@tailscale-ip"
docker context use remote

# Verify connection
docker info
docker node ls

# Switch back to local
docker context use default
```

### Multiple Environments
```bash
docker context create staging --docker "host=ssh://admin@staging-ip"
docker context create production --docker "host=ssh://admin@prod-ip"

# Use specific context
docker --context production service ls
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
          use-cache: 'true'

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.8.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Deploy
        run: |
          docker context create remote --docker "host=ssh://admin@${{ secrets.SERVER_TAILSCALE_IP }}"
          docker context use remote
          docker stack deploy -c docker-compose.yml app
```

### Tailscale Setup
1. Go to: https://login.tailscale.com/admin/settings/oauth
2. Create OAuth client with `auth_keys` scope and `tag:ci`
3. Add to GitHub Secrets: `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET`

**Required ACL:**
```json
{
  "tagOwners": {
    "tag:ci": ["admin@yourdomain.com"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": ["tag:server:22"]
    }
  ]
}
```

**Required GitHub Secrets:**
```bash
TS_OAUTH_CLIENT_ID=<from-tailscale-oauth>
TS_OAUTH_SECRET=<from-tailscale-oauth>
SERVER_TAILSCALE_IP=100.x.x.x
SSH_PRIVATE_KEY=<ssh-key-content>
```

**SSH Key Setup:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/github-actions -N ""
ssh-copy-id -i ~/.ssh/github-actions.pub admin@server-ip
# Add private key content to GitHub secrets
```

## Deployment Commands

```bash
# Deploy stack
docker stack deploy -c compose.yml app

# Update service
docker service update --image app:v2.0.0 app_web

# Scale service
docker service scale app_web=3

# Rollback
docker service rollback app_web

# Check status
docker service ls
docker service ps app_web

# View logs
docker service logs app_web -f
```

## Compose Template

```yaml
version: '3.8'
services:
  web:
    image: app:latest
    networks: [traefik-public]
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
        order: start-first
      labels:
        - traefik.enable=true
        - traefik.http.routers.app.rule=Host(`app.domain.com`)
        - traefik.http.routers.app.entrypoints=websecure
        - traefik.http.routers.app.tls.certresolver=cloudflare
        - traefik.http.services.app.loadbalancer.server.port=3000
        - traefik.http.services.app.loadbalancer.healthcheck.path=/health
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  traefik-public:
    external: true
```

## Traefik Labels

### Basic Routing
```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.app.rule=Host(`app.domain.com`)
  - traefik.http.routers.app.entrypoints=websecure
  - traefik.http.routers.app.tls.certresolver=cloudflare
  - traefik.http.services.app.loadbalancer.server.port=3000
```

### Health Checks
```yaml
labels:
  - traefik.http.services.app.loadbalancer.healthcheck.path=/health
  - traefik.http.services.app.loadbalancer.healthcheck.interval=30s
  - traefik.http.services.app.loadbalancer.healthcheck.timeout=5s
```

### Security Middlewares
```yaml
labels:
  - traefik.http.middlewares.security.headers.sslredirect=true
  - traefik.http.middlewares.security.headers.stsincludesubdomains=true
  - traefik.http.middlewares.security.headers.stsseconds=31536000
  - traefik.http.routers.app.middlewares=security
```

### Rate Limiting
```yaml
labels:
  - traefik.http.middlewares.rate-limit.ratelimit.burst=100
  - traefik.http.middlewares.rate-limit.ratelimit.average=50
  - traefik.http.routers.app.middlewares=rate-limit
```

## Zero-Downtime Strategies

### Rolling Updates (Default)
```yaml
deploy:
  update_config:
    parallelism: 1
    delay: 10s
    failure_action: rollback
    order: start-first
```

### Blue-Green Deployment
```bash
# Deploy new version
docker stack deploy -c compose-v2.yml app-v2

# Switch Traefik labels
docker service update --label-add traefik.http.routers.app.rule=Host('app.domain.com') app-v2_web
docker service update --label-rm traefik.enable app_web

# Remove old version
docker stack rm app
```

## Troubleshooting

### Service Issues
```bash
# Check service status
docker service ps app_web --no-trunc

# View logs
docker service logs app_web --tail=50

# Check resource usage
docker stats $(docker ps -q --filter label=com.docker.swarm.service.name=app_web)
```

### Traefik Issues
```bash
# Check Traefik logs
docker service logs traefik_traefik --tail=100

# Verify labels
docker service inspect app_web --format='{{json .Spec.Labels}}' | jq

# Test connectivity
curl -f https://app.domain.com/health
```

### Context Issues
```bash
# Test SSH connection
ssh admin@server-ip "docker info"

# Check SSH agent
ssh-add -l

# Recreate context
docker context rm remote
docker context create remote --docker "host=ssh://admin@server-ip"
```

## Best Practices

- Use health checks for proper load balancing
- Implement proper resource limits
- Use secrets for sensitive data
- Monitor service logs and metrics
- Test deployments in staging first
- Keep images small and secure
- Use specific image tags, not `latest`
- Backup persistent data regularly

## Secret Management

### Git-Crypt for Configuration Files
For easier secret management in GitOps workflows:

```bash
# Install git-crypt
sudo apt install git-crypt

# Initialize in repository
git-crypt init

# Add GPG key for team access
git-crypt add-gpg-user your-email@domain.com

# Create .gitattributes for secret files
echo "secrets/* filter=git-crypt diff=git-crypt" >> .gitattributes
echo ".env.* filter=git-crypt diff=git-crypt" >> .gitattributes

# Add encrypted files
mkdir secrets
echo "TS_OAUTH_SECRET=secret123" > secrets/.env
git add . && git commit -m "Add encrypted secrets"

# Team members unlock with their GPG key
git-crypt unlock
```

### Alternatives
- **SOPS**: Mozilla's Secrets OPerationS for YAML/JSON encryption
- **Sealed Secrets**: Kubernetes-native secret encryption
- **External Secrets Operator**: Sync from HashiCorp Vault, AWS Secrets Manager
- **Docker Secrets**: For runtime secret injection in Swarm

*Note: Git-crypt simplifies secret sharing in team environments while maintaining GitOps workflows.*

## Cluster Scaling

### Add Worker Nodes
```bash
# Scale cluster with additional worker nodes
ansible-playbook -i inventory/hosts.yml playbooks/scale-add-workers.yml

# Verify new workers
docker node ls
```

### Add Manager Nodes (HA)
```bash
# Add managers for high availability
ansible-playbook -i inventory/hosts.yml playbooks/scale-add-managers.yml

# Check manager consensus
docker node ls --filter role=manager
```

### Node Maintenance
```bash
# Drain node for maintenance
ansible-playbook -i inventory/hosts.yml playbooks/node-maintenance.yml \
  -e node_action=drain -e target_node=worker1

# Reactivate after maintenance
ansible-playbook -i inventory/hosts.yml playbooks/node-maintenance.yml \
  -e node_action=active -e target_node=worker1
```

**See**: `scaling-guide.md` for complete cluster scaling procedures and best practices.

## Self-Hosted Runner Alternative

Setup on server (in Tailscale network):
```bash
curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf actions-runner.tar.gz
./config.sh --url https://github.com/org/repo --token TOKEN
sudo ./svc.sh install && sudo ./svc.sh start
```

Use in workflow:
```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux]
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: docker stack deploy -c compose.yml app
``` 
# Portainer CE - Docker Management

> **🐳 Docker container management made easy**

Portainer CE provides a comprehensive web-based interface for managing Docker containers, images, networks, and volumes on your home server.

## Features

- **Container Management**: Start, stop, restart, and monitor containers
- **Image Management**: Pull, build, and manage Docker images
- **Network Management**: Create and manage Docker networks
- **Volume Management**: Handle persistent storage
- **Stack Deployment**: Deploy multi-container applications
- **User Management**: Role-based access control
- **Resource Monitoring**: Real-time stats and logs

## Quick Deploy

```bash
# Navigate to service directory
cd /opt/docker/services/
mkdir portainer && cd portainer

# Download template
curl -o docker-compose.yml https://raw.githubusercontent.com/your-repo/service-templates/home/portainer/docker-compose.yml

# Deploy Portainer
docker compose up -d

# Check status
docker compose logs -f portainer
```

## Access

- **Local Web Interface**: `http://portainer.home`
- **Protocol**: HTTP (routed via nginx-proxy)
- **First-time Setup**: Admin user creation required

### Initial Setup

1. **Access Interface**: Navigate to `http://portainer.home`
2. **Create Admin User**:
   - Set admin username and password
   - Password must be at least 12 characters
3. **Choose Environment**: Select "Docker" and verify connection
4. **Start Managing**: Begin managing your Docker environment

## Configuration

### Data Persistence

- **Config Directory**: `/opt/docker/config/portainer-config/`
- **Database**: SQLite database stored in config directory
- **Settings**: All Portainer settings persist across restarts

### Security Features

- **No Analytics**: Analytics disabled with `--no-analytics` flag
- **Local Only**: Not exposed externally (Tailscale/local network only)
- **HTTP**: Local HTTP access via nginx-proxy
- **Docker Socket**: Read/write access to Docker daemon

## Management Commands

```bash
# View logs
docker compose logs portainer

# Restart service
docker compose restart portainer

# Update Portainer
docker compose pull portainer
docker compose up -d

# Backup configuration
sudo tar -czf portainer-backup-$(date +%Y%m%d).tar.gz /opt/docker/config/portainer-config/

# Remove service (keeps data)
docker compose down
```

## Useful Features

### Stack Management
- Deploy compose files directly through web UI
- Manage service templates
- Environment variable management

### Container Operations
- One-click container actions
- Real-time log viewing
- Resource usage monitoring
- Console access to containers

### System Monitoring
- Host resource usage
- Docker engine information
- Container health status
- Network connectivity

## Troubleshooting

### Common Issues

**Cannot access http://portainer.home:**
```bash
# Check if service is running
docker compose ps

# Check nginx-proxy routing
curl -H "Host: portainer.home" http://localhost
```

**Forgot admin password:**
```bash
# Reset admin user (will lose settings)
docker compose down
sudo rm -rf /opt/docker/config/portainer-config/
docker compose up -d
```

**Permission errors:**
```bash
# Check Docker socket permissions
ls -la /var/run/docker.sock

# Verify container can access Docker
docker compose exec portainer docker ps
```

## Security Notes

- **Admin Access**: Full Docker daemon access (create, delete, modify containers)
- **Network Isolation**: Only accessible via home network and Tailscale
- **HTTP Only**: Local unencrypted access (behind nginx-proxy)
- **No External Exposure**: Not accessible from internet

## Updates

Portainer CE updates regularly with new features and security patches:

```bash
# Check current version
docker compose exec portainer portainer --version

# Update to latest
docker compose pull && docker compose up -d
```

Your Docker management interface is ready at **http://portainer.home**! 🚀

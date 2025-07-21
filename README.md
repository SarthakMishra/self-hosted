# Self-Hosted Infrastructure

Complete automation for self-hosted home server deployment.

## 📦 Components

- **`home-server/`** - Ansible automation (nginx-proxy + dnsmasq + Cloudflare tunnel)
- **`packer/`** - Custom Ubuntu image builder with pre-configuration
- **`service-templates/`** - Ready-to-deploy Docker services

### Home Server
- [Server Setup](home-server/README.md) - Complete deployment guide 
- [Service Deployment](home-server/service-deployment-guide.md) - Deploy apps
- [Docker Compose Templates](service-templates/home)

### Remote Server
- [Server Setup](remote-server/README.md) - Complete deployment guide 
- [Service Deployment](remote-server/service-deployment-guide.md) - Deploy apps
- [Docker Compose Templates](service-templates/remote)
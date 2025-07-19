# Docker Swarm Scaling Guide

Automated scaling of Docker Swarm clusters using Ansible playbooks.

## Prerequisites

- Existing single-node Docker Swarm cluster
- Additional servers for scaling
- Ansible inventory configured
- Tailscale mesh VPN setup

## Node Types

- **Manager**: Cluster control (odd numbers: 1,3,5,7 max)
- **Worker**: Application workloads (unlimited)

## Inventory Setup

**Add new nodes to `inventory/hosts.yml`:**
```yaml
docker:
  children:
    swarm_managers:
      hosts:
        manager1: { ansible_host: 10.1.0.100, node_type: manager }
    swarm_workers:
      hosts:
        worker1: { ansible_host: 10.1.0.101, node_type: worker }
    new_workers:
      hosts:
        worker2: { ansible_host: 10.1.0.102, node_type: worker }
        worker3: { ansible_host: 10.1.0.103, node_type: worker }
    new_managers:
      hosts:
        manager2: { ansible_host: 10.1.0.104, node_type: manager }
```

## Scaling Operations

### Add Worker Nodes
```bash
# Scale out with worker nodes
ansible-playbook -i inventory/hosts.yml playbooks/scale-add-workers.yml

# Verify workers joined
ansible swarm_managers[0] -i inventory/hosts.yml -m shell -a "docker node ls"
```

### Add Manager Nodes (HA)
```bash
# Add managers for high availability
ansible-playbook -i inventory/hosts.yml playbooks/scale-add-managers.yml

# Check manager consensus
ansible swarm_managers[0] -i inventory/hosts.yml -m shell -a "docker node ls --filter role=manager"
```

### Node Maintenance
```bash
# Drain node for maintenance
ansible-playbook -i inventory/hosts.yml playbooks/node-maintenance.yml \
  -e node_action=drain -e target_node=worker1

# Reactivate node
ansible-playbook -i inventory/hosts.yml playbooks/node-maintenance.yml \
  -e node_action=active -e target_node=worker1

# Pause node (stop new tasks)
ansible-playbook -i inventory/hosts.yml playbooks/node-maintenance.yml \
  -e node_action=pause -e target_node=worker1
```

## Service Management

### Distribute Services
```bash
# Spread services across worker nodes
docker service update --constraint-add 'node.labels.role==worker' \
  --placement-pref 'spread=node.hostname' SERVICE_NAME

# Keep management services on managers  
docker service update --constraint-add 'node.role==manager' traefik_traefik

# Scale service across nodes
docker service scale SERVICE_NAME=5
```

### Rolling Updates
```bash
# Update service with zero downtime
docker service update --image app:v2.0.0 \
  --update-delay 30s \
  --update-parallelism 1 \
  --update-failure-action rollback \
  SERVICE_NAME

# Monitor update progress
docker service ps SERVICE_NAME
```

## Management Commands

### Cluster Status
```bash
# List all nodes
docker node ls

# Check service distribution
docker service ls
docker service ps SERVICE_NAME

# View Swarm status
docker system info | grep -A 10 "Swarm:"
```

### Node Management
```bash
# Label nodes
docker node update --label-add workload=compute worker1
docker node update --label-add datacenter=dc1 worker1

# Remove node (drain first)
docker node update --availability drain NODE_ID
docker node rm NODE_ID
```

## Troubleshooting

### Connectivity Issues
```bash
# Test Tailscale connectivity
tailscale status
tailscale ping manager1
tailscale ping worker1

# Check node communication
docker node ls
docker node inspect NODE_ID --pretty
```

### Service Issues
```bash
# Check service status
docker service ps SERVICE_NAME --no-trunc

# View service logs
docker service logs SERVICE_NAME -f

# Check constraints
docker service inspect SERVICE_NAME --pretty
```

### Split-Brain Prevention
```bash
# Ensure odd number of managers
docker node ls --filter role=manager

# Check Raft consensus
docker system info | grep -A 5 "Raft"

# Manager count should be: 1, 3, 5, or 7
```

## Best Practices

### Planning
- Start with workers before adding managers
- Use odd numbers of managers (1,3,5,7)
- Consider failure domains and zones
- Plan for network latency between nodes

### Security
- All communication via Tailscale mesh
- No exposed Docker Swarm ports
- Regular token rotation
- Monitor node access

### Operations
- Label nodes appropriately
- Update service constraints for distribution
- Use placement preferences for spreading
- Test scaling operations in staging

### Scaling Patterns
```
Small (3-5 nodes):    1 Manager + 2-4 Workers
HA (5+ nodes):        3 Managers + 2+ Workers  
Large (10+ nodes):    3-5 Managers + Workers
```

## Quick Reference

### Essential Commands
```bash
# Check cluster
docker node ls
docker service ls

# Scale service
docker service scale app=5

# Update service
docker service update --image app:v2 app

# Drain node
docker node update --availability drain worker1

# Join tokens
docker swarm join-token worker
docker swarm join-token manager

# Remove node
docker node rm worker1
```

### Tailscale Commands
```bash
# Check status
tailscale status

# Test connectivity
tailscale ping NODE_NAME

# Get IP
tailscale ip -4
```

---

**Complete automated scaling with zero manual intervention using Ansible playbooks and Tailscale mesh networking.** 
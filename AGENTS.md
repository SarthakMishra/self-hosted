# AGENTS.md - Self-Hosted Infrastructure

## Build/Deploy Commands
- **Run playbook**: `ansible-playbook -i inventory/stage1-bootstrap.yml playbooks/bootstrap.yml` (home-server)
- **Run playbook**: `ansible-playbook -i inventory/stage1-system-setup.yml playbooks/system-setup.yml` (remote-server)  
- **Deploy services**: `ansible-playbook -i inventory/hosts.yml playbooks/services.yml`
- **Expand storage**: `./scripts/expand-storage.sh` (home-server only)
- **Test syntax**: `ansible-playbook --syntax-check playbooks/[playbook].yml`
- **Dry run**: `ansible-playbook --check -i inventory/[stage].yml playbooks/[playbook].yml`

## Code Style Guidelines
- **YAML**: 2-space indentation, `---` file header, descriptive task names with descriptive comments
- **Ansible**: Use fully qualified module names (`ansible.builtin.copy`), include tags for all tasks
- **Shell scripts**: Use `set -euo pipefail`, color output with escape codes, comprehensive error handling
- **Docker Compose**: Use `---` header, descriptive service names, include restart policies and health checks  
- **Variables**: Use snake_case, group related vars in separate files, vault-encrypt secrets
- **Templates**: Include `{{ ansible_managed }}` header, use descriptive Jinja2 variable names
- **File structure**: Group by function (roles/, playbooks/, group_vars/), descriptive directory names
- **Comments**: Explain WHY not WHAT, include banners for major sections, document security implications
- **Error handling**: Always include failed_when conditions, meaningful error messages, graceful fallbacks
- **Security**: Never commit plaintext secrets, use vault files, principle of least privilege for all tasks
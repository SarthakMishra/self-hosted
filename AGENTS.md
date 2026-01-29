# Agent Guidelines

## Repository Structure

```
home-server/       # Ansible playbook for home lab
remote-server/     # Ansible playbook for VPS/cloud
service-templates/ # Docker Compose templates
  ├── home/        # Home network services
  ├── remote/      # Production/cloud services
  └── local/       # Development services
scripts/           # Validation scripts
```

## Pre-commit Hooks

12 hooks run automatically on commit. Run manually with:
```bash
pre-commit run --all-files
```

### Handling Hook Failures

| Hook | Fix |
|------|-----|
| `gitleaks` | Remove secrets, use `changeme` placeholder |
| `yamllint` | Fix indentation (2 spaces), line length (<200) |
| `ansible-lint` | Fix task naming, use FQCNs, add `changed_when` |
| `docker-compose-check` | Validate compose syntax |
| `check-env-placeholders` | Use standardized placeholders (see below) |

## Creating Service Templates

1. Create directory: `service-templates/{home,remote,local}/service-name/`
2. Required files:
   - `docker-compose.yml` - Service definition
   - `env.example` - Environment template

### env.example Conventions

**Placeholders:**
- Secrets/passwords: `changeme`
- Domains: `service.example.com`
- Emails: `admin@example.com`
- IPs: `192.168.1.x`

**Comment style:**
```bash
# Service Name Configuration

# === SECTION ===
# Generate with: openssl rand -hex 32
SECRET_KEY=changeme

# === DATABASE ===
DB_PASSWORD=changeme
```

## Ansible Playbooks

- Use FQCN modules: `ansible.builtin.apt`, `ansible.posix.authorized_key`
- Handler names: Start with uppercase (`Restart Docker`)
- Shell commands: Add `changed_when: true` or `changed_when: false`
- Escape Docker Go templates: `{% raw %}{{.Names}}{% endraw %}`

### Required Collections

```yaml
# requirements.yml
collections:
  - ansible.posix
  - community.docker
  - community.general
```

## File Conventions

- YAML indentation: 2 spaces (consistent within file)
- Line endings: LF (Unix)
- Trailing whitespace: None
- End of file: Single newline

# Bitwarden SSH Agent for WSL2

## Windows Setup
1. Install Bitwarden desktop → Settings → SSH Agent → Enable
2. Add SSH key to vault (create SSH Key item)

## WSL2 Bridge Setup
```bash
# Install bridge
go install github.com/mame/wsl2-ssh-agent@latest

# Configure shell
cat >> ~/.bashrc << 'EOF'
export SSH_AUTH_SOCK="$HOME/.ssh/wsl2-ssh-agent.sock"
auto_start_ssh_bridge() {
    if [ ! -S "$SSH_AUTH_SOCK" ] || ! pgrep -f wsl2-ssh-agent >/dev/null 2>&1; then
        mkdir -p ~/.ssh && wsl2-ssh-agent >/dev/null 2>&1 &
        sleep 2
    fi
}
check_ssh_agent() {
    auto_start_ssh_bridge
    if ssh-add -l >/dev/null 2>&1; then
        echo "✅ SSH agent working with $(ssh-add -l | wc -l) keys"
        ssh-add -l
    else
        echo "❌ Bridge not working"
    fi
}
auto_start_ssh_bridge >/dev/null 2>&1 &
EOF

source ~/.bashrc
```

## Auto-start Service
```bash
# Create systemd service
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/wsl2-ssh-agent.service << 'EOF'
[Unit]
Description=WSL2 SSH Agent Bridge
After=default.target

[Service]
Type=simple
ExecStart=%h/go/bin/wsl2-ssh-agent
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Enable service
systemctl --user daemon-reload
systemctl --user enable --now wsl2-ssh-agent.service
```

## Configure Ansible
In `vault.yml`, comment out private key:
```yaml
# vault_ansible_ssh_private_key_file: "~/.ssh/id_ed25519"  # SSH agent mode
```

## Test
```bash
check_ssh_agent  # Should show keys from Bitwarden
``` 
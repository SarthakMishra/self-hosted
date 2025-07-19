FROM alpine:3.18

# Install required packages
RUN apk add --no-cache \
    restic \
    openssh-client \
    rsync \
    curl \
    bash \
    jq \
    bc \
    dcron \
    procps \
    python3 \
    py3-pip

# Create application user and directories
RUN adduser -D -s /bin/bash app && \
    mkdir -p /app/{config,repository,logs,scripts,ssh} && \
    chown -R app:app /app

# Set up SSH client configuration
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo "Host *" >> /root/.ssh/config && \
    echo "    StrictHostKeyChecking no" >> /root/.ssh/config && \
    echo "    UserKnownHostsFile /dev/null" >> /root/.ssh/config && \
    echo "    ServerAliveInterval 60" >> /root/.ssh/config && \
    echo "    ServerAliveCountMax 3" >> /root/.ssh/config && \
    echo "    ControlMaster auto" >> /root/.ssh/config && \
    echo "    ControlPath /tmp/ssh-control-%h-%p-%r" >> /root/.ssh/config && \
    echo "    ControlPersist 600" >> /root/.ssh/config && \
    chmod 600 /root/.ssh/config

# Copy sync service script
COPY scripts/sync-service.py /app/sync-service.py
COPY scripts/health-server.py /app/health-server.py

# Create entrypoint script
RUN cat > /app/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Wait for configuration to be mounted
while [ ! -f /app/config/ssh/id_rsa ]; do
    echo "Waiting for SSH key configuration..."
    sleep 5
done

# Set up SSH key permissions
cp /app/config/ssh/* /root/.ssh/
chmod 600 /root/.ssh/id_rsa
chmod 644 /root/.ssh/id_rsa.pub 2>/dev/null || true

# Test SSH connection
echo "Testing SSH connection to $REMOTE_HOST..."
if ssh -o ConnectTimeout=10 $REMOTE_USER@$REMOTE_HOST "echo 'SSH connection successful'"; then
    echo "SSH connection verified"
else
    echo "SSH connection failed, retrying in 30 seconds..."
    sleep 30
fi

# Start health check server in background
python3 /app/health-server.py &
HEALTH_PID=$!

# Start main sync service
echo "Starting restic sync service..."
python3 /app/sync-service.py

# Cleanup on exit
kill $HEALTH_PID 2>/dev/null || true
EOF

RUN chmod +x /app/entrypoint.sh

# Set working directory
WORKDIR /app

# Expose health check port
EXPOSE 8080

# Switch to app user for security
USER app

# Start the service
ENTRYPOINT ["/app/entrypoint.sh"] 
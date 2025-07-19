#!/bin/bash
set -euo pipefail

# Local Backup Script for Independent Local Data Protection
# Creates backups of local Docker data and configurations

# Source configuration
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/app/repository}"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/app/config/restic-password}"
LOCAL_DATA_PATH="${LOCAL_DATA_PATH:-/app/local-data}"
LOG_FILE="/app/logs/local-backup.log"

# Export restic environment
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if repository is accessible
if ! restic cat config >/dev/null 2>&1; then
    log "Repository not accessible for local backup"
    exit 1
fi

# Create local data directory if it doesn't exist
mkdir -p "$LOCAL_DATA_PATH"

# Check if there's local data to backup
if [ ! -d "$LOCAL_DATA_PATH" ] || [ -z "$(ls -A "$LOCAL_DATA_PATH" 2>/dev/null)" ]; then
    log "No local data to backup, skipping"
    exit 0
fi

log "Starting local backup"

# Perform backup
restic backup \
    --host="local-machine" \
    --tag=local-data \
    --tag=independent \
    "$LOCAL_DATA_PATH" 2>&1 | tee -a "$LOG_FILE"

log "Local backup completed" 
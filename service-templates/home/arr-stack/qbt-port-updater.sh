#!/bin/sh

# qBittorrent Automatic Port Updater
# Monitors gluetun forwarded port and updates qBittorrent automatically

set -e

# Configuration with defaults
QBT_HOST="${QBT_HOST:-localhost}"
QBT_PORT="${QBT_PORT:-8080}"
QBT_USERNAME="${QBT_USERNAME:-admin}"
QBT_PASSWORD="${QBT_PASSWORD:-adminadmin}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
PORT_FILE="${PORT_FILE:-/shared/forwarded_port}"
COOKIES_FILE="/tmp/qbt_cookies.txt"
MAX_RETRIES=5
RETRY_DELAY=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${RED}ERROR: $1${NC}"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${GREEN}SUCCESS: $1${NC}"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${YELLOW}WARNING: $1${NC}"
}

log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${BLUE}INFO: $1${NC}"
}

# Function to check if qBittorrent is ready
wait_for_qbittorrent() {
    local retries=0
    log_info "Waiting for qBittorrent to be ready..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -s -m 5 "http://$QBT_HOST:$QBT_PORT/api/v2/app/version" >/dev/null 2>&1; then
            log_success "qBittorrent is ready!"
            return 0
        fi
        
        retries=$((retries + 1))
        log_warning "qBittorrent not ready yet (attempt $retries/$MAX_RETRIES). Waiting $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
    done
    
    log_error "qBittorrent failed to become ready after $MAX_RETRIES attempts"
    return 1
}

# Function to login to qBittorrent
qbt_login() {
    log_info "Attempting to login to qBittorrent..."
    
    # Clean up old cookies
    rm -f "$COOKIES_FILE"
    
    local login_response
    login_response=$(curl -s -c "$COOKIES_FILE" \
        -d "username=$QBT_USERNAME&password=$QBT_PASSWORD" \
        -X POST \
        "http://$QBT_HOST:$QBT_PORT/api/v2/auth/login" 2>/dev/null || echo "FAIL")
    
    if [ "$login_response" = "Ok." ]; then
        log_success "Successfully logged into qBittorrent"
        return 0
    else
        log_error "Failed to login to qBittorrent. Response: $login_response"
        log_error "Please check your credentials: Username=$QBT_USERNAME"
        return 1
    fi
}

# Function to update qBittorrent port
update_qbt_port() {
    local new_port="$1"
    
    log_info "Updating qBittorrent listening port to $new_port..."
    
    # Prepare preferences JSON
    local prefs_json="{\"listen_port\":$new_port,\"upnp\":false,\"random_port\":false,\"max_connec\":200,\"max_uploads\":20}"
    
    local response
    response=$(curl -s -b "$COOKIES_FILE" \
        -X POST \
        -d "json=$prefs_json" \
        "http://$QBT_HOST:$QBT_PORT/api/v2/app/setPreferences" 2>/dev/null || echo "FAIL")
    
    if [ $? -eq 0 ]; then
        log_success "Successfully updated qBittorrent listening port to $new_port"
        
        # Verify the change
        sleep 2
        local current_prefs
        current_prefs=$(curl -s -b "$COOKIES_FILE" "http://$QBT_HOST:$QBT_PORT/api/v2/app/preferences" 2>/dev/null)
        
        if echo "$current_prefs" | grep -q "\"listen_port\":$new_port"; then
            log_success "Port update verified successfully"
            return 0
        else
            log_warning "Port update completed but verification failed"
            return 0
        fi
    else
        log_error "Failed to update qBittorrent port"
        return 1
    fi
}

# Function to read port from file with validation
read_port_file() {
    if [ ! -f "$PORT_FILE" ]; then
        return 1
    fi
    
    local port_content
    port_content=$(cat "$PORT_FILE" 2>/dev/null | tr -d '\n\r' | grep -E '^[0-9]+$')
    
    if [ -n "$port_content" ] && [ "$port_content" -ge 1024 ] && [ "$port_content" -le 65535 ]; then
        echo "$port_content"
        return 0
    else
        log_error "Invalid port in file: '$port_content'. Port must be between 1024-65535"
        return 1
    fi
}

# Main monitoring loop
main() {
    log_info "Starting qBittorrent Port Updater"
    log_info "Configuration:"
    log_info "  Host: $QBT_HOST:$QBT_PORT"
    log_info "  Username: $QBT_USERNAME"
    log_info "  Port file: $PORT_FILE"
    log_info "  Check interval: ${CHECK_INTERVAL}s"
    
    local current_port=""
    local startup=true
    
    # Install required packages
    log_info "Installing required packages..."
    apk add --no-cache curl >/dev/null 2>&1
    
    while true; do
        local new_port
        
        if new_port=$(read_port_file); then
            if [ "$new_port" != "$current_port" ] || [ "$startup" = true ]; then
                log_info "Port change detected: '$current_port' -> '$new_port'"
                
                if wait_for_qbittorrent && qbt_login; then
                    if update_qbt_port "$new_port"; then
                        current_port="$new_port"
                        startup=false
                        log_success "Port update cycle completed successfully"
                    else
                        log_error "Failed to update port, will retry on next cycle"
                    fi
                else
                    log_error "Failed to connect/login to qBittorrent, will retry on next cycle"
                fi
            fi
        else
            if [ "$startup" = true ]; then
                log_warning "Port file not found or invalid, waiting for gluetun to create it..."
            fi
        fi
        
        log_info "Sleeping for ${CHECK_INTERVAL} seconds..."
        sleep "$CHECK_INTERVAL"
    done
}

# Signal handlers
cleanup() {
    log_info "Received termination signal, cleaning up..."
    rm -f "$COOKIES_FILE"
    exit 0
}

trap cleanup TERM INT

# Start main function
main 
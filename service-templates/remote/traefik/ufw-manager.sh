#!/bin/bash

# UFW Manager Script for Cloudflare-Only Access
# This script configures UFW to only allow Cloudflare IPs for web traffic

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cloudflare IP range URLs
CLOUDFLARE_IPV4_URL="https://www.cloudflare.com/ips-v4/"
CLOUDFLARE_IPV6_URL="https://www.cloudflare.com/ips-v6/"

# Arrays to store fetched IP ranges
CLOUDFLARE_IPV4=()
CLOUDFLARE_IPV6=()

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

fetch_cloudflare_ips() {
    log_info "Fetching latest Cloudflare IP ranges..."
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed. Please install curl first."
        exit 1
    fi
    
    # Fetch IPv4 ranges
    log_info "Fetching IPv4 ranges from $CLOUDFLARE_IPV4_URL"
    if ! CLOUDFLARE_IPV4_RESPONSE=$(curl -s --max-time 30 "$CLOUDFLARE_IPV4_URL"); then
        log_error "Failed to fetch IPv4 ranges from Cloudflare (timeout or network error)"
        exit 1
    fi
    
    # Extract IPv4 ranges (lines that look like IP ranges)
    CLOUDFLARE_IPV4=($(echo "$CLOUDFLARE_IPV4_RESPONSE" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$' | sort -u))
    
    if [ ${#CLOUDFLARE_IPV4[@]} -eq 0 ]; then
        log_error "No IPv4 ranges found. The page structure may have changed."
        exit 1
    fi
    
    log_success "Found ${#CLOUDFLARE_IPV4[@]} IPv4 ranges"
    
    # Fetch IPv6 ranges
    log_info "Fetching IPv6 ranges from $CLOUDFLARE_IPV6_URL"
    if ! CLOUDFLARE_IPV6_RESPONSE=$(curl -s --max-time 30 "$CLOUDFLARE_IPV6_URL"); then
        log_error "Failed to fetch IPv6 ranges from Cloudflare (timeout or network error)"
        exit 1
    fi
    
    # Extract IPv6 ranges (lines that look like IPv6 ranges)
    CLOUDFLARE_IPV6=($(echo "$CLOUDFLARE_IPV6_RESPONSE" | grep -E '^[0-9a-fA-F:]+/[0-9]{1,3}$' | sort -u))
    
    if [ ${#CLOUDFLARE_IPV6[@]} -eq 0 ]; then
        log_warning "No IPv6 ranges found. Continuing with IPv4 only."
    else
        log_success "Found ${#CLOUDFLARE_IPV6[@]} IPv6 ranges"
    fi
    
    # Display fetched ranges for verification
    log_info "IPv4 ranges:"
    for ip in "${CLOUDFLARE_IPV4[@]}"; do
        echo "  - $ip"
    done
    
    if [ ${#CLOUDFLARE_IPV6[@]} -gt 0 ]; then
        log_info "IPv6 ranges:"
        for ip in "${CLOUDFLARE_IPV6[@]}"; do
            echo "  - $ip"
        done
    fi
    
    echo
}

reset_ufw() {
    log_info "Resetting UFW to default state..."
    
    # Disable UFW temporarily
    ufw --force disable
    
    # Reset to default
    ufw --force reset
    
    log_success "UFW reset completed"
}

configure_basic_rules() {
    log_info "Configuring basic UFW rules..."
    
    # Enable UFW
    ufw enable
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny routed
    
    # Allow SSH (important to not lock yourself out)
    ufw allow ssh
    
    # Allow Tailscale interface
    ufw allow in on tailscale0
    
    log_success "Basic UFW rules configured"
}

add_cloudflare_rules() {
    log_info "Adding Cloudflare IP ranges for ports 80 and 443..."
    
    # Add IPv4 rules for port 80
    for ip in "${CLOUDFLARE_IPV4[@]}"; do
        ufw allow from "$ip" to any port 80 proto tcp
        log_info "Added IPv4 rule for $ip -> port 80"
    done
    
    # Add IPv4 rules for port 443
    for ip in "${CLOUDFLARE_IPV4[@]}"; do
        ufw allow from "$ip" to any port 443 proto tcp
        log_info "Added IPv4 rule for $ip -> port 443"
    done
    
    # Add IPv6 rules for port 80
    for ip in "${CLOUDFLARE_IPV6[@]}"; do
        ufw allow from "$ip" to any port 80 proto tcp
        log_info "Added IPv6 rule for $ip -> port 80"
    done
    
    # Add IPv6 rules for port 443
    for ip in "${CLOUDFLARE_IPV6[@]}"; do
        ufw allow from "$ip" to any port 443 proto tcp
        log_info "Added IPv6 rule for $ip -> port 443"
    done
    
    log_success "Cloudflare IP ranges added"
}

add_cloudflare_route_rules() {
    log_info "Adding Cloudflare route rules for Docker containers..."
    
    # Add IPv4 route rules for port 80
    for ip in "${CLOUDFLARE_IPV4[@]}"; do
        ufw route allow proto tcp from "$ip" to any port 80
        log_info "Added IPv4 route rule for $ip -> port 80"
    done
    
    # Add IPv4 route rules for port 443
    for ip in "${CLOUDFLARE_IPV4[@]}"; do
        ufw route allow proto tcp from "$ip" to any port 443
        log_info "Added IPv4 route rule for $ip -> port 443"
    done
    
    # Add IPv6 route rules for port 80
    for ip in "${CLOUDFLARE_IPV6[@]}"; do
        ufw route allow proto tcp from "$ip" to any port 80
        log_info "Added IPv6 route rule for $ip -> port 80"
    done
    
    # Add IPv6 route rules for port 443
    for ip in "${CLOUDFLARE_IPV6[@]}"; do
        ufw route allow proto tcp from "$ip" to any port 443
        log_info "Added IPv6 route rule for $ip -> port 443"
    done
    
    log_success "Cloudflare route rules added"
}

verify_ufw_docker() {
    log_info "Verifying ufw-docker integration..."
    
    # Check if ufw-docker rules exist in after.rules
    if grep -q "BEGIN UFW AND DOCKER" /etc/ufw/after.rules; then
        log_success "ufw-docker rules found in /etc/ufw/after.rules"
    else
        log_warning "ufw-docker rules not found. Please install ufw-docker first:"
        log_warning "sudo wget -O /usr/local/bin/ufw-docker https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker"
        log_warning "sudo chmod +x /usr/local/bin/ufw-docker"
        log_warning "sudo ufw-docker install"
    fi
    
    # Check if DOCKER-USER chain exists
    if iptables -L DOCKER-USER >/dev/null 2>&1; then
        log_success "DOCKER-USER chain exists"
    else
        log_warning "DOCKER-USER chain not found. ufw-docker may not be properly configured."
    fi
}

show_status() {
    log_info "Current UFW status:"
    echo
    ufw status numbered
    echo
    
    log_info "Current ufw-user-forward rules:"
    echo
    iptables -L ufw-user-forward -n -v
    echo
}

main() {
    log_info "Starting UFW Manager for Cloudflare-Only Access"
    log_info "This will reset all UFW rules and configure Cloudflare-only access"
    echo
    
    # Check if running as root
    check_root
    
    # Execute configuration steps
    fetch_cloudflare_ips
    reset_ufw
    configure_basic_rules
    add_cloudflare_rules
    add_cloudflare_route_rules
    verify_ufw_docker
    
    # Reload UFW to apply all changes
    log_info "Reloading UFW to apply all changes..."
    ufw reload
    
    log_success "UFW configuration completed successfully!"
    echo
    
    show_status
    
    log_info "Configuration Summary:"
    log_info "- UFW reset and configured with default deny incoming"
    log_info "- SSH access preserved"
    log_info "- Tailscale interface allowed"
    log_info "- Cloudflare IPv4 ranges: ${#CLOUDFLARE_IPV4[@]} ranges"
    log_info "- Cloudflare IPv6 ranges: ${#CLOUDFLARE_IPV6[@]} ranges"
    log_info "- Ports 80 and 443 accessible only from Cloudflare IPs"
    log_info "- Docker containers accessible only from Cloudflare IPs"
    echo
    log_warning "IMPORTANT: Make sure you have SSH access before running this script!"
    log_warning "If you lose SSH access, you may need console access to fix UFW rules."
}

# Run main function
main "$@" 
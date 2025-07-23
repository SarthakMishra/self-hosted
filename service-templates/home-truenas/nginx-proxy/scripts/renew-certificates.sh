#!/bin/bash
set -e

# nginx-proxy Certificate Renewal Script
# Renews certificates from step-ca and reloads nginx-proxy

# Configuration
STEP_CA_URL="${STEP_CA_URL:-https://step-ca:9000}"
ACME_DIRECTORY="${STEP_CA_URL}/acme/acme/directory"
CERT_OUTPUT_DIR="/etc/letsencrypt/live"
NGINX_CERTS_DIR="/etc/nginx/certs"
NGINX_PROXY_CONTAINER="nginx-proxy"

echo "🔄 nginx-proxy Certificate Renewal Script"
echo "==========================================="
echo "CA URL: $STEP_CA_URL"
echo "ACME Directory: $ACME_DIRECTORY"
echo "Certificate Directory: $CERT_OUTPUT_DIR"
echo ""

# Check if Step CA is accessible
if ! curl -f -s -k "$STEP_CA_URL/health" > /dev/null 2>&1; then
    echo "❌ Error: Step CA is not accessible at $STEP_CA_URL"
    echo "   Certificate renewal skipped"
    exit 1
fi

echo "✅ Step CA is accessible"

# Track if nginx-proxy needs reload
nginx_reload_needed=false
renewed_domains=()

# Function to check certificate expiry and renew if needed
check_and_renew() {
    local domain=$1
    local cert_file="$CERT_OUTPUT_DIR/$domain/fullchain.pem"
    
    if [ ! -f "$cert_file" ]; then
        echo "⚠️  No certificate found for $domain, skipping"
        return 0
    fi
    
    # Check if certificate expires within next 30 days (2592000 seconds)
    if openssl x509 -checkend 2592000 -noout -in "$cert_file" 2>/dev/null; then
        echo "✅ Certificate for $domain is still valid (>30 days remaining)"
        return 0
    fi
    
    echo "🔄 Certificate for $domain expires soon, renewing..."
    
    # Attempt renewal
    if certbot renew \
        --server "$ACME_DIRECTORY" \
        --cert-name "$domain" \
        --non-interactive \
        --quiet \
        --no-random-sleep-on-renew; then
        
        echo "✅ Certificate renewed for $domain"
        renewed_domains+=("$domain")
        
        # Copy renewed certificate to nginx certs directory
        if [ -f "$cert_file" ] && [ -f "$CERT_OUTPUT_DIR/$domain/privkey.pem" ]; then
            cp "$cert_file" "$NGINX_CERTS_DIR/$domain.crt" 2>/dev/null || true
            cp "$CERT_OUTPUT_DIR/$domain/privkey.pem" "$NGINX_CERTS_DIR/$domain.key" 2>/dev/null || true
            
            # Set proper permissions
            chmod 644 "$NGINX_CERTS_DIR/$domain.crt" 2>/dev/null || true
            chmod 600 "$NGINX_CERTS_DIR/$domain.key" 2>/dev/null || true
        fi
        
        nginx_reload_needed=true
        return 0
    else
        echo "❌ Failed to renew certificate for $domain"
        return 1
    fi
}

# Get list of all domains with certificates
echo "🔍 Checking certificates for renewal..."

if [ -d "$CERT_OUTPUT_DIR" ]; then
    renewal_count=0
    failed_renewals=()
    
    for cert_dir in "$CERT_OUTPUT_DIR"/*; do
        if [ -d "$cert_dir" ]; then
            domain=$(basename "$cert_dir")
            
            if check_and_renew "$domain"; then
                if [[ " ${renewed_domains[@]} " =~ " ${domain} " ]]; then
                    ((renewal_count++))
                fi
            else
                failed_renewals+=("$domain")
            fi
        fi
    done
    
    echo ""
    echo "📊 Renewal Summary"
    echo "=================="
    echo "✅ Certificates checked: $(find "$CERT_OUTPUT_DIR" -maxdepth 1 -type d | tail -n +2 | wc -l)"
    echo "🔄 Certificates renewed: $renewal_count"
    
    if [ ${#failed_renewals[@]} -gt 0 ]; then
        echo "❌ Failed renewals:"
        printf '   - %s\n' "${failed_renewals[@]}"
    fi
    
    if [ ${#renewed_domains[@]} -gt 0 ]; then
        echo "🎯 Renewed domains:"
        printf '   - %s\n' "${renewed_domains[@]}"
    fi
    
else
    echo "ℹ️  No certificate directory found at $CERT_OUTPUT_DIR"
fi

# Reload nginx-proxy if certificates were renewed
if [ "$nginx_reload_needed" = true ]; then
    echo ""
    echo "🔄 Reloading nginx-proxy to use updated certificates..."
    
    # Try different methods to reload nginx-proxy
    if docker exec "$NGINX_PROXY_CONTAINER" nginx -s reload 2>/dev/null; then
        echo "✅ nginx-proxy reloaded successfully using nginx -s reload"
    elif docker restart "$NGINX_PROXY_CONTAINER" 2>/dev/null; then
        echo "✅ nginx-proxy restarted successfully"
        sleep 5  # Give nginx time to start
    else
        echo "⚠️  Could not reload nginx-proxy container"
        echo "   You may need to restart nginx-proxy manually:"
        echo "   docker restart $NGINX_PROXY_CONTAINER"
    fi
else
    echo ""
    echo "ℹ️  No certificates were renewed, nginx-proxy reload not needed"
fi

echo ""
echo "📊 Current Certificate Status"
echo "============================="

# List all certificates and their expiration dates
if [ -d "$CERT_OUTPUT_DIR" ]; then
    for cert_dir in "$CERT_OUTPUT_DIR"/*; do
        if [ -d "$cert_dir" ] && [ -f "$cert_dir/fullchain.pem" ]; then
            domain=$(basename "$cert_dir")
            
            # Get certificate expiration info
            if expiry_info=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.pem" 2>/dev/null); then
                expiry_date=$(echo "$expiry_info" | cut -d= -f2)
                
                # Calculate days until expiry
                if command -v date >/dev/null 2>&1; then
                    if expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null); then
                        current_epoch=$(date +%s)
                        days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                        
                        if [ $days_left -gt 30 ]; then
                            status="✅ Good"
                        elif [ $days_left -gt 7 ]; then
                            status="⚠️  Expires soon"
                        else
                            status="❌ Critical"
                        fi
                        
                        printf "%-25s %s (%d days left)\n" "$domain:" "$status" "$days_left"
                    else
                        printf "%-25s ⚠️  Could not parse expiry date\n" "$domain:"
                    fi
                else
                    printf "%-25s ℹ️  Expiry check not available\n" "$domain:"
                fi
            else
                printf "%-25s ❌ Invalid certificate\n" "$domain:"
            fi
        fi
    done
else
    echo "ℹ️  No certificates found in $CERT_OUTPUT_DIR"
fi

# Health check for nginx-proxy
echo ""
echo "🏥 nginx-proxy Health Check"
echo "============================"

if curl -f -s http://localhost > /dev/null 2>&1; then
    echo "✅ nginx-proxy is responding on HTTP"
else
    echo "❌ nginx-proxy is not responding on HTTP"
fi

if curl -f -s -k https://localhost > /dev/null 2>&1; then
    echo "✅ nginx-proxy is responding on HTTPS"
else
    echo "❌ nginx-proxy is not responding on HTTPS"
fi

# Test specific domain if provided
if [ -n "$1" ]; then
    test_domain="$1"
    echo ""
    echo "🧪 Testing specific domain: $test_domain"
    
    if curl -f -s -k "https://$test_domain" > /dev/null 2>&1; then
        echo "✅ $test_domain is accessible via HTTPS"
    else
        echo "❌ $test_domain is not accessible via HTTPS"
    fi
fi

echo ""
echo "🎯 Certificate renewal completed at $(date)"

# Exit with appropriate code
if [ ${#failed_renewals[@]} -gt 0 ]; then
    echo "⚠️  Some certificate renewals failed"
    exit 1
else
    echo "✅ All certificate operations completed successfully"
    exit 0
fi 
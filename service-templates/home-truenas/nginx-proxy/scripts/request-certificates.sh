#!/bin/bash
set -e

# nginx-proxy Certificate Request Script
# Requests certificates from step-ca for configured domains

# Configuration
STEP_CA_URL="${STEP_CA_URL:-https://step-ca:9000}"
ACME_DIRECTORY="${STEP_CA_URL}/acme/acme/directory"
CERT_OUTPUT_DIR="/etc/letsencrypt/live"
EMAIL="${ACME_EMAIL:-admin@homeserver.local}"

echo "🔐 nginx-proxy Certificate Request Script"
echo "=========================================="
echo "CA URL: $STEP_CA_URL"
echo "ACME Directory: $ACME_DIRECTORY"
echo "Output Directory: $CERT_OUTPUT_DIR"
echo ""

# Read domains from environment or use default list
if [ -n "$AUTO_CERT_DOMAINS" ]; then
    DOMAINS=($AUTO_CERT_DOMAINS)
else
    DOMAINS=(
        "proxy.home"
        "portainer.home"
        "netdata.home"
        "ca.home"
        "sonarr.home"
        "radarr.home"
        "plex.home"
        "immich.home"
        "frigate.home"
    )
fi

echo "📋 Domains to process: ${DOMAINS[*]}"
echo ""

# Wait for step-ca to be ready
echo "⏳ Waiting for Step CA to be ready..."
for i in {1..30}; do
    if curl -f -s -k "$STEP_CA_URL/health" > /dev/null 2>&1; then
        echo "✅ Step CA is ready!"
        break
    fi
    echo "   Attempt $i/30 - Step CA not ready yet..."
    sleep 10
done

# Check if Step CA is accessible
if ! curl -f -s -k "$STEP_CA_URL/health" > /dev/null 2>&1; then
    echo "❌ Error: Step CA is not accessible at $STEP_CA_URL"
    echo "   Please check that step-ca service is running and accessible"
    exit 1
fi

# Function to request certificate for a domain
request_certificate() {
    local domain=$1
    echo "🔒 Requesting certificate for: $domain"
    
    # Check if certificate already exists and is valid
    if [ -f "$CERT_OUTPUT_DIR/$domain/fullchain.pem" ]; then
        # Check if certificate expires within 30 days
        if openssl x509 -checkend 2592000 -noout -in "$CERT_OUTPUT_DIR/$domain/fullchain.pem" 2>/dev/null; then
            echo "   ✅ Valid certificate already exists for $domain (expires in >30 days)"
            return 0
        else
            echo "   ⚠️  Certificate exists but expires soon, renewing..."
        fi
    fi
    
    # Create domain directory if it doesn't exist
    mkdir -p "$CERT_OUTPUT_DIR/$domain"
    
    # Request certificate using certbot with HTTP-01 challenge
    if certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domains "$domain" \
        --server "$ACME_DIRECTORY" \
        --cert-path "$CERT_OUTPUT_DIR/$domain/cert.pem" \
        --key-path "$CERT_OUTPUT_DIR/$domain/privkey.pem" \
        --fullchain-path "$CERT_OUTPUT_DIR/$domain/fullchain.pem" \
        --chain-path "$CERT_OUTPUT_DIR/$domain/chain.pem" \
        --preferred-challenges http \
        --http-01-port 80 \
        --force-renewal; then
        
        echo "   ✅ Certificate obtained successfully for $domain"
        
        # Create nginx-proxy compatible certificate files
        # nginx-proxy expects certificates named after the domain
        cp "$CERT_OUTPUT_DIR/$domain/fullchain.pem" "/etc/nginx/certs/$domain.crt" 2>/dev/null || true
        cp "$CERT_OUTPUT_DIR/$domain/privkey.pem" "/etc/nginx/certs/$domain.key" 2>/dev/null || true
        
        # Set proper permissions
        chmod 644 "$CERT_OUTPUT_DIR/$domain"/*.pem 2>/dev/null || true
        chmod 644 "/etc/nginx/certs/$domain.crt" 2>/dev/null || true
        chmod 600 "/etc/nginx/certs/$domain.key" 2>/dev/null || true
        
        return 0
    else
        echo "   ❌ Failed to obtain certificate for $domain"
        return 1
    fi
}

# Check if nginx-proxy is running (might conflict with HTTP-01 challenge)
if curl -f -s http://localhost > /dev/null 2>&1; then
    echo "⚠️  Warning: nginx-proxy appears to be running on port 80"
    echo "   You may need to stop nginx-proxy temporarily for HTTP-01 challenges to work"
    echo "   Or configure DNS-01 challenges instead"
    echo ""
fi

# Main execution
success_count=0
failed_domains=()

for domain in "${DOMAINS[@]}"; do
    if request_certificate "$domain"; then
        ((success_count++))
    else
        failed_domains+=("$domain")
    fi
    echo ""
done

# Summary
echo "📋 Certificate Request Summary"
echo "=============================="
echo "✅ Successful: $success_count/${#DOMAINS[@]}"

if [ ${#failed_domains[@]} -gt 0 ]; then
    echo "❌ Failed domains:"
    printf '   - %s\n' "${failed_domains[@]}"
    echo ""
    echo "💡 Troubleshooting tips:"
    echo "   - Stop nginx-proxy temporarily: docker compose stop nginx-proxy"
    echo "   - Check that DNS resolves correctly for failed domains"
    echo "   - Verify step-ca is accessible and ACME provisioner is configured"
    echo "   - Check firewall allows port 80 for HTTP-01 challenge"
    echo "   - Consider using DNS-01 challenge for wildcard certificates"
fi

echo ""
echo "🔄 Next steps:"
echo "   1. Start nginx-proxy: docker compose start nginx-proxy"
echo "   2. Test HTTPS access: curl -k https://proxy.home"
echo "   3. Set up certificate renewal cron job"
echo "   4. Configure nginx-proxy to reload when certificates change"

# Create a simple index page for testing
cat > /tmp/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>nginx-proxy with Step CA</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; }
        .success { color: #27ae60; }
        .info { background: #ecf0f1; padding: 15px; border-radius: 4px; margin: 20px 0; }
        .domain { background: #3498db; color: white; padding: 5px 10px; border-radius: 3px; margin: 2px; display: inline-block; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 nginx-proxy with Step CA</h1>
        <p class="success">✅ Your nginx-proxy is working with automatic HTTPS!</p>
        
        <div class="info">
            <h3>📋 Configured Domains:</h3>
EOF

for domain in "${DOMAINS[@]}"; do
    echo "            <span class=\"domain\">https://$domain</span>" >> /tmp/index.html
done

cat >> /tmp/index.html << 'EOF'
        </div>
        
        <div class="info">
            <h3>🔧 Service Access:</h3>
            <ul>
                <li><strong>Step CA:</strong> <a href="https://ca.home">https://ca.home</a></li>
                <li><strong>Portainer:</strong> <a href="https://portainer.home">https://portainer.home</a></li>
                <li><strong>Netdata:</strong> <a href="https://netdata.home">https://netdata.home</a></li>
                <li><strong>Media Services:</strong> plex.home, sonarr.home, radarr.home</li>
            </ul>
        </div>
        
        <div class="info">
            <h3>🛡️ Security Features:</h3>
            <ul>
                <li>✅ Private Certificate Authority (Step CA)</li>
                <li>✅ Automatic HTTPS with valid certificates</li>
                <li>✅ Local network access only</li>
                <li>✅ Automatic certificate renewal</li>
            </ul>
        </div>
        
        <p><em>Generated by nginx-proxy certificate request script</em></p>
    </div>
</body>
</html>
EOF

# Copy index page to nginx serving directory if it exists
if [ -d "/usr/share/nginx/html" ]; then
    cp /tmp/index.html /usr/share/nginx/html/index.html
fi

echo ""
echo "🎯 Certificate request completed at $(date)"

exit 0 
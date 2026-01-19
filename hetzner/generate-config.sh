#!/bin/bash
# =============================================================================
# Hetzner Cloud-Config Generator
# =============================================================================
# This script generates a ready-to-use cloud-config.yml by substituting
# placeholders with values from secrets.yml
#
# Usage:
#   ./generate-config.sh
#   ./generate-config.sh --output my-config.yml
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/cloud-config.yml"
SECRETS_FILE="${SCRIPT_DIR}/secrets.yml"
OUTPUT_FILE="${SCRIPT_DIR}/cloud-config-generated.yml"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -o, --output FILE   Output file path (default: cloud-config-generated.yml)"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if template exists
if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    echo "❌ Error: Template file not found: ${TEMPLATE_FILE}"
    exit 1
fi

# Check if secrets file exists
if [[ ! -f "${SECRETS_FILE}" ]]; then
    echo "❌ Error: Secrets file not found: ${SECRETS_FILE}"
    echo ""
    echo "Please create it from the example:"
    echo "  cp secrets.yml.example secrets.yml"
    echo "  nano secrets.yml"
    exit 1
fi

echo "🔧 Generating cloud-config..."
echo "   Template: ${TEMPLATE_FILE}"
echo "   Secrets:  ${SECRETS_FILE}"
echo "   Output:   ${OUTPUT_FILE}"
echo ""

# Parse secrets from YAML file
parse_secret() {
    local key=$1
    grep "^${key}:" "${SECRETS_FILE}" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//"
}

# Read secrets
ADMIN_USERNAME=$(parse_secret "ADMIN_USERNAME")
SSH_PUBLIC_KEY=$(parse_secret "SSH_PUBLIC_KEY")
TAILSCALE_AUTH_KEY=$(parse_secret "TAILSCALE_AUTH_KEY")
TAILSCALE_HOSTNAME=$(parse_secret "TAILSCALE_HOSTNAME")

# Validate required secrets
MISSING_SECRETS=0

if [[ -z "${ADMIN_USERNAME}" || "${ADMIN_USERNAME}" == "admin" ]]; then
    echo "⚠️  Warning: ADMIN_USERNAME is using default value 'admin'"
fi

if [[ -z "${SSH_PUBLIC_KEY}" || "${SSH_PUBLIC_KEY}" == *"AAAAI..."* ]]; then
    echo "❌ Error: SSH_PUBLIC_KEY is not set or still has placeholder value"
    MISSING_SECRETS=1
fi

if [[ -z "${TAILSCALE_AUTH_KEY}" || "${TAILSCALE_AUTH_KEY}" == *"xxxxx"* ]]; then
    echo "❌ Error: TAILSCALE_AUTH_KEY is not set or still has placeholder value"
    MISSING_SECRETS=1
fi

if [[ -z "${TAILSCALE_HOSTNAME}" ]]; then
    echo "❌ Error: TAILSCALE_HOSTNAME is not set"
    MISSING_SECRETS=1
fi

if [[ ${MISSING_SECRETS} -eq 1 ]]; then
    echo ""
    echo "Please update your secrets.yml file with actual values."
    exit 1
fi

# Generate the config by replacing placeholders
cp "${TEMPLATE_FILE}" "${OUTPUT_FILE}"

# Use different sed syntax based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|<ADMIN_USERNAME>|${ADMIN_USERNAME}|g" "${OUTPUT_FILE}"
    sed -i '' "s|<SSH_PUBLIC_KEY>|${SSH_PUBLIC_KEY}|g" "${OUTPUT_FILE}"
    sed -i '' "s|<TAILSCALE_AUTH_KEY>|${TAILSCALE_AUTH_KEY}|g" "${OUTPUT_FILE}"
    sed -i '' "s|<TAILSCALE_HOSTNAME>|${TAILSCALE_HOSTNAME}|g" "${OUTPUT_FILE}"
else
    # Linux
    sed -i "s|<ADMIN_USERNAME>|${ADMIN_USERNAME}|g" "${OUTPUT_FILE}"
    sed -i "s|<SSH_PUBLIC_KEY>|${SSH_PUBLIC_KEY}|g" "${OUTPUT_FILE}"
    sed -i "s|<TAILSCALE_AUTH_KEY>|${TAILSCALE_AUTH_KEY}|g" "${OUTPUT_FILE}"
    sed -i "s|<TAILSCALE_HOSTNAME>|${TAILSCALE_HOSTNAME}|g" "${OUTPUT_FILE}"
fi

echo "✅ Cloud-config generated successfully!"
echo ""
echo "📋 Configuration Summary:"
echo "   Admin User:        ${ADMIN_USERNAME}"
echo "   SSH Key:           ${SSH_PUBLIC_KEY:0:50}..."
echo "   Tailscale Host:    ${TAILSCALE_HOSTNAME}"
echo ""
echo "📝 Next steps:"
echo "   1. Copy the contents of ${OUTPUT_FILE}"
echo "   2. Paste into Hetzner Cloud Console -> Create Server -> Cloud config"
echo "   3. Or use: cat ${OUTPUT_FILE} | pbcopy (macOS) / xclip (Linux)"
echo ""
echo "⚠️  Remember: Delete ${OUTPUT_FILE} after use (contains secrets)"

#!/bin/bash

# Camoufox Service Deployment Script
# This script deploys the Camoufox service using Docker context

set -e

echo "🚀 Deploying Camoufox service..."

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found. Please run this script from the camoufox service directory."
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build and start the service
echo "🔨 Building Camoufox service..."
docker compose build --no-cache

echo "🚀 Starting Camoufox service..."
docker compose up -d

# Wait for service to be ready
echo "⏳ Waiting for service to be ready..."
sleep 10

# Check service status
echo "📊 Checking service status..."
if docker compose ps | grep -q "Up"; then
    echo "✅ Camoufox service is running!"
    echo ""
    echo "📋 Service Information:"
    echo "   - WebSocket endpoint: ws://localhost:9222/camoufox"
    echo "   - API endpoint: http://localhost:3000"
    echo "   - Health check: http://localhost:3000/health"
    echo ""
    echo "🔗 For OpenWebUI integration, use:"
    echo "   PLAYWRIGHT_WS_URL=ws://camoufox:9222/camoufox"
    echo ""
    echo "📝 To view logs: docker compose logs -f camoufox"
    echo "📝 To stop service: docker compose down"
else
    echo "❌ Service failed to start. Check logs with: docker compose logs camoufox"
    exit 1
fi

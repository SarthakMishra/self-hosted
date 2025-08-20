# Camoufox Remote WebSocket Service

✅ **ACTIVE**: Enhanced stealth browser service using Camoufox with automatic anti-detection features and proxy support.

---

A Docker service that provides a Playwright-compatible WebSocket endpoint using Camoufox - an advanced undetected browser automation library with **automatic stealth configuration rotation** via Browserforge.

## Features

- **Automatic Stealth**: Uses Camoufox + Browserforge for comprehensive anti-detection
- **Virtual Display**: Xvfb-based headless mode for better stealth than traditional headless
- **GeoIP Spoofing**: Built-in geographic location spoofing
- **Proxy Support**: Configurable HTTP/HTTPS proxy with authentication
- **WebSocket Server**: Remote browser access via WebSocket protocol
- **Zero Configuration**: All stealth features automatically managed by Browserforge
- **API Interface**: REST API for service management and endpoint discovery
- **Resource Optimized**: Configurable memory and CPU limits
- **Health Monitoring**: Built-in health checks with detailed status

## Quick Start

```bash
# Start the service
docker compose up -d

# Check service status
docker compose logs -f camoufox

# Test the WebSocket endpoint
curl http://localhost:3000/health

# Get the WebSocket endpoint
curl http://localhost:3000/ws-endpoint
```

## How It Works

The service works by:

1. **Launching Xvfb**: Creates a virtual display for better stealth
2. **Starting Camoufox Server**: Launches the remote WebSocket server with enhanced stealth
3. **Browserforge Integration**: Automatically rotates all stealth configurations (headers, fingerprints, etc.)
4. **Exposing WebSocket Endpoint**: Makes the browser accessible via WebSocket protocol
5. **API Management**: Provides REST endpoints for service monitoring and configuration

## Endpoints

### API Endpoints

- **Health Check**: `GET http://localhost:3000/health`
  - Returns service status, WebSocket endpoint, and stealth configuration
- **WebSocket Info**: `GET http://localhost:3000/ws-endpoint`
  - Returns WebSocket endpoint for browser connections
- **Playwright Endpoint**: `GET http://localhost:3000/playwright-endpoint`
  - OpenWebUI-compatible endpoint information
- **Configuration**: `GET http://localhost:3000/config`
  - Current server configuration and environment variables

### WebSocket Endpoint

- **Browser Connection**: `ws://localhost:9222/camoufox`
  - Direct connection to the Camoufox browser instance

## Configuration

### Core Settings

```bash
# Server Configuration
CAMOUFOX_PORT=9222                    # WebSocket server port
CAMOUFOX_WS_PATH=camoufox            # WebSocket path
CAMOUFOX_HEADLESS=virtual            # Use virtual display (recommended)
CAMOUFOX_GEOIP=true                  # Enable geoip spoofing
```

### Proxy Configuration

```bash
# HTTP/HTTPS Proxy (optional)
CAMOUFOX_PROXY_SERVER=http://proxy.example.com:8080
CAMOUFOX_PROXY_USERNAME=username
CAMOUFOX_PROXY_PASSWORD=password
```

### Stealth Features (Automatic)

**🎭 All stealth configurations are automatically managed by Browserforge:**

- **Browser Fingerprinting**: User agent, viewport, timezone, locale, platform
- **Graphics & Media**: WebGL vendor/renderer, canvas noise, audio noise, font noise
- **System Information**: Hardware concurrency, device memory, languages, plugins
- **Device Detection**: Touch support, mobile detection, permissions
- **Automatic Rotation**: Configurations change between sessions for enhanced stealth

**No manual configuration needed!** Browserforge automatically selects and rotates the most effective stealth configurations.

## Usage with Other Services

### Connect from Playwright

```python
import requests
from playwright.sync_api import sync_playwright

# Get the WebSocket endpoint
response = requests.get('http://localhost:3000/ws-endpoint')
data = response.json()
ws_endpoint = data['ws_endpoint']

# Connect using the WebSocket endpoint
with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp(ws_endpoint)
    page = browser.new_page()
    page.goto('https://example.com')
```

### Integration with OpenWebUI

Set the following environment variables in your OpenWebUI docker-compose.yml:

```yaml
environment:
  - WEB_LOADER_ENGINE=playwright
  - PLAYWRIGHT_WS_URL=ws://camoufox:9222/camoufox
```

**Verification:**
```bash
# Test from OpenWebUI container
docker exec openwebui curl http://camoufox:3000/playwright-endpoint
```

### Integration with Firecrawl

Update your Firecrawl configuration:

```yaml
environment:
  - PLAYWRIGHT_MICROSERVICE_URL=http://camoufox:3000
```

## Enhanced Stealth Features

### 1. Virtual Display (Xvfb)
- **Benefit**: Better stealth than traditional headless mode
- **Implementation**: Uses Xvfb to create a virtual display server
- **Advantage**: Avoids detection patterns associated with headless browsers

### 2. GeoIP Spoofing
- **Benefit**: Geographic location masking
- **Implementation**: Built-in Camoufox geoip functionality
- **Advantage**: Bypasses location-based restrictions and detection

### 3. Browserforge Auto-Rotation
- **Benefit**: Automatic stealth configuration management
- **Implementation**: Browserforge integration for dynamic configuration
- **Advantage**: 
  - No manual configuration needed
  - Configurations automatically rotate between sessions
  - Always uses the most effective stealth settings
  - Prevents fingerprinting through variety

### 4. Proxy Support
- **Benefit**: IP address rotation and geographic diversity
- **Implementation**: Configurable HTTP/HTTPS proxy with authentication
- **Advantage**: Enhanced anonymity and bypass of IP-based restrictions

## Network Access

The service is connected to the `local-network` Docker network, making it accessible to other services in your local development environment.

## Monitoring

```bash
# View logs
docker compose logs camoufox

# Check resource usage
docker stats camoufox_service

# Test WebSocket connection
curl http://localhost:3000/ws-endpoint

# Check service health
curl http://localhost:3000/health
```

## Testing

Test the service endpoints:

```bash
# Health check
curl http://localhost:3000/health

# WebSocket endpoint info
curl http://localhost:3000/ws-endpoint

# Configuration
curl http://localhost:3000/config
```

## Troubleshooting

### Service won't start
```bash
# Check logs for errors
docker compose logs camoufox

# Rebuild the image
docker compose build --no-cache camoufox
docker compose up -d
```

### WebSocket endpoint not available
```bash
# Check service logs
docker compose logs camoufox

# Verify the service is running
curl http://localhost:3000/health
```

### Xvfb issues
```bash
# Check if Xvfb is running inside container
docker exec camoufox_service ps aux | grep Xvfb

# Check display environment
docker exec camoufox_service env | grep DISPLAY
```

### Memory issues
```bash
# Increase memory limit in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 8G  # Increase from 4G
```

## Security Notes

- The service runs with virtual display for enhanced stealth
- WebSocket endpoint is exposed on all interfaces (0.0.0.0)
- Proxy credentials are stored as environment variables
- Intended for local development use only
- Consider network restrictions for production use

## Key Advantages over Patchright

1. **Automatic Stealth**: Browserforge handles all stealth configurations automatically
2. **Zero Configuration**: No need to manually set user agents, viewports, etc.
3. **Virtual Display**: Better stealth than traditional headless mode
4. **GeoIP Spoofing**: Built-in geographic location masking
5. **Proxy Support**: Configurable proxy with authentication
6. **Modern Architecture**: Built specifically for remote server deployment
7. **Better Resource Management**: Optimized for containerized environments
8. **Continuous Improvement**: Stealth configurations automatically adapt and improve

## Performance Considerations

- **Memory Usage**: Virtual display requires additional memory
- **CPU Overhead**: Stealth features add computational overhead
- **Startup Time**: Xvfb initialization adds startup delay
- **Resource Scaling**: Consider increasing limits for high-concurrency usage

## Future Enhancements

- **Session Rotation**: Automatic browser instance rotation
- **Load Balancing**: Multiple browser instances for high availability
- **Metrics Collection**: Detailed performance and stealth metrics
- **Configuration Hot-Reload**: Runtime configuration updates
- **Advanced Proxy Support**: SOCKS5, rotation, and failover

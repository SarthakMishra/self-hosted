#!/usr/bin/env python3
"""
Camoufox Remote WebSocket Server
Enhanced stealth browser service with proxy support and anti-detection features
"""

import os
import threading
import time
import json
import logging
import asyncio
from typing import Dict, Any
from fastapi import FastAPI, HTTPException
import uvicorn
from camoufox.sync_api import Camoufox

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Camoufox Remote Server", version="1.0.0")

# Global state
browser = None
ws_endpoint = None
server_ready = False
server_config: Dict[str, Any] = {}

def get_env_config() -> Dict[str, Any]:
    """Get configuration from environment variables"""
    config = {
        "headless": "virtual",  # Use virtual headless with Xvfb for maximum stealth
        "humanize": True,
        "geoip": True,
        "os": ["windows", "macos", "linux"],  # Rotate OS fingerprints
        "locale": ["en-US", "en-GB", "en-CA"],  # Rotate locales
        "disable_coop": True,  # Disable Cross-Origin-Opener-Policy to prevent issues with antibot mechanisms
        "port": int(os.getenv("CAMOUFOX_PORT", 9222)),
        "ws_path": os.getenv("CAMOUFOX_WS_PATH", "camoufox"),
    }

    # Add proxy if configured
    proxy_server = os.getenv("CAMOUFOX_PROXY_SERVER")
    if proxy_server and proxy_server.strip():
        config["proxy"] = {
            "server": proxy_server,
            "username": os.getenv("CAMOUFOX_PROXY_USERNAME"),
            "password": os.getenv("CAMOUFOX_PROXY_PASSWORD"),
        }

    return config

@app.get("/health")
def health():
    """Health check endpoint"""
    return {
        "status": "healthy" if server_ready else "starting",
        "service": "camoufox",
        "ws_endpoint": ws_endpoint,
        "server_type": "camoufox_direct",
        "config": {
            "port": server_config.get("port"),
            "ws_path": server_config.get("ws_path"),
            "proxy_enabled": bool(server_config.get("proxy")),
            "stealth_features": {
                "geoip": server_config.get("geoip"),
                "headless": server_config.get("headless"),
                "browserforge": "enabled",
                "auto_rotation": "enabled",
            },
        },
    }

@app.get("/ws-endpoint")
def get_ws_endpoint():
    """Get the WebSocket endpoint for connecting to the browser"""
    if not server_ready or not ws_endpoint:
        raise HTTPException(status_code=503, detail="Server not ready")

    return {
        "ws_endpoint": ws_endpoint,
        "status": "ready",
        "server_type": "camoufox_direct",
        "connection_info": {
            "protocol": "ws",
            "host": "localhost",
            "port": server_config.get("port"),
            "path": server_config.get("ws_path"),
        },
    }

@app.get("/playwright-endpoint")
def get_playwright_endpoint():
    """Get the Playwright-compatible WebSocket endpoint for OpenWebUI"""
    if not server_ready or not ws_endpoint:
        raise HTTPException(status_code=503, detail="Server not ready")

    return {
        "wsEndpoint": ws_endpoint,
        "status": "ready",
        "server_type": "camoufox_direct",
        "usage_note": "Use this endpoint with OpenWebUI PLAYWRIGHT_WS_URL",
        "stealth_features": "Enhanced anti-detection with Camoufox + Browserforge auto-rotation",
    }

@app.get("/config")
def get_config():
    """Get current server configuration"""
    return {
        "server_config": server_config,
        "environment_variables": {
            "CAMOUFOX_PORT": os.getenv("CAMOUFOX_PORT"),
            "CAMOUFOX_WS_PATH": os.getenv("CAMOUFOX_WS_PATH"),
            "CAMOUFOX_PROXY_SERVER": os.getenv("CAMOUFOX_PROXY_SERVER"),
            "CAMOUFOX_GEOIP": os.getenv("CAMOUFOX_GEOIP", "true"),
            "CAMOUFOX_HEADLESS": os.getenv("CAMOUFOX_HEADLESS", "virtual"),
        },
        "stealth_info": {
            "browserforge": "enabled",
            "auto_rotation": "enabled",
            "description": "Camoufox automatically rotates browser configurations, headers, and fingerprints using Browserforge",
        },
    }

def start_camoufox_server():
    """Start the Camoufox browser with CDP enabled"""
    global browser, ws_endpoint, server_ready, server_config

    try:
        logger.info("🚀 Starting Camoufox browser with CDP...")

        # Get configuration
        server_config = get_env_config()

        logger.info(f"📋 Server configuration: {json.dumps(server_config, indent=2)}")
        logger.info(
            "🔄 Browserforge auto-rotation enabled - stealth configs will rotate automatically"
        )

        # Launch the Camoufox browser with CDP enabled
        browser_args = [
            f"--remote-debugging-port={server_config['port']}",
            "--remote-debugging-address=0.0.0.0",
            "--no-sandbox",
            "--disable-dev-shm-usage",
            "--disable-gpu",
            "--disable-web-security",
            "--disable-features=VizDisplayCompositor",
        ]

        # Create browser configuration
        browser_config = {
            "headless": server_config["headless"],
            "humanize": server_config["humanize"],
            "geoip": server_config["geoip"],
            "os": server_config["os"],
            "locale": server_config["locale"],
            "disable_coop": server_config["disable_coop"],
            "args": browser_args,
        }

        # Add proxy if configured
        if server_config.get("proxy"):
            browser_config["proxy"] = server_config["proxy"]

        # Launch the Camoufox browser
        browser = Camoufox(**browser_config)

        logger.info("✅ Camoufox browser started!")
        logger.info(f"✅ CDP available on port {server_config['port']}")

        # Wait for CDP to be ready
        logger.info("⏳ Waiting for CDP to be ready...")
        time.sleep(5)

        # Construct WebSocket endpoint
        ws_endpoint = (
            f"ws://localhost:{server_config['port']}/{server_config['ws_path']}"
        )
        server_ready = True

        logger.info(f"✅ Camoufox server started successfully!")
        logger.info(f"🔗 WebSocket endpoint: {ws_endpoint}")
        logger.info(f"🌐 Server accessible on port {server_config['port']}")
        logger.info("🎭 Browserforge is automatically rotating stealth configurations")

        # Keep browser running
        while server_ready:
            time.sleep(30)

    except Exception as e:
        logger.error(f"❌ Failed to start Camoufox server: {e}")
        import traceback

        traceback.print_exc()
        server_ready = False

def start_api():
    """Start the FastAPI server"""
    logger.info("🌐 Starting API server on port 3000...")
    uvicorn.run(app, host="0.0.0.0", port=3000, log_level="info")

def cleanup():
    """Clean up resources"""
    global browser, server_ready
    if browser:
        browser.close()
    server_ready = False

if __name__ == "__main__":
    # Start API server in background thread
    api_thread = threading.Thread(target=start_api, daemon=True)
    api_thread.start()

    # Give API server time to start
    time.sleep(2)

    try:
        # Start Camoufox server in main thread
        start_camoufox_server()

        # Keep main thread alive
        while server_ready:
            time.sleep(30)

    except KeyboardInterrupt:
        logger.info("🛑 Shutting down...")
    finally:
        cleanup()
```


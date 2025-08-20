#!/usr/bin/env python3
"""
Test script for Camoufox service
Verifies the service is running and WebSocket endpoint is accessible
"""

import requests
import json
import time
import sys


def test_health_endpoint():
    """Test the health endpoint"""
    print("🔍 Testing health endpoint...")
    try:
        response = requests.get("http://localhost:3000/health", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Health check passed: {data['status']}")
            print(f"   Service: {data['service']}")
            print(f"   Server type: {data['server_type']}")
            if data.get("ws_endpoint"):
                print(f"   WebSocket endpoint: {data['ws_endpoint']}")

            # Check stealth features
            stealth = data.get("config", {}).get("stealth_features", {})
            if stealth.get("browserforge") == "enabled":
                print("   🎭 Browserforge auto-rotation: enabled")
            if stealth.get("auto_rotation") == "enabled":
                print("   🔄 Automatic stealth rotation: enabled")

            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Health check error: {e}")
        return False


def test_ws_endpoint():
    """Test the WebSocket endpoint endpoint"""
    print("\n🔍 Testing WebSocket endpoint...")
    try:
        response = requests.get("http://localhost:3000/ws-endpoint", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ WebSocket endpoint available: {data['ws_endpoint']}")
            print(f"   Status: {data['status']}")
            print(f"   Server type: {data['server_type']}")
            return True
        else:
            print(f"❌ WebSocket endpoint failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ WebSocket endpoint error: {e}")
        return False


def test_playwright_endpoint():
    """Test the Playwright endpoint for OpenWebUI compatibility"""
    print("\n🔍 Testing Playwright endpoint...")
    try:
        response = requests.get("http://localhost:3000/playwright-endpoint", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Playwright endpoint available: {data['wsEndpoint']}")
            print(f"   Status: {data['status']}")
            print(f"   Server type: {data['server_type']}")
            print(f"   Usage note: {data['usage_note']}")
            return True
        else:
            print(f"❌ Playwright endpoint failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Playwright endpoint error: {e}")
        return False


def test_config_endpoint():
    """Test the configuration endpoint"""
    print("\n🔍 Testing configuration endpoint...")
    try:
        response = requests.get("http://localhost:3000/config", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print("✅ Configuration endpoint available")
            print(f"   Port: {data['server_config'].get('port')}")
            print(f"   WebSocket path: {data['server_config'].get('ws_path')}")
            print(f"   Headless mode: {data['server_config'].get('headless')}")
            print(f"   GeoIP enabled: {data['server_config'].get('geoip')}")
            print(
                f"   Proxy enabled: {data['server_config'].get('proxy_enabled', False)}"
            )

            # Check stealth info
            stealth_info = data.get("stealth_info", {})
            if stealth_info.get("browserforge") == "enabled":
                print("   🎭 Browserforge: enabled")
            if stealth_info.get("auto_rotation") == "enabled":
                print("   🔄 Auto-rotation: enabled")
            if stealth_info.get("description"):
                print(f"   📝 {stealth_info['description']}")

            return True
        else:
            print(f"❌ Configuration endpoint failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Configuration endpoint error: {e}")
        return False


def test_service_readiness():
    """Test if the service is fully ready"""
    print("\n🔍 Testing service readiness...")

    max_attempts = 30
    attempt = 0

    while attempt < max_attempts:
        try:
            response = requests.get("http://localhost:3000/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                if data["status"] == "healthy" and data.get("ws_endpoint"):
                    print(f"✅ Service is ready after {attempt + 1} attempts")
                    return True
        except:
            pass

        attempt += 1
        time.sleep(2)
        if attempt % 5 == 0:
            print(f"   Waiting... (attempt {attempt}/{max_attempts})")

    print("❌ Service did not become ready within expected time")
    return False


def main():
    """Main test function"""
    print("🚀 Testing Camoufox service...")
    print("=" * 50)

    # Test service readiness first
    if not test_service_readiness():
        print("\n❌ Service is not ready. Exiting.")
        sys.exit(1)

    # Test all endpoints
    tests = [
        test_health_endpoint,
        test_ws_endpoint,
        test_playwright_endpoint,
        test_config_endpoint,
    ]

    passed = 0
    total = len(tests)

    for test in tests:
        if test():
            passed += 1

    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 All tests passed! Camoufox service is working correctly.")
        print("\n📋 Service Information:")
        print("   - WebSocket endpoint: ws://localhost:9222/camoufox")
        print("   - API endpoint: http://localhost:3000")
        print("   - Health check: http://localhost:3000/health")
        print("\n🔗 For OpenWebUI integration, use:")
        print("   PLAYWRIGHT_WS_URL=ws://camoufox:9222/camoufox")
        print("\n🎭 Stealth Features:")
        print("   - Browserforge auto-rotation: enabled")
        print("   - Automatic stealth configuration: enabled")
        print("   - No manual configuration needed!")
    else:
        print("⚠️  Some tests failed. Check the service logs.")
        sys.exit(1)


if __name__ == "__main__":
    main()

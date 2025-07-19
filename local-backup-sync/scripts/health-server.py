#!/usr/bin/env python3
"""
Health Check Server for Restic Sync Service
Provides HTTP endpoints for Docker health checks and service monitoring
"""

import os
import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class HealthCheckHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status_code=200, content_type="application/json"):
        self.send_response(status_code)
        self.send_header("Content-type", content_type)
        self.end_headers()

    def _get_sync_status(self):
        """Check sync service health based on recent activity"""
        try:
            log_file = Path("/app/logs/sync-service.log")

            # Check if log file shows recent activity
            if log_file.exists():
                log_age = time.time() - log_file.stat().st_mtime
                if log_age > 1800:  # 30 minutes old
                    return False, f"Log file is {log_age:.0f} seconds old"
            else:
                return False, "No log file found"

            return True, "Service healthy"

        except Exception as e:
            return False, f"Health check error: {e}"

    def _get_repository_info(self):
        """Get local repository information"""
        try:
            repo_path = Path("/app/repository")
            if not repo_path.exists():
                return {"status": "missing", "size": 0, "snapshots": 0}

            # Calculate repository size
            total_size = sum(
                f.stat().st_size for f in repo_path.rglob("*") if f.is_file()
            )

            # Try to get snapshot count (if restic is available)
            snapshot_count = 0
            try:
                import subprocess

                env = os.environ.copy()
                env["RESTIC_REPOSITORY"] = str(repo_path)
                env["RESTIC_PASSWORD_FILE"] = "/app/config/restic-password"

                result = subprocess.run(
                    ["restic", "snapshots", "--json"],
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=30,
                )

                if result.returncode == 0:
                    snapshots = json.loads(result.stdout)
                    snapshot_count = len(snapshots)

            except Exception:
                pass  # Not critical if we can't get snapshot count

            return {
                "status": "available",
                "size": total_size,
                "snapshots": snapshot_count,
            }

        except Exception as e:
            return {"status": "error", "error": str(e)}

    def do_GET(self):
        if self.path == "/health":
            # Basic health check
            is_healthy, message = self._get_sync_status()

            response = {
                "status": "healthy" if is_healthy else "unhealthy",
                "message": message,
                "timestamp": int(time.time()),
            }

            status_code = 200 if is_healthy else 503
            self._set_headers(status_code)
            self.wfile.write(json.dumps(response).encode())

        elif self.path == "/status":
            # Detailed status information
            is_healthy, health_message = self._get_sync_status()
            repo_info = self._get_repository_info()

            response = {
                "service": {
                    "status": "healthy" if is_healthy else "unhealthy",
                    "message": health_message,
                },
                "repository": repo_info,
                "environment": {
                    "remote_host": os.getenv("REMOTE_HOST", "not configured"),
                    "sync_interval": os.getenv("SYNC_INTERVAL", "900"),
                    "bandwidth_limit": os.getenv("BANDWIDTH_LIMIT", "10M"),
                },
                "timestamp": int(time.time()),
            }

            self._set_headers()
            self.wfile.write(json.dumps(response, indent=2).encode())

        else:
            # 404 for unknown paths
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Not found"}).encode())

    def do_HEAD(self):
        self._set_headers()

    def log_message(self, format, *args):
        # Suppress default logging to avoid noise
        pass


def run_health_server():
    port = int(os.getenv("HEALTH_CHECK_PORT", 8080))
    server_address = ("", port)

    httpd = HTTPServer(server_address, HealthCheckHandler)
    logger.info(f"Health check server starting on port {port}")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Health check server shutting down")
        httpd.shutdown()


if __name__ == "__main__":
    run_health_server()

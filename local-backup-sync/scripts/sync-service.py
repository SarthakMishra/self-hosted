#!/usr/bin/env python3
"""
Restic Remote Sync Service
Robust reverse SSH pull sync for Restic repositories with minimal data loss
"""

import os
import time
import json
import logging
import subprocess
import signal
import sys
from datetime import datetime, timedelta
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("/app/logs/sync-service.log"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)


class ResticSyncService:
    def __init__(self):
        self.remote_host = os.getenv("REMOTE_HOST")
        self.remote_user = os.getenv("REMOTE_USER", "admin")
        self.remote_backup_path = os.getenv(
            "REMOTE_BACKUP_PATH", "/opt/docker-swarm/backup"
        )
        self.local_repo_path = os.getenv("LOCAL_REPO_PATH", "/app/repository")
        self.sync_interval = int(os.getenv("SYNC_INTERVAL", 900))  # 15 minutes
        self.bandwidth_limit = os.getenv("BANDWIDTH_LIMIT", "10M")
        self.max_retries = int(os.getenv("MAX_RETRIES", 3))

        self.ssh_command = f"ssh {self.remote_user}@{self.remote_host}"
        self.rsync_base_cmd = [
            "rsync",
            "-avz",
            "--compress-level=6",
            f"--bwlimit={self.bandwidth_limit}",
            "--partial",
            "--progress",
            "--stats",
        ]

        self.running = True
        self.last_sync_timestamp = None
        self.consecutive_failures = 0

        # Ensure local directories exist
        Path(self.local_repo_path).mkdir(parents=True, exist_ok=True)
        Path("/app/logs").mkdir(parents=True, exist_ok=True)
        Path("/app/metrics").mkdir(parents=True, exist_ok=True)

        # Set up signal handlers
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def _signal_handler(self, signum, frame):
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False

    def _run_command(self, cmd, timeout=3600):
        """Run command with timeout and proper error handling"""
        try:
            logger.debug(
                f"Running command: {' '.join(cmd) if isinstance(cmd, list) else cmd}"
            )
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=timeout, check=True
            )
            return result.stdout, result.stderr, 0
        except subprocess.TimeoutExpired:
            logger.error(f"Command timed out after {timeout} seconds")
            return "", "Command timed out", 124
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed with exit code {e.returncode}: {e.stderr}")
            return e.stdout, e.stderr, e.returncode
        except Exception as e:
            logger.error(f"Unexpected error running command: {e}")
            return "", str(e), 1

    def _test_ssh_connection(self):
        """Test SSH connectivity to remote server"""
        cmd = f"{self.ssh_command} 'echo SSH_OK'"
        stdout, stderr, returncode = self._run_command(cmd.split(), timeout=30)

        if returncode == 0 and "SSH_OK" in stdout:
            logger.debug("SSH connection test successful")
            return True
        else:
            logger.error(f"SSH connection test failed: {stderr}")
            return False

    def _get_remote_repository_info(self):
        """Get information about remote repository state"""
        try:
            # Check if backup is currently running
            marker_check_cmd = f"{self.ssh_command} 'test -f {self.remote_backup_path}/sync-in-progress && echo BACKUP_RUNNING || echo BACKUP_READY'"
            stdout, stderr, returncode = self._run_command(
                marker_check_cmd.split(), timeout=30
            )

            if returncode != 0:
                logger.error(f"Failed to check remote backup status: {stderr}")
                return None

            backup_status = stdout.strip()

            # Get repository size and last modification time
            stat_cmd = f'{self.ssh_command} \'stat -c "%Y %s" {self.remote_backup_path}/repository/config || echo "0 0"\''
            stdout, stderr, returncode = self._run_command(stat_cmd.split(), timeout=30)

            if returncode != 0:
                logger.warning(f"Could not get repository stats: {stderr}")
                return {"status": backup_status, "mtime": 0, "size": 0}

            parts = stdout.strip().split()
            mtime = int(parts[0]) if len(parts) >= 1 else 0
            size = int(parts[1]) if len(parts) >= 2 else 0

            return {"status": backup_status, "mtime": mtime, "size": size}

        except Exception as e:
            logger.error(f"Error getting remote repository info: {e}")
            return None

    def _sync_repository(self):
        """Perform incremental sync of repository from remote to local"""
        try:
            logger.info("Starting repository sync...")

            # Check if remote backup is in progress
            remote_info = self._get_remote_repository_info()
            if not remote_info:
                logger.error("Could not get remote repository information")
                return False

            if remote_info["status"] == "BACKUP_RUNNING":
                logger.info("Remote backup is currently running, skipping sync")
                return True

            # Check if there are changes since last sync
            if (
                self.last_sync_timestamp
                and remote_info["mtime"] <= self.last_sync_timestamp
            ):
                logger.debug("No changes detected since last sync")
                return True

            # Create marker file for sync in progress
            marker_cmd = (
                f"{self.ssh_command} 'touch {self.remote_backup_path}/sync-in-progress'"
            )
            self._run_command(marker_cmd.split(), timeout=30)

            try:
                # Sync repository data
                remote_repo_path = f"{self.remote_user}@{self.remote_host}:{self.remote_backup_path}/repository/"

                rsync_cmd = self.rsync_base_cmd + [
                    "--exclude=locks/",  # Exclude lock files
                    "--exclude=tmp/",  # Exclude temporary files
                    remote_repo_path,
                    self.local_repo_path + "/",
                ]

                logger.info(f"Syncing repository data: {' '.join(rsync_cmd)}")
                stdout, stderr, returncode = self._run_command(rsync_cmd, timeout=3600)

                if returncode != 0:
                    logger.error(f"Repository sync failed: {stderr}")
                    return False

                # Parse rsync stats
                if "Number of files transferred:" in stderr:
                    transferred_files = int(
                        [
                            line
                            for line in stderr.split("\n")
                            if "Number of files transferred:" in line
                        ][0]
                        .split(":")[1]
                        .strip()
                    )
                    logger.info(f"Transferred {transferred_files} files")

                # Verify local repository integrity
                if not self._verify_local_repository():
                    logger.error("Local repository verification failed")
                    return False

                # Update timestamp
                self.last_sync_timestamp = remote_info["mtime"]

                # Trigger remote cleanup if enabled
                self._trigger_remote_cleanup()

                logger.info("Repository sync completed successfully")
                return True

            finally:
                # Remove sync marker
                cleanup_cmd = f"{self.ssh_command} 'rm -f {self.remote_backup_path}/sync-in-progress'"
                self._run_command(cleanup_cmd.split(), timeout=30)

        except Exception as e:
            logger.error(f"Sync operation failed: {e}")
            return False

    def _verify_local_repository(self):
        """Verify integrity of local repository"""
        try:
            logger.info("Verifying local repository integrity...")

            # Set restic environment
            env = os.environ.copy()
            env["RESTIC_REPOSITORY"] = self.local_repo_path
            env["RESTIC_PASSWORD_FILE"] = "/app/config/restic-password"

            # Quick check
            cmd = ["restic", "check", "--read-data-subset=1%"]

            result = subprocess.run(
                cmd, env=env, capture_output=True, text=True, timeout=600
            )

            if result.returncode == 0:
                logger.info("Repository verification successful")
                return True
            else:
                logger.error(f"Repository verification failed: {result.stderr}")
                return False

        except Exception as e:
            logger.error(f"Repository verification error: {e}")
            return False

    def _trigger_remote_cleanup(self):
        """Trigger cleanup on remote server after successful sync"""
        try:
            # Create sync completion marker
            marker_cmd = (
                f"{self.ssh_command} 'touch /tmp/restic-sync-complete-$(date +%Y%m%d)'"
            )
            self._run_command(marker_cmd.split(), timeout=30)

            # Trigger cleanup script
            cleanup_cmd = f"{self.ssh_command} 'RESTIC_SYNC_CALLER=local-sync-service {self.remote_backup_path}/scripts/cleanup-remote.sh'"
            stdout, stderr, returncode = self._run_command(
                cleanup_cmd.split(), timeout=1800
            )

            if returncode == 0:
                logger.info("Remote cleanup completed successfully")
            else:
                logger.warning(f"Remote cleanup failed (non-critical): {stderr}")

        except Exception as e:
            logger.warning(f"Remote cleanup error (non-critical): {e}")

    def run(self):
        """Main service loop"""
        logger.info(f"Starting Restic Sync Service")
        logger.info(
            f"Remote: {self.remote_user}@{self.remote_host}:{self.remote_backup_path}"
        )
        logger.info(f"Local: {self.local_repo_path}")
        logger.info(f"Sync interval: {self.sync_interval} seconds")

        # Initial connectivity test
        if not self._test_ssh_connection():
            logger.error("Initial SSH connection failed")
            sys.exit(1)

        while self.running:
            try:
                # Perform sync operation
                sync_success = self._sync_repository()

                # Track consecutive failures
                if sync_success:
                    self.consecutive_failures = 0
                else:
                    self.consecutive_failures += 1

                # Check for too many consecutive failures
                if self.consecutive_failures >= self.max_retries:
                    logger.critical(
                        f"Too many consecutive failures ({self.consecutive_failures}), stopping service"
                    )
                    break

                # Wait for next sync interval
                if self.running:
                    logger.info(f"Next sync in {self.sync_interval} seconds")
                    time.sleep(self.sync_interval)

            except KeyboardInterrupt:
                logger.info("Received interrupt signal, shutting down...")
                break
            except Exception as e:
                logger.error(f"Unexpected error in main loop: {e}")
                time.sleep(60)  # Wait before retrying

        logger.info("Restic Sync Service stopped")


if __name__ == "__main__":
    service = ResticSyncService()
    service.run()

# Global Watchtower Service

This service automatically updates Docker containers to their latest image versions.

## How It Works

Watchtower runs on a schedule and monitors all other containers. When it detects that a newer image is available for a container, it will automatically pull the new image and restart the container with the updated version.

### Opt-In Configuration

This Watchtower instance is configured to be **opt-in**. It will **only** update containers that have the following label applied in their `docker-compose.yml`:

```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

This gives you explicit control over which services are automatically updated.

## ⚠️ Important: No Automatic Rollbacks

Watchtower does **not** automatically roll back an update if it fails. If a new image contains a breaking change or fails to start, the service will be left in a non-running state, requiring **manual intervention**.

## Best Practices for Safe Updates

To prevent failed updates from breaking your services, it is strongly recommended to follow these practices:

1.  **Pin Image Versions**: Avoid using the `:latest` tag for critical services. Instead, pin to a specific major/minor version (e.g., `image: nocodb/nocodb:0.205`). This prevents unexpected, major breaking changes from being pulled automatically.
2.  **Maintain Regular Backups**: Always have a robust backup strategy for your persistent data (Docker volumes), especially for databases. An image rollback cannot fix corrupted data.
3.  **Enable Notifications**: For production environments, consider configuring Watchtower to send notifications (e.g., via email or Slack) so you are immediately aware when an update has occurred. 
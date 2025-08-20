#!/bin/bash

# Start Xvfb (virtual display) on display :99
echo "Starting Xvfb virtual display..."

# Clean up any existing display locks
rm -f /tmp/.X99-lock
rm -rf /tmp/.X11-unix/X99

# Start Xvfb on display :99
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
XVFB_PID=$!

# Wait for Xvfb to be ready
sleep 3

# Set DISPLAY environment variable
export DISPLAY=:99

# Start the Camoufox server
echo "Starting Camoufox server..."
python camoufox_server.py

# Cleanup Xvfb when server exits
if [ -n "$XVFB_PID" ]; then
    kill $XVFB_PID 2>/dev/null || true
fi

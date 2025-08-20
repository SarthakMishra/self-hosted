FROM python:3.11-slim

# Install system dependencies including xvfb for virtual display
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    xvfb \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libxss1 \
    libasound2 \
    libatspi2.0-0 \
    libgtk-3-0 \
    libx11-6 \
    libxext6 \
    libxfixes3 \
    libxcb1 \
    libxcb-dri3-0 \
    fonts-liberation \
    libappindicator3-1 \
    libdbusmenu-gtk3-4 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies with geoip extra
RUN pip install camoufox[geoip] fastapi uvicorn websockets requests

# Create app directory
WORKDIR /app

# Copy the application script
COPY camoufox_server.py .

# Create a startup script for xvfb
COPY start.sh .
RUN chmod +x start.sh

# Expose ports
EXPOSE 3000 9222

# Run the startup script
CMD ["./start.sh"]

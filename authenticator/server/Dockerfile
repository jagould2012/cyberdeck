FROM node:20-bookworm

# Install Bluetooth and system dependencies
RUN apt-get update && apt-get install -y \
	bluetooth \
	bluez \
	libbluetooth-dev \
	libudev-dev \
	libusb-1.0-0-dev \
	dbus \
	xprintidle \
	libpam0g-dev \
	&& rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/

# Create data directory
RUN mkdir -p /data/publicKeys

# Environment variables
ENV NODE_ENV=production
ENV CONFIG_PATH=/data/config.json
ENV PUBLIC_KEYS_DIR=/data/publicKeys

# The container needs access to:
# - /var/run/dbus (D-Bus socket)
# - /dev (Bluetooth devices)
# - Host network for BLE

CMD ["node", "src/index.js"]
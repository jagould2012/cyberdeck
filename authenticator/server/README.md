# Cyberdeck Login Server

Node.js BLE server that handles authentication requests from the iOS app.

## Prerequisites

- Docker and Docker Compose (for production)
- Node.js 18+ (for development)
- Bluetooth 4.0+ adapter (or use proxy mode for VMs)
- Linux system with D-Bus (for lock screen monitoring)

## Quick Start

1. **Configure environment**

   ```bash
   cp .env.example .env
   nano .env
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Start the server**

   ```bash
   npm run dev
   ```

## Configuration

### Environment Variables (`.env`)

```bash
# Path to config.json
CONFIG_PATH=./data/config.json

# Directory for captured public keys during registration
PUBLIC_KEYS_DIR=./data/publicKeys

# Computer name shown in BLE advertisement
COMPUTER_NAME=cyberdeck

# Linux user to log in
LOGIN_USER=pi

# BLE Mode: 'native' for real Bluetooth, 'tcp' for proxy mode
BLE_MODE=native

# TCP port for proxy mode (only used when BLE_MODE=tcp)
TCP_PORT=3100
```

### Server Settings (`data/config.json`)

```json
{
  "computerName": "my-raspberry-pi",
  "loginUser": "pi",
  "nonceRotationIntervalMs": 30000
}
```

## Directory Structure

```
data/
├── config.json      # Server settings
├── publicKeys/      # Captured keys from registration attempts
│   └── <device-id>.json
└── registered/      # Approved devices (copy files here to enable)
    └── <device-id>.json
```

## Device Registration

Registration is always enabled. When an iPhone registers, its public key is saved to `publicKeys/`. To approve a device, copy its file to `registered/`.

1. **Register from iPhone app** (Settings → Register Device)
   
   Server logs:
   ```
   📝 Registration request from: Jonathan's iPhone
   📝 Captured public key saved to ./data/publicKeys/ABC123.json
      To register: cp ./data/publicKeys/ABC123.json ./data/registered/
   ```

2. **Review the captured key**

   ```bash
   cat data/publicKeys/ABC123.json
   ```

3. **Approve the device**

   ```bash
   cp data/publicKeys/ABC123.json data/registered/
   ```

   Server auto-detects and logs:
   ```
   🔑 1 registered device(s) in ./data/registered
      ✨ New device(s) added!
   ```

4. **Revoke a device**

   ```bash
   rm data/registered/ABC123.json
   ```

   Server logs:
   ```
   🔑 0 registered device(s) in ./data/registered
      🗑️  Device(s) removed
   ```

## Proxy Mode (for VMs)

If running in a VM without Bluetooth access, use proxy mode. A Mac with Bluetooth acts as a BLE bridge.

### Architecture

```
iPhone ←→ BLE ←→ Mac (proxy) ←→ WebSocket ←→ VM (server)
```

### Setup

**On the VM:**

```bash
# Set proxy mode in .env
echo "BLE_MODE=tcp" >> .env
echo "TCP_PORT=3100" >> .env

# Start server
npm run dev
```

Output:
```
📡 BLE Mode: tcp
📡 WebSocket server listening on port 3100
✅ Cyberdeck Login Server running (proxy mode)
   Waiting for proxy connection on port 3100...
```

**On the Mac:**

```bash
cd tools/ble-proxy
npm install
npm start -- --server <VM_IP>:3100
```

Output:
```
🔗 BLE Proxy - connecting to ws://<VM_IP>:3100
✅ Connected to server
🔗 Server ready
📡 Bluetooth: poweredOn
✅ BLE advertising - iPhone can now connect
```

Now the iPhone app will see "CyberdeckProxy" and can authenticate through the VM.

## BLE Service Details

### Service UUID: `CD10`

### Characteristics

| UUID | Name | Properties | Description |
|------|------|------------|-------------|
| `CD11` | Challenge | Read | Returns current challenge (nonce, timestamp, computerName) |
| `CD12` | Auth | Write | Accepts signed authentication response |
| `CD13` | Register | Write | Accepts public key registration |

### Challenge Format (JSON)

```json
{
  "nonce": "base64-encoded-32-byte-random",
  "timestamp": 1699999999999,
  "computerName": "my-raspberry-pi"
}
```

### Auth Request Format (JSON)

```json
{
  "signedNonce": "base64-encoded-ed25519-signature",
  "publicKey": "base64-encoded-public-key"
}
```

## Docker Deployment

```bash
docker-compose up -d
```

The container needs:
- Privileged mode (for Bluetooth)
- Host network (for BLE)
- Volume mounts for `/data` and D-Bus

## Troubleshooting

### Bluetooth not working

```bash
# Check Bluetooth status
bluetoothctl show

# Restart Bluetooth service
sudo systemctl restart bluetooth

# Verify adapter is visible
hciconfig
```

### D-Bus errors

```bash
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
npm run dev
```

### Lock screen not detected

The server supports:
- systemd-logind (via `loginctl`)
- GNOME Screensaver (via D-Bus)
- KDE Screensaver (via D-Bus)
- freedesktop.org Screensaver standard

### Proxy mode connection issues

```bash
# Check VM is reachable
ping <VM_IP>

# Check port is open
nc -zv <VM_IP> 3100

# Check server is listening
# On VM:
ss -tlnp | grep 3100
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   CyberdeckLoginServer              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Native Mode:           Proxy Mode:                 │
│  ┌─────────────┐        ┌─────────────┐            │
│  │BleAdvertiser│        │ WsBleServer │            │
│  │BlePeripheral│        │ (WebSocket) │            │
│  └──────┬──────┘        └──────┬──────┘            │
│         │                      │                    │
│  ┌──────┴──────────────────────┴──────┐            │
│  │            AuthService             │            │
│  │       (Ed25519 verification)       │            │
│  └──────────────────┬─────────────────┘            │
│                     │                               │
│  ┌──────────────────┴─────────────────┐            │
│  │           ConfigManager            │            │
│  │    (watches registered/ folder)    │            │
│  └──────────────────┬─────────────────┘            │
│                     │                               │
│  ┌──────────────────┴─────────────────┐            │
│  │             PamAuth                │            │
│  │      (trigger system login)        │            │
│  └────────────────────────────────────┘            │
└─────────────────────────────────────────────────────┘
```
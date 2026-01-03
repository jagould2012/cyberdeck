# Cyberdeck Login Server

Node.js BLE server that handles authentication requests from the iOS app.

## Prerequisites

- Docker and Docker Compose
- Bluetooth 4.0+ adapter
- Linux system with D-Bus (for lock screen monitoring)

## Quick Start

1. **Configure environment**

   Create a `.env` file:
   ```bash
   COMPUTER_NAME=my-raspberry-pi
   LOGIN_USER=pi
   ```

2. **Build and start**

   ```bash
   docker-compose up -d
   ```

3. **Check logs**

   ```bash
   docker-compose logs -f
   ```

## Configuration

Configuration is stored in `data/config.json`:

```json
{
  "computerName": "my-raspberry-pi",
  "loginUser": "pi",
  "nonceRotationIntervalMs": 30000,
  "registeredDevices": [
    {
      "name": "My iPhone",
      "publicKey": "base64-encoded-ed25519-public-key"
    }
  ]
}
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `computerName` | Name shown in BLE advertisement | `cyberdeck` |
| `loginUser` | Linux user to log in | `pi` |
| `nonceRotationIntervalMs` | How often to rotate the nonce | `30000` (30s) |
| `registeredDevices` | Array of registered device public keys | `[]` |

## Registering Devices

1. **Enter registration mode**

   ```bash
   # Option 1: Via docker exec
   docker exec cyberdeck-login-server node src/register-mode.js 60
   
   # Option 2: Via docker-compose
   docker-compose --profile registration up register
   ```

2. **On your iPhone**, open the Cyberdeck Login app and go to Settings → Register Device

3. **Check captured keys**

   ```bash
   ls data/publicKeys/
   cat data/publicKeys/<device-id>.json
   ```

4. **Add to config.json**

   Copy the public key to the `registeredDevices` array:
   
   ```json
   {
     "registeredDevices": [
       {
         "name": "My iPhone 15",
         "publicKey": "<the-captured-public-key>"
       }
     ]
   }
   ```

5. **Restart the server**

   ```bash
   docker-compose restart
   ```

## BLE Service Details

### Service UUID: `cd10`

### Characteristics

| UUID | Name | Properties | Description |
|------|------|------------|-------------|
| `cd11` | Challenge | Read | Returns current challenge (nonce, timestamp, computerName) |
| `cd12` | Auth | Write | Accepts signed authentication response |
| `cd13` | Register | Write | Accepts public key during registration mode |

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

The `signedNonce` is the Ed25519 signature of:
```json
{
  "nonce": "<nonce-from-challenge>",
  "timestamp": <current-timestamp>
}
```

## Troubleshooting

### Bluetooth not working

```bash
# Check Bluetooth status
bluetoothctl show

# Restart Bluetooth service
sudo systemctl restart bluetooth

# Check container can see Bluetooth
docker exec cyberdeck-login-server hciconfig
```

### D-Bus errors

Make sure to pass the D-Bus session address:

```bash
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
docker-compose up -d
```

### Lock screen not detected

The server supports multiple methods:
- systemd-logind (via `loginctl`)
- GNOME Screensaver (via D-Bus)
- KDE Screensaver (via D-Bus)
- freedesktop.org Screensaver standard

For headless systems or unusual setups, you may need to manually configure lock detection.

## Development

Run without Docker:

```bash
npm install
npm run dev
```

Run tests:

```bash
npm test
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   CyberdeckLoginServer              │
├─────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │ BleAdvertiser│  │BlePeripheral│  │LockMonitor │  │
│  │ (advertising)│  │(GATT server)│  │(D-Bus/idle)│  │
│  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘  │
│         │                │               │          │
│  ┌──────┴────────────────┴───────────────┴──────┐  │
│  │              NonceManager                     │  │
│  │         (nonce generation/validation)        │  │
│  └──────────────────────┬───────────────────────┘  │
│                         │                           │
│  ┌──────────────────────┴───────────────────────┐  │
│  │              AuthService                      │  │
│  │         (Ed25519 verification)               │  │
│  └──────────────────────┬───────────────────────┘  │
│                         │                           │
│  ┌──────────────────────┴───────────────────────┐  │
│  │              ConfigManager                    │  │
│  │         (device registration)                │  │
│  └──────────────────────┬───────────────────────┘  │
│                         │                           │
│  ┌──────────────────────┴───────────────────────┐  │
│  │              PamAuth                          │  │
│  │         (trigger system login)               │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```
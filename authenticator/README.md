# Cyberdeck Login

A BLE-based remote authentication system for Raspberry Pi computers. Authenticate to your devices from your iPhone without typing passwords.

## Overview

Cyberdeck Login allows you to unlock your Raspberry Pi (or other Linux) computers remotely via Bluetooth Low Energy (BLE). The system uses public key cryptography to ensure secure, passwordless authentication.

### How It Works

1. **Server** advertises via BLE when the device is locked/away, broadcasting:
   - Computer name
   - Random nonce (changes frequently)
   - Timestamp

2. **iPhone App** detects the advertisement, signs the nonce with its private key, and sends back the signed response via BLE

3. **Server** verifies the signature against registered public keys and triggers PAM login for the configured user

### Security Features

- **Public Key Cryptography**: Ed25519 signatures for authentication
- **Nonce-based**: Fresh nonce for each authentication attempt
- **Replay Attack Prevention**: Nonces are invalidated immediately after use and rotate frequently
- **No Password Transmission**: Only cryptographic signatures are exchanged

## Project Structure

```
cyberdeck-login/
├── README.md           # This file
├── server/             # Node.js BLE server
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── package.json
│   └── src/
├── config/             # PAM configuration and scripts
│   └── README.md
└── app/                # iOS Swift app example code
    └── README.md
```

## Quick Start

### 1. Set Up the Server

```bash
cd server
docker-compose up -d
```

### 2. Configure PAM

Follow the instructions in `config/README.md` to install the PAM module.

### 3. Register Your iPhone

1. Put the server in registration mode:
   ```bash
   docker exec cyberdeck-login-server node register-mode.js
   ```

2. In the iOS app, go to Settings → Register Device

3. The server will capture your public key in the `publicKeys/` directory

4. Manually move the key to `config.json`:
   ```bash
   # Review the captured key
   cat data/publicKeys/<device-id>.json
   
   # Add it to config.json registered devices
   ```

### 4. Test Authentication

Lock your Raspberry Pi and use the iOS app to authenticate!

## Configuration

### Server Configuration (`data/config.json`)

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

### Volume Mounts

The server expects a `data/` volume containing:
- `config.json` - Main configuration
- `publicKeys/` - Directory for captured public keys during registration

## Requirements

### Server (Raspberry Pi)
- Docker and Docker Compose
- Bluetooth 4.0+ adapter
- Linux with PAM support

### iOS App
- iOS 14.0+
- iPhone with Bluetooth

## Security Considerations

1. **Physical Security**: The server must be physically secured as it can bypass password authentication

2. **Key Management**: Protect your private keys on both server and mobile device

3. **Registration Mode**: Only enable registration mode when actively pairing a new device

4. **Network**: BLE has limited range (~10m), providing implicit proximity verification

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please read CONTRIBUTING.md before submitting PRs.
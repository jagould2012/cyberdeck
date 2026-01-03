
# Cyberdeck Login iOS App

Example Swift code for the Cyberdeck Login iOS app.

## Overview

This directory contains example Swift code demonstrating the core functionality needed for the iOS app. You will need to create an Xcode project and integrate this code.

## Project Setup

1. Create a new iOS project in Xcode
   - Product Name: `Cyberdeck Login`
   - Bundle Identifier: `com.yourcompany.cyberdeck-login`
   - Language: Swift
   - Minimum iOS: 14.0

2. Add required capabilities in Xcode:
   - Background Modes → Uses Bluetooth LE accessories
   - Background Modes → Acts as a Bluetooth LE accessory (for registration)

3. Add to Info.plist:
   ```xml
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>Cyberdeck Login uses Bluetooth to authenticate with your devices</string>
   <key>NSBluetoothPeripheralUsageDescription</key>
   <string>Cyberdeck Login uses Bluetooth to authenticate with your devices</string>
   ```

4. Copy the Swift files from this directory into your project

## File Structure

```
app/
├── README.md                 # This file
├── CyberdeckLoginApp.swift   # Main app entry point
├── Models/
│   ├── Device.swift          # Device model
│   └── KeyPair.swift         # Cryptographic key pair
├── Services/
│   ├── BLEManager.swift      # Bluetooth LE manager
│   ├── CryptoService.swift   # Ed25519 signing
│   └── KeychainService.swift # Secure key storage
├── Views/
│   ├── ContentView.swift     # Main view
│   ├── DeviceListView.swift  # Nearby devices list
│   ├── DeviceDetailView.swift# Single device view
│   └── SettingsView.swift    # Settings & registration
└── ViewModels/
    └── DeviceViewModel.swift # Device state management
```

## Core Components

### BLE Service UUIDs

```swift
let CYBERDECK_SERVICE_UUID = CBUUID(string: "CD10")
let CHALLENGE_CHAR_UUID = CBUUID(string: "CD11")
let AUTH_CHAR_UUID = CBUUID(string: "CD12")
let REGISTER_CHAR_UUID = CBUUID(string: "CD13")
```

### Authentication Flow

1. **Discover** nearby Cyberdeck devices (scanning for `CD10` service)
2. **Connect** to the device
3. **Read** the challenge from `CD11` characteristic (nonce + timestamp)
4. **Sign** the challenge with device's Ed25519 private key
5. **Write** signed response to `CD12` characteristic
6. **Receive** success/failure result

### Key Management

- Keys are generated using Ed25519 (via CryptoKit on iOS 13+ or TweetNaCl)
- Private key stored securely in iOS Keychain
- Public key can be exported for registration

## Dependencies

The example code uses only Apple frameworks:
- `CoreBluetooth` - BLE communication
- `CryptoKit` - Ed25519 signing (iOS 13+)
- `Security` - Keychain access

## Building

1. Open your Xcode project
2. Copy the Swift files into your project
3. Build and run on a physical device (BLE doesn't work in simulator)

## Usage

### First Time Setup

1. Open the app
2. Go to Settings → Generate Keys (if not already done)
3. Put your Raspberry Pi server in registration mode
4. Tap "Register Device" in the app
5. Wait for registration confirmation

### Authentication

1. Lock your Raspberry Pi
2. Open the app on your iPhone
3. The device should appear in the list
4. Tap to authenticate
5. Your Raspberry Pi should unlock!

## Troubleshooting

### Device not appearing
- Ensure Bluetooth is enabled on both devices
- Check that the server is running and in locked state
- Verify BLE advertising is working

### Authentication failing
- Check that your public key is registered in config.json
- Verify system clocks are synchronized (within 60 seconds)
- Check server logs for detailed error messages

### Keys not generating
- Ensure the app has Keychain access
- Try deleting and regenerating keys in Settings

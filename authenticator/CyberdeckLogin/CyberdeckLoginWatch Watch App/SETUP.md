# Apple Watch Support Setup

## Adding Watch Target to Xcode Project

### 1. Create Watch Target

1. Open `CyberdeckLogin.xcodeproj` in Xcode
2. File → New → Target
3. Select **watchOS** → **App**
4. Configure:
   - Product Name: `CyberdeckLogin Watch App`
   - Bundle Identifier: `com.yourcompany.CyberdeckLogin.watchkitapp`
   - Language: Swift
   - User Interface: SwiftUI
   - Watch App Type: **Watch App** (not Watch App for iOS App)
   - Include Notification Scene: No (optional)
5. Click **Finish**

### 2. Add Watch Files

Copy the Watch files to the Watch target:

```
app/Watch/
├── CyberdeckLoginWatchApp.swift   (replace generated App file)
├── PhoneConnectivityService.swift
├── WatchDevice.swift
├── WatchContentView.swift
└── WatchDeviceDetailView.swift
```

Add each file to the Watch target (select the Watch target in File Inspector).

### 3. Add WatchConnectivity to iPhone App

1. Add `WatchConnectivityService.swift` to the **iPhone target**
2. Initialize it in `CyberdeckLoginApp.swift`:

```swift
import SwiftUI

@main
struct CyberdeckLoginApp: App {
    @StateObject private var bleManager = BLEManager()
    
    init() {
        // Configure Watch connectivity
        WatchConnectivityService.shared.configure(bleManager: BLEManager())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
        }
    }
}
```

### 4. Configure Capabilities

#### iPhone Target:
1. Select iPhone target → Signing & Capabilities
2. Add **Background Modes**:
   - Uses Bluetooth LE accessories
   - Background fetch (optional)

#### Watch Target:
1. Select Watch target → Signing & Capabilities
2. No special capabilities needed (WatchConnectivity is automatic)

### 5. Update Info.plist (if needed)

The Watch app doesn't need Bluetooth permissions since it communicates through the iPhone.

### 6. App Groups (Optional - for shared data)

If you want to share data between iPhone and Watch via UserDefaults:

1. Add **App Groups** capability to both targets
2. Use the same group identifier: `group.com.yourcompany.CyberdeckLogin`

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│   Apple Watch   │         │     iPhone      │
├─────────────────┤         ├─────────────────┤
│                 │         │                 │
│  WatchContent   │◄──WC───►│   BLEManager    │
│      View       │         │                 │
│        │        │         │        │        │
│        ▼        │         │        ▼        │
│  PhoneConnect   │         │  WatchConnect   │
│    Service      │         │    Service      │
│                 │         │        │        │
└─────────────────┘         │        ▼        │
                            │   Cyberdeck     │
                            │   (via BLE)     │
                            └─────────────────┘

WC = WatchConnectivity Framework
```

## Communication Flow

### Getting Devices
1. Watch sends `getDevices` message
2. iPhone replies with array of discovered devices
3. Watch displays device list

### Authentication
1. User taps "Unlock" on Watch
2. Watch sends `authenticate` message with deviceId
3. iPhone:
   - Connects to device (if needed)
   - Performs BLE authentication
   - Signs challenge with private key
4. iPhone sends result back to Watch
5. Watch shows success/failure with haptic feedback

## Testing

1. Run iPhone app on device
2. Run Watch app on paired Apple Watch or simulator
3. iPhone must be running for Watch to work
4. Test with Watch simulator: iPhone Simulator can pair with Watch Simulator

## Notes

- Watch cannot do BLE directly for this use case (needs iPhone)
- Authentication requires iPhone to be reachable
- Watch app shows cached device list when iPhone is briefly unreachable
- Haptic feedback confirms authentication result

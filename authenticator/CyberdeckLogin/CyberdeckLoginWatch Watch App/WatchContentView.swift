import SwiftUI

struct WatchContentView: View {
    @StateObject private var bleManager = WatchBLEManager()
    @StateObject private var keyManager = WatchKeyManager.shared
    @EnvironmentObject var connectivityService: PhoneConnectivityService
    
    var body: some View {
        NavigationView {
            Group {
                if !keyManager.hasKeyPair {
                    KeySyncView()
                } else if !bleManager.isBluetoothEnabled {
                    BluetoothDisabledView()
                } else if bleManager.discoveredDevices.isEmpty && !bleManager.isScanning {
                    NoDevicesView(onScan: { bleManager.startScanning() })
                } else {
                    DeviceListView(bleManager: bleManager)
                }
            }
        }
    }
}

struct KeySyncView: View {
    @EnvironmentObject var connectivityService: PhoneConnectivityService
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            
            Text("Setup Required")
                .font(.headline)
            
            Text("Sync key from iPhone")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                connectivityService.requestKeySync()
            }) {
                Text("Sync Key")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!connectivityService.isPhoneReachable)
            
            if !connectivityService.keySyncStatus.isEmpty {
                Text(connectivityService.keySyncStatus)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !connectivityService.isPhoneReachable {
                Text("Open iPhone app")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct BluetoothDisabledView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 36))
                .foregroundColor(.red)
            
            Text("Bluetooth Off")
                .font(.headline)
            
            Text("Enable in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct NoDevicesView: View {
    let onScan: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            
            Text("No Devices")
                .font(.headline)
            
            Button(action: onScan) {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct DeviceListView: View {
    @ObservedObject var bleManager: WatchBLEManager
    
    var body: some View {
        List {
            if bleManager.isScanning {
                HStack {
                    ProgressView()
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ForEach(bleManager.discoveredDevices) { device in
                NavigationLink(destination: WatchDeviceDetailView(device: device, bleManager: bleManager)) {
                    DeviceRowView(device: device)
                }
            }
            
            Button(action: { bleManager.startScanning() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
            .disabled(bleManager.isScanning)
        }
    }
}

struct DeviceRowView: View {
    let device: WatchDevice
    
    var body: some View {
        HStack {
            Image(systemName: "desktopcomputer")
                .foregroundColor(device.isConnected ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(device.isConnected ? "Connected" : "Available")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WatchContentView()
        .environmentObject(PhoneConnectivityService.shared)
}

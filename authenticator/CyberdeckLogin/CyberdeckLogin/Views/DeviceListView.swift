import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Binding var selectedDevice: CyberdeckDevice?
    
    var body: some View {
        VStack {
            // Scanning controls
            HStack {
                if bleManager.isScanning {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Scanning...")
                        .foregroundColor(.secondary)
                } else {
                    Text("\(bleManager.discoveredDevices.count) device(s) found")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    if bleManager.isScanning {
                        bleManager.stopScanning()
                    } else {
                        bleManager.startScanning()
                    }
                }) {
                    Text(bleManager.isScanning ? "Stop" : "Scan")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if bleManager.discoveredDevices.isEmpty && !bleManager.isScanning {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Devices Found")
                        .font(.headline)
                    
                    Text("Make sure your device is locked and nearby")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Start Scanning") {
                        bleManager.startScanning()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                // Device list
                List(bleManager.discoveredDevices, selection: $selectedDevice) { device in
                    NavigationLink(value: device) {
                        DeviceRow(device: device)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear {
            // Start scanning when view appears
            if !bleManager.isScanning && bleManager.discoveredDevices.isEmpty {
                bleManager.startScanning()
            }
        }
    }
}

struct DeviceRow: View {
    let device: CyberdeckDevice
    
    var signalStrength: String {
        switch device.rssi {
        case -50...0:
            return "wifi"
        case -70 ... -51:
            return "wifi"
        case -90 ... -71:
            return "wifi"
        default:
            return "wifi.exclamationmark"
        }
    }
    
    var signalBars: Int {
        switch device.rssi {
        case -50...0:
            return 3
        case -70 ... -51:
            return 2
        case -90 ... -71:
            return 1
        default:
            return 0
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "desktopcomputer")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                
                Text("Last seen: \(device.lastSeen, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: signalStrength)
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}

struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DeviceListView(selectedDevice: .constant(nil))
                .environmentObject(BLEManager())
        }
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var cryptoService: CryptoService
    
    @State private var showingSettings = false
    @State private var selectedDevice: CyberdeckDevice?
    
    var body: some View {
        NavigationSplitView {
            VStack {
                if !cryptoService.hasKeyPair {
                    // No key pair - show setup prompt
                    NoKeyPairView(showingSettings: $showingSettings)
                } else if !bleManager.isBluetoothEnabled {
                    // Bluetooth not available
                    BluetoothDisabledView()
                } else {
                    // Main device list
                    DeviceListView(selectedDevice: $selectedDevice)
                }
            }
            .navigationTitle("Cyberdeck Login")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        } detail: {
            if let device = selectedDevice {
                DeviceDetailView(device: device, selectedDevice: $selectedDevice)
            } else {
                Text("Select a device")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct NoKeyPairView: View {
    @Binding var showingSettings: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Setup Required")
                .font(.title)
            
            Text("Generate a key pair to start using Cyberdeck Login")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: { showingSettings = true }) {
                Label("Go to Settings", systemImage: "gear")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct BluetoothDisabledView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Bluetooth Disabled")
                .font(.title)
            
            Text("Please enable Bluetooth in Settings to scan for devices")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BLEManager())
            .environmentObject(CryptoService())
    }
}

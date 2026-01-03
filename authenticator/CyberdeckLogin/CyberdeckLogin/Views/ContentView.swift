import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var cryptoService: CryptoService
    
    @State private var showingSettings = false
    @State private var selectedDevice: CyberdeckDevice?
    
    var body: some View {
        NavigationSplitView {
            Group {
                if !cryptoService.hasKeyPair {
                    NoKeyPairView(showingSettings: $showingSettings)
                } else if !bleManager.isBluetoothEnabled {
                    BluetoothDisabledView()
                } else {
                    DeviceListView(selectedDevice: $selectedDevice)
                }
            }
            .background(
                Image("Background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            )
            .navigationTitle("Cyberdeck Login")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .foregroundColor(CyberdeckTheme.matrixGreen)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        } detail: {
            Group {
                if let device = selectedDevice {
                    DeviceDetailView(device: device, selectedDevice: $selectedDevice)
                } else {
                    VStack {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 64))
                            .foregroundColor(CyberdeckTheme.matrixGreen.opacity(0.5))
                        Text("Select a device")
                            .font(.title2)
                            .foregroundColor(Color(white: 0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.05))
        }
        .tint(CyberdeckTheme.matrixGreen)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BLEManager())
            .environmentObject(CryptoService())
    }
}

struct NoKeyPairView: View {
    @Binding var showingSettings: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(CyberdeckTheme.matrixGreen)
            
            Text("Setup Required")
                .font(.title)
            
            Text("Generate a key pair to start using Cyberdeck Login")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: { showingSettings = true }) {
                Label("Go to Settings", systemImage: "gear")
                    .padding()
                    .background(CyberdeckTheme.matrixGreen)
                    .foregroundColor(.black)
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

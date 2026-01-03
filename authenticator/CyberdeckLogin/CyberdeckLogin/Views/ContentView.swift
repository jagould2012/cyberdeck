import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var cryptoService: CryptoService
    
    @State private var showingSettings = false
    @State private var selectedDevice: CyberdeckDevice?
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showDetailBackground = true
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            .background(
                Group {
                    if isIPad && !showDetailBackground {
                        Color.black.ignoresSafeArea()
                    } else {
                        Image("Background")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .ignoresSafeArea()
                    }
                }
            )
            .onAppear {
                if isIPad {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showDetailBackground = false
                    }
                }
            }
        }
        .tint(CyberdeckTheme.matrixGreen)
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
                .foregroundColor(.white)
            
            Text("Generate a key pair to start using Cyberdeck Login")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(white: 0.6))
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
                .foregroundColor(.white)
            
            Text("Please enable Bluetooth in Settings to scan for devices")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(white: 0.6))
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

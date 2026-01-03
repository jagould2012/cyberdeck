import SwiftUI

struct WatchDeviceDetailView: View {
    let device: WatchDevice
    @EnvironmentObject var connectivityService: PhoneConnectivityService
    @State private var showingResult = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Device icon and name
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
                
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(device.isConnected ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(device.isConnected ? "Connected" : "Available")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Authenticate button or progress
                if connectivityService.isAuthenticating {
                    ProgressView()
                        .padding(.top, 8)
                } else {
                    Button(action: authenticate) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("Unlock")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding(.top, 8)
                }
                
                // Result display
                if let result = connectivityService.lastAuthResult, result.deviceId == device.id {
                    AuthResultView(result: result)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Unlock")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: connectivityService.lastAuthResult?.deviceId) { _ in
            if connectivityService.lastAuthResult?.deviceId == device.id {
                WKInterfaceDevice.current().play(
                    connectivityService.lastAuthResult?.success == true ? .success : .failure
                )
            }
        }
    }
    
    private func authenticate() {
        WKInterfaceDevice.current().play(.click)
        connectivityService.authenticate(deviceId: device.id)
    }
}

struct AuthResultView: View {
    let result: PhoneConnectivityService.AuthResult
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            Text(result.success ? "Unlocked!" : (result.error ?? "Failed"))
                .font(.caption2)
                .foregroundColor(result.success ? .green : .red)
                .lineLimit(1)
        }
        .padding(.top, 4)
    }
}

#Preview {
    WatchDeviceDetailView(device: WatchDevice(id: "test", name: "cyberdeck-pi1", isConnected: true))
        .environmentObject(PhoneConnectivityService.shared)
}

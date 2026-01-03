import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var cryptoService: CryptoService
    @Environment(\.dismiss) var dismiss
    
    let device: CyberdeckDevice
    @Binding var selectedDevice: CyberdeckDevice?
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var userCancelled = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Device info
            VStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text(device.name)
                    .font(.title)
                
                Text("Signal: \(device.rssi) dBm")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            
            // Status indicator
            statusView
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                if bleManager.authenticationState == .success {
                    successView
                } else if isAuthenticating {
                    cancelButton
                } else {
                    authenticateButton
                }
            }
            .padding(.bottom, 32)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isAuthenticating)
        .toolbar {
            if isAuthenticating {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelAuthentication()
                    }
                }
            }
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Connect when view appears
            if bleManager.connectedDevice?.id != device.id {
                bleManager.connect(to: device)
            }
        }
        .onDisappear {
            // Disconnect when leaving
            if bleManager.authenticationState != .success {
                bleManager.disconnect()
            }
        }
        .onChange(of: bleManager.connectedDevice) { oldValue, newValue in
            // Auto-reconnect if disconnected while still on this view (unless user cancelled)
            if oldValue != nil && newValue == nil && !userCancelled && bleManager.authenticationState != .success {
                print("🔄 Auto-reconnecting after disconnect...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !userCancelled {
                        bleManager.connect(to: device)
                    }
                }
            }
        }
        .onChange(of: bleManager.authenticationState) { oldValue, newValue in
            // Auto-reconnect on failure (unless user cancelled)
            if case .failed(_) = newValue, !userCancelled {
                print("🔄 Auth failed, will reconnect...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !userCancelled {
                        bleManager.connect(to: device)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    var statusView: some View {
        HStack {
            switch bleManager.authenticationState {
            case .idle:
                Image(systemName: "circle")
                Text("Ready")
            case .connecting:
                ProgressView()
                Text("Connecting...")
            case .readingChallenge:
                ProgressView()
                Text("Reading challenge...")
            case .signing:
                ProgressView()
                Text("Signing...")
            case .authenticating:
                ProgressView()
                Text("Authenticating...")
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Authenticated!")
            case .failed(let message):
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Failed: \(message)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    var authenticateButton: some View {
        Button(action: authenticate) {
            HStack {
                Image(systemName: "lock.open.fill")
                Text("Authenticate")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(bleManager.connectedDevice == nil ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(bleManager.connectedDevice == nil)
    }
    
    var cancelButton: some View {
        Button(action: cancelAuthentication) {
            HStack {
                Image(systemName: "xmark.circle")
                Text("Cancel")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
    }
    
    var disconnectButton: some View {
        Button(action: { bleManager.disconnect() }) {
            HStack {
                Image(systemName: "xmark.circle")
                Text("Disconnect")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
    }
    
    var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Successfully Authenticated!")
                .font(.headline)
            
            Text("Your device should now be unlocked")
                .foregroundColor(.secondary)
        }
        .onAppear {
            // Auto-reset after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if bleManager.authenticationState == .success {
                    bleManager.authenticationState = .idle
                }
            }
        }
    }
    
    var isAuthenticating: Bool {
        switch bleManager.authenticationState {
        case .connecting, .readingChallenge, .signing, .authenticating:
            return true
        default:
            return false
        }
    }
    
    func authenticate() {
        userCancelled = false
        bleManager.authenticate(using: cryptoService) { success, error in
            if !success {
                errorMessage = error ?? "Unknown error"
                showingError = true
            }
        }
    }
    
    func cancelAuthentication() {
        userCancelled = true
        bleManager.disconnect()
        selectedDevice = nil
    }
}

// Preview requires a real CBPeripheral which can't be mocked easily
// Test on device or use a mock wrapper
#if DEBUG
struct DeviceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview placeholder - actual testing requires a real device
        Text("DeviceDetailView Preview - Test on device")
            .environmentObject(BLEManager())
            .environmentObject(CryptoService())
    }
}
#endif

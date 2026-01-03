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
                    .foregroundColor(CyberdeckTheme.matrixGreen)
                
                Text(device.name)
                    .font(.title)
                    .foregroundColor(.white)
                
                Text("Signal: \(device.rssi) dBm")
                    .foregroundColor(Color(white: 0.6))
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
            if bleManager.connectedDevice?.id != device.id {
                bleManager.connect(to: device)
            }
        }
        .onDisappear {
            if bleManager.authenticationState != .success {
                bleManager.disconnect()
            }
        }
        .onChange(of: bleManager.connectedDevice) { oldValue, newValue in
            if oldValue != nil && newValue == nil && !userCancelled && bleManager.authenticationState != .success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !userCancelled {
                        bleManager.connect(to: device)
                    }
                }
            }
        }
        .onChange(of: bleManager.authenticationState) { oldValue, newValue in
            if case .failed(_) = newValue, !userCancelled {
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
                    .foregroundColor(Color(white: 0.6))
                Text("Ready")
                    .foregroundColor(Color(white: 0.6))
            case .connecting:
                ProgressView()
                    .tint(CyberdeckTheme.matrixGreen)
                Text("Connecting...")
                    .foregroundColor(.white)
            case .readingChallenge:
                ProgressView()
                    .tint(CyberdeckTheme.matrixGreen)
                Text("Reading challenge...")
                    .foregroundColor(.white)
            case .signing:
                ProgressView()
                    .tint(CyberdeckTheme.matrixGreen)
                Text("Signing...")
                    .foregroundColor(.white)
            case .authenticating:
                ProgressView()
                    .tint(CyberdeckTheme.matrixGreen)
                Text("Authenticating...")
                    .foregroundColor(.white)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(CyberdeckTheme.matrixGreen)
                Text("Authenticated!")
                    .foregroundColor(CyberdeckTheme.matrixGreen)
            case .failed(let message):
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Failed: \(message)")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(white: 0.12).opacity(0.8))
        .cornerRadius(12)
    }
    
    var authenticateButton: some View {
        Button(action: authenticate) {
            HStack {
                Image(systemName: "lock.open.fill")
                Text("Unlock")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(bleManager.connectedDevice == nil ? Color(white: 0.3) : CyberdeckTheme.matrixGreen)
            .foregroundColor(bleManager.connectedDevice == nil ? Color(white: 0.6) : .black)
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
            .background(Color(white: 0.2))
            .foregroundColor(.white)
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
            .background(Color(white: 0.2))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(CyberdeckTheme.matrixGreen)
            
            Text("Successfully Authenticated!")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Your device should now be unlocked")
                .foregroundColor(Color(white: 0.6))
        }
        .onAppear {
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

#if DEBUG
struct DeviceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Text("DeviceDetailView Preview - Test on device")
            .environmentObject(BLEManager())
            .environmentObject(CryptoService())
    }
}
#endif

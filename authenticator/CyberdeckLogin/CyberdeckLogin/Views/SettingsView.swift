import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var cryptoService: CryptoService
    @Environment(\.dismiss) var dismiss
    
    @State private var showingDeleteConfirmation = false
    @State private var showingRegistration = false
    @State private var registrationStatus: RegistrationStatus = .idle
    @State private var showingCopiedAlert = false
    
    enum RegistrationStatus {
        case idle
        case scanning
        case connecting
        case registering
        case success
        case failed(String)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Key Management
                Section(header: Text("Key Management")) {
                    if cryptoService.hasKeyPair {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Public Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(cryptoService.publicKeyBase64 ?? "Unknown")
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: copyPublicKey) {
                            Label("Copy Public Key", systemImage: "doc.on.doc")
                        }
                        
                        Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                            Label("Delete Key Pair", systemImage: "trash")
                        }
                    } else {
                        Button(action: generateKeys) {
                            Label("Generate Key Pair", systemImage: "key.fill")
                        }
                    }
                }
                
                // Device Registration
                Section(header: Text("Device Registration")) {
                    if cryptoService.hasKeyPair {
                        Button(action: { showingRegistration = true }) {
                            Label("Register with Device", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .disabled(!bleManager.isBluetoothEnabled)
                    } else {
                        Text("Generate a key pair first")
                            .foregroundColor(.secondary)
                    }
                }
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/yourcompany/cyberdeck-login")!) {
                        Label("View on GitHub", systemImage: "link")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Key Pair?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    _ = cryptoService.deleteKeyPair()
                }
            } message: {
                Text("This will permanently delete your key pair. You will need to re-register with all devices.")
            }
            .alert("Copied!", isPresented: $showingCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Public key copied to clipboard")
            }
            .sheet(isPresented: $showingRegistration) {
                RegistrationView(status: $registrationStatus)
            }
        }
    }
    
    func generateKeys() {
        _ = cryptoService.generateKeyPair()
    }
    
    func copyPublicKey() {
        if let key = cryptoService.publicKeyBase64 {
            UIPasteboard.general.string = key
            showingCopiedAlert = true
        }
    }
}

struct RegistrationView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var cryptoService: CryptoService
    @Environment(\.dismiss) var dismiss
    
    @Binding var status: SettingsView.RegistrationStatus
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                statusView
                
                Spacer()
                
                instructionsView
                
                Spacer()
                
                if case .success = status {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                } else if case .failed = status {
                    Button("Try Again") {
                        status = .idle
                        startRegistration()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Register Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                startRegistration()
            }
            .onDisappear {
                bleManager.disconnect()
            }
        }
    }
    
    @ViewBuilder
    var statusView: some View {
        VStack(spacing: 16) {
            switch status {
            case .idle, .scanning:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Scanning for devices...")
                
            case .connecting:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Connecting...")
                
            case .registering:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Registering...")
                
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                Text("Registration Successful!")
                    .font(.headline)
                Text("Your public key has been sent to the server.\nAsk an admin to approve it in config.json")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
            case .failed(let error):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                Text("Registration Failed")
                    .font(.headline)
                Text(error)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var instructionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions:")
                .font(.headline)
            
            HStack(alignment: .top) {
                Text("1.")
                Text("Put your server in registration mode")
            }
            
            HStack(alignment: .top) {
                Text("2.")
                Text("Make sure Bluetooth is enabled on both devices")
            }
            
            HStack(alignment: .top) {
                Text("3.")
                Text("Stay near your device during registration")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    func startRegistration() {
        status = .scanning
        bleManager.startScanning()
        
        // Wait for device discovery then connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if let device = bleManager.discoveredDevices.first {
                status = .connecting
                bleManager.connect(to: device)
                
                // Wait for connection then register
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    status = .registering
                    bleManager.register(using: cryptoService) { success, error in
                        if success {
                            status = .success
                        } else {
                            status = .failed(error ?? "Unknown error")
                        }
                    }
                }
            } else {
                status = .failed("No devices found. Make sure the server is in registration mode.")
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(BLEManager())
            .environmentObject(CryptoService())
    }
}

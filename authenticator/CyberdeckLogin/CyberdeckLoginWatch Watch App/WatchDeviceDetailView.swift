import SwiftUI
import WatchKit

struct WatchDeviceDetailView: View {
    let device: WatchDevice
    @ObservedObject var bleManager: WatchBLEManager
    
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
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Action button
                actionButton
                    .padding(.top, 8)
                
                // Error display
                if let error = bleManager.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 4)
        }
        .onChange(of: bleManager.authenticationState) { newState in
            if newState == .success {
                WKInterfaceDevice.current().play(.success)
            } else if case .failed(_) = newState {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
    
    private var statusColor: Color {
        switch bleManager.authenticationState {
        case .success:
            return .green
        case .failed(_):
            return .red
        default:
            return device.isConnected ? .green : .gray
        }
    }
    
    private var statusText: String {
        switch bleManager.authenticationState {
        case .connecting:
            return "Connecting..."
        case .readingChallenge, .signing, .authenticating:
            return "Authenticating..."
        case .success:
            return "Unlocked!"
        case .failed(let msg):
            return msg
        default:
            return device.isConnected ? "Connected" : "Available"
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch bleManager.authenticationState {
        case .idle:
            if device.isConnected || bleManager.connectedDevice?.id == device.id {
                Button(action: authenticate) {
                    HStack {
                        Image(systemName: "lock.open.fill")
                        Text("Unlock")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button(action: connect) {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            
        case .connecting, .readingChallenge, .signing, .authenticating:
            ProgressView()
            
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            
        case .failed(_):
            Button(action: connect) {
                Text("Retry")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func connect() {
        WKInterfaceDevice.current().play(.click)
        bleManager.connect(to: device)
    }
    
    private func authenticate() {
        WKInterfaceDevice.current().play(.click)
        bleManager.authenticate { success, error in
            // State is already updated via @Published
        }
    }
}

#Preview {
    WatchDeviceDetailView(
        device: WatchDevice(id: "test", name: "cyberdeck-pi1", isConnected: true),
        bleManager: WatchBLEManager()
    )
}

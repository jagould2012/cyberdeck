import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Binding var selectedDevice: CyberdeckDevice?
    
    var body: some View {
        List(bleManager.discoveredDevices, selection: $selectedDevice) { device in
            NavigationLink(value: device) {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.title2)
                        .foregroundColor(CyberdeckTheme.matrixGreen)
                    
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Last seen: \(device.lastSeen, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.6))
                    }
                    
                    Spacer()
                    
                    // Signal bars
                    HStack(spacing: 2) {
                        ForEach(0..<3) { bar in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(bar < signalBars(for: device) ? CyberdeckTheme.matrixGreen : Color.gray.opacity(0.3))
                                .frame(width: 4, height: CGFloat(6 + bar * 3))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color(white: 0.12).opacity(0.8))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, 12)
        .onAppear {
            if !bleManager.isScanning && bleManager.discoveredDevices.isEmpty {
                bleManager.startScanning()
            }
        }
    }
    
    func signalBars(for device: CyberdeckDevice) -> Int {
        switch device.rssi {
        case -50...0: return 3
        case -70 ... -51: return 2
        case -90 ... -71: return 1
        default: return 0
        }
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

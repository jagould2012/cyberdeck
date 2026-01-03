import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var connectivityService: PhoneConnectivityService
    
    var body: some View {
        NavigationView {
            Group {
                if !connectivityService.isPhoneReachable {
                    PhoneNotReachableView()
                } else if connectivityService.devices.isEmpty {
                    NoDevicesView(onRefresh: {
                        connectivityService.requestDevices()
                        connectivityService.requestStartScanning()
                    })
                } else {
                    DeviceListView()
                }
            }
            .navigationTitle("Cyberdeck")
        }
        .onAppear {
            if connectivityService.isPhoneReachable {
                connectivityService.requestDevices()
            }
        }
    }
}

struct PhoneNotReachableView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("iPhone Not Reachable")
                .font(.headline)
            
            Text("Open the Cyberdeck app on your iPhone")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct NoDevicesView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Devices")
                .font(.headline)
            
            Button(action: onRefresh) {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct DeviceListView: View {
    @EnvironmentObject var connectivityService: PhoneConnectivityService
    
    var body: some View {
        List {
            ForEach(connectivityService.devices) { device in
                NavigationLink(destination: WatchDeviceDetailView(device: device)) {
                    DeviceRowView(device: device)
                }
            }
        }
        .refreshable {
            connectivityService.requestDevices()
        }
    }
}

struct DeviceRowView: View {
    let device: WatchDevice
    
    var body: some View {
        HStack {
            Image(systemName: "desktopcomputer")
                .foregroundColor(device.isConnected ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(device.isConnected ? "Connected" : "Available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WatchContentView()
        .environmentObject(PhoneConnectivityService.shared)
}

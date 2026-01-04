import Foundation
import CoreBluetooth
import Combine

#if targetEnvironment(simulator)

/// Mock BLE Manager for simulator testing
/// Provides fake devices and simulated authentication flow
class MockBLEManager: ObservableObject {
    
    // MARK: - Published Properties (mirrors BLEManager)
    
    @Published var isScanning = false
    @Published var isBluetoothEnabled = true
    @Published var discoveredDevices: [CyberdeckDevice] = []
    @Published var connectedDevice: CyberdeckDevice?
    @Published var authenticationState: AuthState = .idle
    @Published var lastError: String?
    
    // MARK: - State (same as BLEManager)
    
    enum AuthState: Equatable {
        case idle
        case connecting
        case readingChallenge
        case signing
        case authenticating
        case success
        case failed(String)
    }
    
    // MARK: - Mock Data
    
    private var mockDevices: [CyberdeckDevice] = []
    
    // MARK: - Initialization
    
    init() {
        // Pre-create mock devices using a workaround for CBPeripheral requirement
        // We'll use a simplified approach with just the data we need
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard isBluetoothEnabled else {
            lastError = "Bluetooth is not enabled"
            return
        }
        
        isScanning = true
        discoveredDevices.removeAll()
        
        // Simulate discovering devices
        let mockData = [
            ("cyberdeck-pi1", -45),
            ("cyberdeck-pi2", -52),
            ("cyberdeck-testvm", -38)
        ]
        
        for (index, (name, rssi)) in mockData.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) { [weak self] in
                guard let self = self, self.isScanning else { return }
                
                // Create a mock device entry
                let device = MockCyberdeckDevice(name: name, rssi: rssi)
                self.discoveredDevices.append(device.asCyberdeckDevice)
            }
        }
        
        // Auto-stop after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    func connect(to device: CyberdeckDevice) {
        authenticationState = .connecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if let index = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                var updatedDevice = self.discoveredDevices[index]
                updatedDevice.isConnected = true
                self.discoveredDevices[index] = updatedDevice
                self.connectedDevice = updatedDevice
            }
            self.authenticationState = .idle
        }
    }
    
    func disconnect(from device: CyberdeckDevice) {
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            var updatedDevice = discoveredDevices[index]
            updatedDevice.isConnected = false
            discoveredDevices[index] = updatedDevice
        }
        if connectedDevice?.id == device.id {
            connectedDevice = nil
        }
    }
    
    func authenticate(using cryptoService: CryptoService, completion: @escaping (Bool, String?) -> Void) {
        guard connectedDevice != nil else {
            completion(false, "No device connected")
            return
        }
        
        // Simulate authentication flow
        authenticationState = .readingChallenge
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.authenticationState = .signing
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.authenticationState = .authenticating
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    // Always succeed in simulator
                    self?.authenticationState = .success
                    completion(true, nil)
                    
                    // Reset after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.authenticationState = .idle
                    }
                }
            }
        }
    }
    
    func register(using cryptoService: CryptoService, deviceName: String, completion: @escaping (Bool, String?) -> Void) {
        guard connectedDevice != nil else {
            completion(false, "No device connected")
            return
        }
        
        // Simulate registration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true, nil)
        }
    }
}

/// Helper to create mock devices without real CBPeripheral
private class MockCyberdeckDevice {
    let id: UUID
    let name: String
    let rssi: Int
    
    init(name: String, rssi: Int) {
        self.id = UUID()
        self.name = name
        self.rssi = rssi
    }
    
    var asCyberdeckDevice: CyberdeckDevice {
        // We need to create a CyberdeckDevice without a real peripheral
        // This requires modifying CyberdeckDevice to support mock initialization
        return CyberdeckDevice(mockId: id, name: name, rssi: rssi)
    }
}

#endif

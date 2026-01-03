import Foundation
import CoreBluetooth
import Combine

/// BLE service UUIDs for Cyberdeck Login (same as iPhone)
enum WatchCyberdeckBLE {
    static let serviceUUID = CBUUID(string: "CD10")
    static let challengeCharUUID = CBUUID(string: "CD11")
    static let authCharUUID = CBUUID(string: "CD12")
}

/// Manages Bluetooth LE communication with Cyberdeck devices on Apple Watch
class WatchBLEManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isScanning = false
    @Published var isBluetoothEnabled = false
    @Published var discoveredDevices: [WatchDevice] = []
    @Published var connectedDevice: WatchDevice?
    @Published var authenticationState: AuthState = .idle
    @Published var lastError: String?
    
    // MARK: - State
    
    enum AuthState: Equatable {
        case idle
        case connecting
        case readingChallenge
        case signing
        case authenticating
        case success
        case failed(String)
    }
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var currentPeripheral: CBPeripheral?
    private var challengeCharacteristic: CBCharacteristic?
    private var authCharacteristic: CBCharacteristic?
    
    private var authCompletion: ((Bool, String?) -> Void)?
    private var pendingChallenge: ChallengeData?
    
    struct ChallengeData: Codable {
        let nonce: String
        let timestamp: Int64
        let computerName: String
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        #if targetEnvironment(simulator)
        isBluetoothEnabled = true
        print("⌚ Watch: Running in simulator - using mock BLE")
        #else
        centralManager = CBCentralManager(delegate: self, queue: .main)
        #endif
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        #if targetEnvironment(simulator)
        startMockScanning()
        return
        #endif
        
        guard isBluetoothEnabled else {
            lastError = "Bluetooth is not enabled"
            return
        }
        
        isScanning = true
        discoveredDevices.removeAll()
        
        centralManager.scanForPeripherals(
            withServices: [WatchCyberdeckBLE.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Auto-stop scanning after 15 seconds (shorter for Watch battery)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        #if targetEnvironment(simulator)
        isScanning = false
        return
        #endif
        
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to device: WatchDevice) {
        #if targetEnvironment(simulator)
        mockConnect(to: device)
        return
        #endif
        
        guard let peripheral = device.peripheral else {
            lastError = "No peripheral"
            return
        }
        
        stopScanning()
        authenticationState = .connecting
        currentPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        #if targetEnvironment(simulator)
        resetState()
        return
        #endif
        
        if let peripheral = currentPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetState()
    }
    
    func authenticate(completion: @escaping (Bool, String?) -> Void) {
        #if targetEnvironment(simulator)
        mockAuthenticate(completion: completion)
        return
        #endif
        
        guard connectedDevice != nil else {
            completion(false, "No device connected")
            return
        }
        
        guard WatchKeyManager.shared.hasKeyPair else {
            completion(false, "No key pair - sync from iPhone first")
            return
        }
        
        authCompletion = completion
        authenticationState = .readingChallenge
        
        // Read challenge characteristic
        if let peripheral = currentPeripheral, let characteristic = challengeCharacteristic {
            peripheral.readValue(for: characteristic)
        } else {
            completion(false, "Not connected to device")
            authenticationState = .failed("Not connected")
        }
    }
    
    // MARK: - Simulator Mock Support
    
    #if targetEnvironment(simulator)
    private func startMockScanning() {
        isScanning = true
        discoveredDevices.removeAll()
        
        let mockData = [
            ("cyberdeck-pi1", -45),
            ("cyberdeck-pi2", -52),
            ("cyberdeck-testvm", -38)
        ]
        
        for (index, (name, rssi)) in mockData.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) { [weak self] in
                guard let self = self, self.isScanning else { return }
                
                let device = WatchDevice(
                    id: UUID().uuidString,
                    name: name,
                    isConnected: false,
                    peripheralIdentifier: nil,
                    peripheral: nil,
                    rssi: rssi
                )
                self.discoveredDevices.append(device)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isScanning = false
        }
    }
    
    private func mockConnect(to device: WatchDevice) {
        authenticationState = .connecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if let index = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[index].isConnected = true
                self.connectedDevice = self.discoveredDevices[index]
            }
            self.authenticationState = .idle
        }
    }
    
    private func mockAuthenticate(completion: @escaping (Bool, String?) -> Void) {
        guard connectedDevice != nil else {
            completion(false, "No device connected")
            return
        }
        
        authenticationState = .readingChallenge
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.authenticationState = .signing
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.authenticationState = .authenticating
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.authenticationState = .success
                    completion(true, nil)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.authenticationState = .idle
                    }
                }
            }
        }
    }
    #endif
    
    // MARK: - Private Methods
    
    private func resetState() {
        currentPeripheral = nil
        challengeCharacteristic = nil
        authCharacteristic = nil
        connectedDevice = nil
        pendingChallenge = nil
        authenticationState = .idle
    }
    
    private func handleChallengeReceived(_ data: Data) {
        guard let challenge = try? JSONDecoder().decode(ChallengeData.self, from: data) else {
            authCompletion?(false, "Invalid challenge format")
            authenticationState = .failed("Invalid challenge")
            return
        }
        
        pendingChallenge = challenge
        authenticationState = .signing
        
        // Sign the challenge
        guard let signedData = WatchKeyManager.shared.sign(nonce: challenge.nonce, timestamp: challenge.timestamp) else {
            authCompletion?(false, "Failed to sign challenge")
            authenticationState = .failed("Signing failed")
            return
        }
        
        // Send authentication request
        authenticationState = .authenticating
        
        if let peripheral = currentPeripheral, let characteristic = authCharacteristic {
            peripheral.writeValue(signedData, for: characteristic, type: .withResponse)
        } else {
            authCompletion?(false, "Connection lost")
            authenticationState = .failed("Connection lost")
        }
    }
    
    private func handleAuthResponse(_ data: Data) {
        if let response = String(data: data, encoding: .utf8) {
            if response.contains("success") || response.contains("ok") {
                authenticationState = .success
                authCompletion?(true, nil)
                
                // Reset after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.authenticationState = .idle
                }
            } else {
                authenticationState = .failed(response)
                authCompletion?(false, response)
            }
        } else {
            authenticationState = .failed("Invalid response")
            authCompletion?(false, "Invalid response")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension WatchBLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothEnabled = central.state == .poweredOn
        
        if !isBluetoothEnabled {
            lastError = "Bluetooth is \(central.state.rawValue)"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        
        // Check if already discovered
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier.uuidString }) {
            discoveredDevices[index].rssi = RSSI.intValue
        } else {
            let device = WatchDevice(
                id: peripheral.identifier.uuidString,
                name: deviceName,
                isConnected: false,
                peripheralIdentifier: peripheral.identifier.uuidString,
                peripheral: peripheral,
                rssi: RSSI.intValue
            )
            discoveredDevices.append(device)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Update connected device
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier.uuidString }) {
            discoveredDevices[index].isConnected = true
            connectedDevice = discoveredDevices[index]
        }
        
        // Discover services
        peripheral.discoverServices([WatchCyberdeckBLE.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lastError = error?.localizedDescription ?? "Connection failed"
        authenticationState = .failed(lastError ?? "Unknown error")
        resetState()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier.uuidString }) {
            discoveredDevices[index].isConnected = false
        }
        
        if currentPeripheral?.identifier == peripheral.identifier {
            resetState()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension WatchBLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            lastError = error?.localizedDescription
            return
        }
        
        if let service = peripheral.services?.first(where: { $0.uuid == WatchCyberdeckBLE.serviceUUID }) {
            peripheral.discoverCharacteristics([
                WatchCyberdeckBLE.challengeCharUUID,
                WatchCyberdeckBLE.authCharUUID
            ], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            lastError = error?.localizedDescription
            return
        }
        
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case WatchCyberdeckBLE.challengeCharUUID:
                challengeCharacteristic = characteristic
            case WatchCyberdeckBLE.authCharUUID:
                authCharacteristic = characteristic
                // Enable notifications for auth responses
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        
        authenticationState = .idle
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else {
            lastError = error?.localizedDescription ?? "No data"
            return
        }
        
        switch characteristic.uuid {
        case WatchCyberdeckBLE.challengeCharUUID:
            handleChallengeReceived(data)
        case WatchCyberdeckBLE.authCharUUID:
            handleAuthResponse(data)
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            lastError = error.localizedDescription
            authenticationState = .failed(error.localizedDescription)
            authCompletion?(false, error.localizedDescription)
        }
        // Success response will come via notification
    }
}

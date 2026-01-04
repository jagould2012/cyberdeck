import Foundation
import CoreBluetooth
import Combine
import UIKit

/// BLE service UUIDs for Cyberdeck Login
enum CyberdeckBLE {
    static let serviceUUID = CBUUID(string: "CD10")
    static let challengeCharUUID = CBUUID(string: "CD11")
    static let authCharUUID = CBUUID(string: "CD12")
    static let registerCharUUID = CBUUID(string: "CD13")
}

/// Manages Bluetooth LE communication with Cyberdeck devices
class BLEManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isScanning = false
    @Published var isBluetoothEnabled = false
    @Published var discoveredDevices: [CyberdeckDevice] = []
    @Published var connectedDevice: CyberdeckDevice?
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
    private var registerCharacteristic: CBCharacteristic?
    
    private var cryptoService: CryptoService?
    private var authCompletion: ((Bool, String?) -> Void)?
    private var registerCompletion: ((Bool, String?) -> Void)?
    private var authTimeout: Timer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        #if targetEnvironment(simulator)
        // In simulator, pretend Bluetooth is enabled and provide mock devices
        isBluetoothEnabled = true
        print("📱 Running in simulator - using mock BLE")
        #else
        centralManager = CBCentralManager(delegate: self, queue: .main)
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for Cyberdeck devices
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
            withServices: [CyberdeckBLE.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        
        // Auto-stop scanning after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScanning()
        }
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        #if targetEnvironment(simulator)
        isScanning = false
        return
        #endif
        
        centralManager.stopScan()
        isScanning = false
    }
    
    #if targetEnvironment(simulator)
    // MARK: - Simulator Mock Support
    
    private func startMockScanning() {
        isScanning = true
        discoveredDevices.removeAll()
        
        let mockData = [
            ("cyberdeck-pi1", -45),
            ("cyberdeck-pi2", -52),
            ("cyberdeck-testvm", -38)
        ]
        
        for (index, (name, rssi)) in mockData.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) { [weak self] in
                guard let self = self, self.isScanning else { return }
                
                let device = CyberdeckDevice(mockId: UUID(), name: name, rssi: rssi)
                self.discoveredDevices.append(device)
                
                // Notify Watch of updated devices
                WatchConnectivityService.shared.sendDevicesToWatch(self.discoveredDevices)
            }
        }
        
        // Auto-stop after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func mockConnect(to device: CyberdeckDevice) {
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
    
    func mockAuthenticate(completion: @escaping (Bool, String?) -> Void) {
        authenticationState = .readingChallenge
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.authenticationState = .signing
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.authenticationState = .authenticating
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
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
    
    /// Connect to a device
    func connect(to device: CyberdeckDevice) {
        print("🔗 BLE: Connecting to \(device.name)...")
        stopScanning()
        
        #if targetEnvironment(simulator)
        mockConnect(to: device)
        return
        #endif
        
        authenticationState = .connecting
        
        guard let peripheral = device.peripheral else {
            print("❌ BLE: No peripheral available (mock device?)")
            authenticationState = .failed("No peripheral available")
            return
        }
        
        currentPeripheral = peripheral
        currentPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Disconnect from current device
    func disconnect() {
        if let peripheral = currentPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetState()
    }
    
    /// Authenticate with connected device
    func authenticate(using cryptoService: CryptoService, completion: @escaping (Bool, String?) -> Void) {
        print("🔐 BLE: Starting authentication...")
        
        #if targetEnvironment(simulator)
        mockAuthenticate(completion: completion)
        return
        #endif
        
        self.cryptoService = cryptoService
        self.authCompletion = completion
        
        guard let peripheral = currentPeripheral else {
            print("❌ BLE: No peripheral")
            completion(false, "No device connected")
            return
        }
        
        print("🔐 BLE: Peripheral state: \(peripheral.state.rawValue)")
        print("🔐 BLE: Challenge characteristic: \(challengeCharacteristic != nil ? "found" : "nil")")
        
        authenticationState = .readingChallenge
        
        // Set timeout for authentication
        authTimeout?.invalidate()
        authTimeout = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            print("❌ BLE: Authentication timeout")
            self?.authenticationState = .failed("Connection timeout")
            self?.authCompletion?(false, "Connection timeout")
            self?.authCompletion = nil
        }
        
        // Read challenge characteristic
        if let characteristic = challengeCharacteristic {
            print("🔐 BLE: Reading challenge...")
            peripheral.readValue(for: characteristic)
        } else {
            print("❌ BLE: Challenge characteristic not found")
            authTimeout?.invalidate()
            completion(false, "Challenge characteristic not found")
        }
    }
    
    /// Register this device with the server (during registration mode)
    func register(using cryptoService: CryptoService, completion: @escaping (Bool, String?) -> Void) {
        self.cryptoService = cryptoService
        self.registerCompletion = completion
        
        guard let peripheral = currentPeripheral,
              let characteristic = registerCharacteristic else {
            completion(false, "Not connected or register characteristic not found")
            return
        }
        
        guard let keyPair = cryptoService.getKeyPair() else {
            completion(false, "No key pair available")
            return
        }
        
        // Create registration request
        let request = RegistrationRequest(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            publicKey: keyPair.publicKeyBase64,
            deviceName: UIDevice.current.name
        )
        
        do {
            let data = try JSONEncoder().encode(request)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } catch {
            completion(false, "Failed to encode registration request")
        }
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        authTimeout?.invalidate()
        authTimeout = nil
        currentPeripheral = nil
        challengeCharacteristic = nil
        authCharacteristic = nil
        registerCharacteristic = nil
        connectedDevice = nil
        authenticationState = .idle
    }
    
    private func handleChallenge(_ data: Data) {
        guard let cryptoService = cryptoService else {
            authCompletion?(false, "Crypto service not available")
            return
        }
        
        do {
            // Parse challenge
            let challenge = try JSONDecoder().decode(Challenge.self, from: data)
            
            // Update connected device with challenge
            if var device = connectedDevice {
                device.challenge = challenge
                connectedDevice = device
            }
            
            authenticationState = .signing
            
            // Create message to sign
            let message = SignableMessage(
                nonce: challenge.nonce,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000)
            )
            
            let messageData = try JSONEncoder().encode(message)
            
            // Sign the message
            guard let signature = cryptoService.sign(messageData),
                  let keyPair = cryptoService.getKeyPair() else {
                authCompletion?(false, "Failed to sign message")
                return
            }
            
            // Create auth request
            let authRequest = AuthRequest(
                signedNonce: signature.base64EncodedString(),
                publicKey: keyPair.publicKeyBase64
            )
            
            authenticationState = .authenticating
            
            // Send auth request
            let requestData = try JSONEncoder().encode(authRequest)
            
            if let peripheral = currentPeripheral,
               let characteristic = authCharacteristic {
                peripheral.writeValue(requestData, for: characteristic, type: .withResponse)
            }
            
        } catch {
            authCompletion?(false, "Failed to process challenge: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothEnabled = central.state == .poweredOn
        
        if central.state != .poweredOn {
            lastError = "Bluetooth is \(central.state)"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        let device = CyberdeckDevice(peripheral: peripheral, rssi: RSSI.intValue)
        
        // Update or add device
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index].rssi = RSSI.intValue
            discoveredDevices[index].lastSeen = Date()
        } else {
            discoveredDevices.append(device)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ BLE: Connected to \(peripheral.name ?? "unknown")")
        peripheral.delegate = self
        
        // Update connected device
        if let index = discoveredDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            var device = discoveredDevices[index]
            device.isConnected = true
            connectedDevice = device
        }
        
        // Discover services
        print("🔍 BLE: Discovering services...")
        peripheral.discoverServices([CyberdeckBLE.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ BLE: Failed to connect: \(error?.localizedDescription ?? "unknown")")
        authenticationState = .failed(error?.localizedDescription ?? "Connection failed")
        authCompletion?(false, error?.localizedDescription)
        resetState()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("📡 BLE: Disconnected: \(error?.localizedDescription ?? "clean disconnect")")
        if authenticationState != .success {
            authenticationState = error != nil ? .failed(error!.localizedDescription) : .idle
        }
        resetState()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("⚠️ BLE: Services modified/invalidated: \(invalidatedServices.map { $0.uuid })")
        
        // Check if our service was invalidated
        if invalidatedServices.contains(where: { $0.uuid == CyberdeckBLE.serviceUUID }) {
            print("❌ BLE: Cyberdeck service lost, disconnecting...")
            authTimeout?.invalidate()
            authTimeout = nil
            authenticationState = .failed("Service disconnected")
            authCompletion?(false, "Service disconnected")
            authCompletion = nil
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("🔍 BLE: Services discovered, error: \(error?.localizedDescription ?? "none")")
        guard error == nil,
              let services = peripheral.services else {
            authCompletion?(false, error?.localizedDescription ?? "No services found")
            return
        }
        
        print("🔍 BLE: Found \(services.count) services")
        for service in services {
            print("   - \(service.uuid)")
            if service.uuid == CyberdeckBLE.serviceUUID {
                peripheral.discoverCharacteristics([
                    CyberdeckBLE.challengeCharUUID,
                    CyberdeckBLE.authCharUUID,
                    CyberdeckBLE.registerCharUUID
                ], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("🔍 BLE: Characteristics discovered, error: \(error?.localizedDescription ?? "none")")
        guard error == nil,
              let characteristics = service.characteristics else {
            authCompletion?(false, error?.localizedDescription ?? "No characteristics found")
            return
        }
        
        print("🔍 BLE: Found \(characteristics.count) characteristics")
        for characteristic in characteristics {
            print("   - \(characteristic.uuid)")
            switch characteristic.uuid {
            case CyberdeckBLE.challengeCharUUID:
                challengeCharacteristic = characteristic
                print("   ✓ Challenge characteristic saved")
            case CyberdeckBLE.authCharUUID:
                authCharacteristic = characteristic
                print("   ✓ Auth characteristic saved")
            case CyberdeckBLE.registerCharUUID:
                registerCharacteristic = characteristic
                print("   ✓ Register characteristic saved")
            default:
                break
            }
        }
        
        // Update state to ready
        if authenticationState == .connecting {
            authenticationState = .idle
            print("✅ BLE: Ready for authentication")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              let data = characteristic.value else {
            authCompletion?(false, error?.localizedDescription ?? "No data received")
            return
        }
        
        if characteristic.uuid == CyberdeckBLE.challengeCharUUID {
            handleChallenge(data)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == CyberdeckBLE.authCharUUID {
            authTimeout?.invalidate()
            authTimeout = nil
            if let error = error {
                authenticationState = .failed(error.localizedDescription)
                authCompletion?(false, error.localizedDescription)
            } else {
                authenticationState = .success
                authCompletion?(true, nil)
            }
        } else if characteristic.uuid == CyberdeckBLE.registerCharUUID {
            if let error = error {
                registerCompletion?(false, error.localizedDescription)
            } else {
                registerCompletion?(true, nil)
            }
        }
    }
}

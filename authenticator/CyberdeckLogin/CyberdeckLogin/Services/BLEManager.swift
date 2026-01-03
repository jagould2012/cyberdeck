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
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for Cyberdeck devices
    func startScanning() {
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
        centralManager.stopScan()
        isScanning = false
    }
    
    /// Connect to a device
    func connect(to device: CyberdeckDevice) {
        stopScanning()
        authenticationState = .connecting
        currentPeripheral = device.peripheral
        centralManager.connect(device.peripheral, options: nil)
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
        self.cryptoService = cryptoService
        self.authCompletion = completion
        
        guard let peripheral = currentPeripheral else {
            completion(false, "No device connected")
            return
        }
        
        authenticationState = .readingChallenge
        
        // Read challenge characteristic
        if let characteristic = challengeCharacteristic {
            peripheral.readValue(for: characteristic)
        } else {
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
        peripheral.delegate = self
        
        // Update connected device
        if let index = discoveredDevices.firstIndex(where: { $0.peripheral == peripheral }) {
            var device = discoveredDevices[index]
            device.isConnected = true
            connectedDevice = device
        }
        
        // Discover services
        peripheral.discoverServices([CyberdeckBLE.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        authenticationState = .failed(error?.localizedDescription ?? "Connection failed")
        authCompletion?(false, error?.localizedDescription)
        resetState()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if authenticationState != .success {
            authenticationState = error != nil ? .failed(error!.localizedDescription) : .idle
        }
        resetState()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let services = peripheral.services else {
            authCompletion?(false, error?.localizedDescription ?? "No services found")
            return
        }
        
        for service in services {
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
        guard error == nil,
              let characteristics = service.characteristics else {
            authCompletion?(false, error?.localizedDescription ?? "No characteristics found")
            return
        }
        
        for characteristic in characteristics {
            switch characteristic.uuid {
            case CyberdeckBLE.challengeCharUUID:
                challengeCharacteristic = characteristic
            case CyberdeckBLE.authCharUUID:
                authCharacteristic = characteristic
            case CyberdeckBLE.registerCharUUID:
                registerCharacteristic = characteristic
            default:
                break
            }
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

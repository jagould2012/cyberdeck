import Foundation
import CoreBluetooth

/// Represents a discovered Cyberdeck device
struct CyberdeckDevice: Identifiable, Equatable, Hashable {
    let id: UUID
    let peripheral: CBPeripheral?
    var name: String
    var rssi: Int
    var lastSeen: Date
    var isConnected: Bool = false
    var challenge: Challenge?
    
    init(peripheral: CBPeripheral, rssi: Int) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi
        self.lastSeen = Date()
    }
    
    #if targetEnvironment(simulator)
    /// Mock initializer for simulator testing
    init(mockId: UUID, name: String, rssi: Int) {
        self.id = mockId
        self.peripheral = nil
        self.name = name
        self.rssi = rssi
        self.lastSeen = Date()
    }
    #endif
    
    static func == (lhs: CyberdeckDevice, rhs: CyberdeckDevice) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Challenge received from device
struct Challenge: Codable {
    let nonce: String
    let timestamp: Int64
    let computerName: String
}

/// Authentication request sent to device
struct AuthRequest: Codable {
    let signedNonce: String
    let publicKey: String
}

/// Registration request sent to device
struct RegistrationRequest: Codable {
    let deviceId: String
    let publicKey: String
    let deviceName: String
}

/// Message to sign for authentication
struct SignableMessage: Codable {
    let nonce: String
    let timestamp: Int64
}

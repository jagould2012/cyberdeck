import Foundation
import CoreBluetooth

/// Represents a discovered Cyberdeck device
struct CyberdeckDevice: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
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
    
    static func == (lhs: CyberdeckDevice, rhs: CyberdeckDevice) -> Bool {
        lhs.id == rhs.id
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

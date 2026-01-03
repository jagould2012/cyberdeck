import Foundation
import CoreBluetooth

/// Simplified device model for Watch
struct WatchDevice: Identifiable, Equatable {
    let id: String
    let name: String
    var isConnected: Bool
    let peripheralIdentifier: String?
    var peripheral: CBPeripheral?
    var rssi: Int
    
    init(id: String, name: String, isConnected: Bool = false, peripheralIdentifier: String? = nil, peripheral: CBPeripheral? = nil, rssi: Int = 0) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
        self.peripheralIdentifier = peripheralIdentifier
        self.peripheral = peripheral
        self.rssi = rssi
    }
    
    init?(from dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.isConnected = dictionary["isConnected"] as? Bool ?? false
        self.peripheralIdentifier = dictionary["peripheralIdentifier"] as? String
        self.peripheral = nil
        self.rssi = 0
    }
    
    static func == (lhs: WatchDevice, rhs: WatchDevice) -> Bool {
        lhs.id == rhs.id
    }
}

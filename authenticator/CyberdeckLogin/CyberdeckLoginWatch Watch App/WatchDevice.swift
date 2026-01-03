import Foundation

/// Simplified device model for Watch
struct WatchDevice: Identifiable, Equatable {
    let id: String
    let name: String
    var isConnected: Bool
    let peripheralIdentifier: String?
    
    init(id: String, name: String, isConnected: Bool = false, peripheralIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
        self.peripheralIdentifier = peripheralIdentifier
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
    }
}

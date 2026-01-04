import Foundation
import WatchConnectivity
import Combine

/// Handles communication between iPhone and Apple Watch
/// Primarily used for syncing the private key to Watch
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    @Published var isWatchReachable = false
    @Published var isWatchPaired = false
    @Published var isWatchAppInstalled = false
    
    private var session: WCSession?
    private var bleManager: BLEManager?
    private var cryptoService: CryptoService?
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func configure(bleManager: BLEManager, cryptoService: CryptoService? = nil) {
        self.bleManager = bleManager
        self.cryptoService = cryptoService
    }
    
    /// Push key to Watch (call when user wants to sync)
    func pushKeyToWatch() {
        guard let session = session, session.isReachable else {
            print("Watch not reachable")
            return
        }
        
        guard let cryptoService = cryptoService ?? (try? CryptoService()),
              let privateKeyData = cryptoService.getPrivateKeyData() else {
            print("No private key to send")
            return
        }
        
        let message: [String: Any] = [
            "type": "pushKey",
            "privateKey": privateKeyData.base64EncodedString()
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to push key to watch: \(error.localizedDescription)")
        }
    }
    
    /// Send list of known devices to Watch (legacy - Watch now scans directly)
    func sendDevicesToWatch(_ devices: [CyberdeckDevice]) {
        guard let session = session, session.isReachable else { return }
        
        let deviceData = devices.map { device -> [String: Any] in
            let peripheralId: String
            if let peripheral = device.peripheral {
                peripheralId = peripheral.identifier.uuidString
            } else {
                peripheralId = device.id.uuidString
            }
            
            return [
                "id": device.id.uuidString,
                "name": device.name,
                "isConnected": device.isConnected,
                "peripheralIdentifier": peripheralId
            ]
        }
        
        session.sendMessage(["type": "devices", "devices": deviceData], replyHandler: nil) { error in
            print("Failed to send devices to watch: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
        
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }
    
    // Handle messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let type = message["type"] as? String else {
            replyHandler(["error": "Unknown message type"])
            return
        }
        
        switch type {
        case "requestKey":
            // Watch is requesting the private key
            DispatchQueue.main.async {
                if let cryptoService = self.cryptoService ?? (try? CryptoService()),
                   let privateKeyData = cryptoService.getPrivateKeyData() {
                    replyHandler(["privateKey": privateKeyData.base64EncodedString()])
                } else {
                    replyHandler(["error": "No key pair on iPhone"])
                }
            }
            
        case "getDevices":
            // Legacy - Watch now scans directly
            DispatchQueue.main.async {
                if let bleManager = self.bleManager {
                    let deviceData = bleManager.discoveredDevices.map { device -> [String: Any] in
                        let peripheralId: String
                        if let peripheral = device.peripheral {
                            peripheralId = peripheral.identifier.uuidString
                        } else {
                            peripheralId = device.id.uuidString
                        }
                        
                        return [
                            "id": device.id.uuidString,
                            "name": device.name,
                            "isConnected": device.isConnected,
                            "peripheralIdentifier": peripheralId
                        ]
                    }
                    replyHandler(["devices": deviceData])
                } else {
                    replyHandler(["devices": []])
                }
            }
            
        default:
            replyHandler(["error": "Unknown message type: \(type)"])
        }
    }
    
    // Handle messages without reply
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // No-reply messages not currently used
    }
}

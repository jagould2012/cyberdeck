import Foundation
import WatchConnectivity
import Combine

/// Handles communication between iPhone and Apple Watch
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    @Published var isWatchReachable = false
    @Published var isWatchPaired = false
    @Published var isWatchAppInstalled = false
    
    private var session: WCSession?
    private var bleManager: BLEManager?
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func configure(bleManager: BLEManager) {
        self.bleManager = bleManager
    }
    
    /// Send list of known devices to Watch
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
    
    /// Send authentication result to Watch
    func sendAuthResultToWatch(deviceId: String, success: Bool, error: String? = nil) {
        guard let session = session, session.isReachable else { return }
        
        var message: [String: Any] = [
            "type": "authResult",
            "deviceId": deviceId,
            "success": success
        ]
        
        if let error = error {
            message["error"] = error
        }
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send auth result to watch: \(error.localizedDescription)")
        }
    }
    
    /// Handle authentication request from Watch
    private func handleAuthRequest(deviceId: String, replyHandler: @escaping ([String: Any]) -> Void) {
        guard let bleManager = bleManager else {
            replyHandler(["success": false, "error": "BLE not configured"])
            return
        }
        
        // Find the device by UUID string
        guard let device = bleManager.discoveredDevices.first(where: { $0.id.uuidString == deviceId }) else {
            replyHandler(["success": false, "error": "Device not found"])
            return
        }
        
        // Get or create crypto service
        guard let cryptoService = try? CryptoService() else {
            replyHandler(["success": false, "error": "Failed to initialize crypto"])
            return
        }
        
        // Connect if needed
        if !device.isConnected {
            bleManager.connect(to: device)
        }
        
        // Authenticate with completion handler
        bleManager.authenticate(using: cryptoService) { success, error in
            var response: [String: Any] = ["success": success]
            if let error = error {
                response["error"] = error
            }
            replyHandler(response)
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
        // Reactivate for switching watches
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
        case "authenticate":
            if let deviceId = message["deviceId"] as? String {
                DispatchQueue.main.async {
                    self.handleAuthRequest(deviceId: deviceId, replyHandler: replyHandler)
                }
            } else {
                replyHandler(["success": false, "error": "Missing deviceId"])
            }
            
        case "getDevices":
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
            
        case "startScanning":
            DispatchQueue.main.async {
                self.bleManager?.startScanning()
            }
            replyHandler(["success": true])
            
        default:
            replyHandler(["error": "Unknown message type: \(type)"])
        }
    }
    
    // Handle messages without reply
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "startScanning":
            DispatchQueue.main.async {
                self.bleManager?.startScanning()
            }
        default:
            break
        }
    }
}

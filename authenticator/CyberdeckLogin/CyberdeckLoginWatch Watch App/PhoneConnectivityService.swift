import Foundation
import WatchConnectivity
import Combine

/// Watch-side connectivity service for communicating with iPhone
/// Now primarily used for key syncing - BLE is handled directly on Watch
class PhoneConnectivityService: NSObject, ObservableObject {
    static let shared = PhoneConnectivityService()
    
    @Published var isPhoneReachable = false
    @Published var hasKey: Bool = false
    @Published var keySyncStatus: String = ""
    
    private var session: WCSession?
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        
        // Check if we have a key
        hasKey = WatchKeyManager.shared.hasKeyPair
    }
    
    /// Request private key from iPhone
    func requestKeySync() {
        guard let session = session, session.isReachable else {
            keySyncStatus = "iPhone not reachable"
            return
        }
        
        keySyncStatus = "Requesting key..."
        
        session.sendMessage(["type": "requestKey"], replyHandler: { [weak self] response in
            DispatchQueue.main.async {
                if let keyBase64 = response["privateKey"] as? String,
                   let keyData = Data(base64Encoded: keyBase64) {
                    if WatchKeyManager.shared.saveKey(privateKeyData: keyData) {
                        self?.hasKey = true
                        self?.keySyncStatus = "Key synced!"
                    } else {
                        self?.keySyncStatus = "Failed to save key"
                    }
                } else if let error = response["error"] as? String {
                    self?.keySyncStatus = error
                } else {
                    self?.keySyncStatus = "Invalid response"
                }
            }
        }) { [weak self] error in
            DispatchQueue.main.async {
                self?.keySyncStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    /// Delete synced key
    func deleteKey() {
        WatchKeyManager.shared.deleteKey()
        hasKey = false
        keySyncStatus = "Key deleted"
    }
}

// MARK: - WCSessionDelegate
extension PhoneConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            self.hasKey = WatchKeyManager.shared.hasKeyPair
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }
    
    // Handle messages from iPhone (e.g., key push)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "pushKey":
            if let keyBase64 = message["privateKey"] as? String,
               let keyData = Data(base64Encoded: keyBase64) {
                DispatchQueue.main.async {
                    if WatchKeyManager.shared.saveKey(privateKeyData: keyData) {
                        self.hasKey = true
                        self.keySyncStatus = "Key received from iPhone"
                    }
                }
            }
        default:
            break
        }
    }
}

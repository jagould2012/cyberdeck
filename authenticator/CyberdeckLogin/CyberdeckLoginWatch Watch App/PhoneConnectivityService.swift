import Foundation
import WatchConnectivity
import Combine

/// Watch-side connectivity service for communicating with iPhone
class PhoneConnectivityService: NSObject, ObservableObject {
    static let shared = PhoneConnectivityService()
    
    @Published var isPhoneReachable = false
    @Published var devices: [WatchDevice] = []
    @Published var isAuthenticating = false
    @Published var lastAuthResult: AuthResult?
    
    private var session: WCSession?
    
    struct AuthResult {
        let deviceId: String
        let success: Bool
        let error: String?
    }
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    /// Request device list from iPhone
    func requestDevices() {
        guard let session = session, session.isReachable else {
            print("Phone not reachable")
            return
        }
        
        session.sendMessage(["type": "getDevices"], replyHandler: { response in
            if let deviceData = response["devices"] as? [[String: Any]] {
                DispatchQueue.main.async {
                    self.devices = deviceData.compactMap { WatchDevice(from: $0) }
                }
            }
        }) { error in
            print("Failed to get devices: \(error.localizedDescription)")
        }
    }
    
    /// Request iPhone to start scanning for devices
    func requestStartScanning() {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["type": "startScanning"], replyHandler: nil, errorHandler: nil)
    }
    
    /// Request authentication for a device
    func authenticate(deviceId: String) {
        guard let session = session, session.isReachable else {
            lastAuthResult = AuthResult(deviceId: deviceId, success: false, error: "Phone not reachable")
            return
        }
        
        isAuthenticating = true
        lastAuthResult = nil
        
        session.sendMessage(["type": "authenticate", "deviceId": deviceId], replyHandler: { response in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                let success = response["success"] as? Bool ?? false
                let error = response["error"] as? String
                self.lastAuthResult = AuthResult(deviceId: deviceId, success: success, error: error)
            }
        }) { error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.lastAuthResult = AuthResult(deviceId: deviceId, success: false, error: error.localizedDescription)
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension PhoneConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        
        if activationState == .activated {
            requestDevices()
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            if session.isReachable {
                self.requestDevices()
            }
        }
    }
    
    // Handle messages from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "devices":
            if let deviceData = message["devices"] as? [[String: Any]] {
                DispatchQueue.main.async {
                    self.devices = deviceData.compactMap { WatchDevice(from: $0) }
                }
            }
            
        case "authResult":
            if let deviceId = message["deviceId"] as? String,
               let success = message["success"] as? Bool {
                let error = message["error"] as? String
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.lastAuthResult = AuthResult(deviceId: deviceId, success: success, error: error)
                }
            }
            
        default:
            break
        }
    }
}

import Foundation
import CryptoKit

/// Manages Ed25519 key pair on Apple Watch
/// Keys are synced from iPhone via WatchConnectivity
class WatchKeyManager: ObservableObject {
    static let shared = WatchKeyManager()
    
    @Published var hasKeyPair: Bool = false
    @Published var publicKeyBase64: String?
    
    private var privateKey: Curve25519.Signing.PrivateKey?
    
    private let keychainService = "com.cyberdeck.login.watch"
    private let privateKeyAccount = "ed25519-private"
    
    private init() {
        loadKey()
    }
    
    // MARK: - Key Management
    
    /// Load key from Keychain
    private func loadKey() {
        if let keyData = loadFromKeychain(account: privateKeyAccount) {
            do {
                privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
                hasKeyPair = true
                publicKeyBase64 = privateKey?.publicKey.rawRepresentation.base64EncodedString()
                print("🔑 Watch: Loaded key pair")
            } catch {
                print("❌ Watch: Failed to load key: \(error)")
                hasKeyPair = false
            }
        } else {
            hasKeyPair = false
            print("🔑 Watch: No key pair found")
        }
    }
    
    /// Save key received from iPhone
    func saveKey(privateKeyData: Data) -> Bool {
        do {
            // Validate it's a valid key
            let key = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
            
            // Save to Keychain
            if saveToKeychain(data: privateKeyData, account: privateKeyAccount) {
                privateKey = key
                hasKeyPair = true
                publicKeyBase64 = key.publicKey.rawRepresentation.base64EncodedString()
                print("🔑 Watch: Key pair saved")
                return true
            }
        } catch {
            print("❌ Watch: Invalid key data: \(error)")
        }
        return false
    }
    
    /// Delete key
    func deleteKey() {
        deleteFromKeychain(account: privateKeyAccount)
        privateKey = nil
        hasKeyPair = false
        publicKeyBase64 = nil
        print("🔑 Watch: Key pair deleted")
    }
    
    // MARK: - Signing
    
    /// Sign a challenge for authentication
    func sign(nonce: String, timestamp: Int64) -> Data? {
        guard let privateKey = privateKey else {
            print("❌ Watch: No private key for signing")
            return nil
        }
        
        // Create the message to sign (same format as iPhone)
        let message = SignableMessage(nonce: nonce, timestamp: timestamp)
        
        guard let messageData = try? JSONEncoder().encode(message) else {
            print("❌ Watch: Failed to encode message")
            return nil
        }
        
        do {
            let signature = try privateKey.signature(for: messageData)
            
            // Ed25519 signature format: signature || message
            // This matches the format expected by tweetnacl.sign() and iPhone
            var signedMessage = Data()
            signedMessage.append(signature)
            signedMessage.append(messageData)
            
            // Create auth request
            let authRequest = AuthRequest(
                signedNonce: signedMessage.base64EncodedString(),
                publicKey: privateKey.publicKey.rawRepresentation.base64EncodedString()
            )
            
            return try JSONEncoder().encode(authRequest)
        } catch {
            print("❌ Watch: Signing failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToKeychain(data: Data, account: String) -> Bool {
        // Delete existing
        deleteFromKeychain(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func loadFromKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Shared Types (same as iPhone)

struct SignableMessage: Codable {
    let nonce: String
    let timestamp: Int64
}

struct AuthRequest: Codable {
    let signedNonce: String
    let publicKey: String
}

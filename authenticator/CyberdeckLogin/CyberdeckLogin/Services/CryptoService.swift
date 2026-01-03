import Foundation
import CryptoKit

/// Handles Ed25519 key generation and signing
class CryptoService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var hasKeyPair: Bool = false
    @Published var publicKeyBase64: String?
    
    // MARK: - Private Properties
    
    private var signingKey: Curve25519.Signing.PrivateKey?
    private let keychainService: KeychainService
    
    // MARK: - Constants
    
    private let keyTag = "com.cyberdeck-login.signing-key"
    
    // MARK: - Initialization
    
    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        loadKeyFromKeychain()
    }
    
    // MARK: - Public Methods
    
    /// Generate a new Ed25519 key pair
    func generateKeyPair() -> Bool {
        do {
            // Generate new key
            signingKey = Curve25519.Signing.PrivateKey()
            
            // Save to keychain
            guard let key = signingKey else { return false }
            
            let privateKeyData = key.rawRepresentation
            try keychainService.save(privateKeyData, forKey: keyTag)
            
            // Update state
            hasKeyPair = true
            publicKeyBase64 = key.publicKey.rawRepresentation.base64EncodedString()
            
            return true
        } catch {
            print("Failed to generate key pair: \(error)")
            return false
        }
    }
    
    /// Delete the existing key pair
    func deleteKeyPair() -> Bool {
        do {
            try keychainService.delete(forKey: keyTag)
            signingKey = nil
            hasKeyPair = false
            publicKeyBase64 = nil
            return true
        } catch {
            print("Failed to delete key pair: \(error)")
            return false
        }
    }
    
    /// Get the current key pair
    func getKeyPair() -> KeyPair? {
        guard let key = signingKey else { return nil }
        
        return KeyPair(
            publicKey: key.publicKey.rawRepresentation,
            privateKey: key.rawRepresentation
        )
    }
    
    /// Get raw private key data for syncing to Watch
    func getPrivateKeyData() -> Data? {
        return signingKey?.rawRepresentation
    }
    
    /// Sign data using Ed25519
    func sign(_ data: Data) -> Data? {
        guard let key = signingKey else {
            print("No signing key available")
            return nil
        }
        
        do {
            let signature = try key.signature(for: data)
            
            // Ed25519 signature format: signature || message
            // This matches the format expected by tweetnacl.sign()
            var signedMessage = Data()
            signedMessage.append(signature)
            signedMessage.append(data)
            
            return signedMessage
        } catch {
            print("Failed to sign data: \(error)")
            return nil
        }
    }
    
    /// Verify a signature (for testing)
    func verify(signature: Data, message: Data, publicKey: Data) -> Bool {
        do {
            let pubKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
            return pubKey.isValidSignature(signature.prefix(64), for: message)
        } catch {
            print("Failed to verify signature: \(error)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadKeyFromKeychain() {
        do {
            let privateKeyData = try keychainService.load(forKey: keyTag)
            signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
            hasKeyPair = true
            publicKeyBase64 = signingKey?.publicKey.rawRepresentation.base64EncodedString()
        } catch {
            // No key found, that's okay
            hasKeyPair = false
            publicKeyBase64 = nil
        }
    }
}

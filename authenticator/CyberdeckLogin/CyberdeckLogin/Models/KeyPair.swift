import Foundation

/// Ed25519 key pair for authentication
struct KeyPair {
    let publicKey: Data
    let privateKey: Data
    
    /// Public key as base64 string (for sharing with server)
    var publicKeyBase64: String {
        publicKey.base64EncodedString()
    }
    
    /// Private key as base64 string (for storage)
    var privateKeyBase64: String {
        privateKey.base64EncodedString()
    }
    
    /// Initialize from base64 strings
    init?(publicKeyBase64: String, privateKeyBase64: String) {
        guard let pubKey = Data(base64Encoded: publicKeyBase64),
              let privKey = Data(base64Encoded: privateKeyBase64) else {
            return nil
        }
        self.publicKey = pubKey
        self.privateKey = privKey
    }
    
    /// Initialize from raw data
    init(publicKey: Data, privateKey: Data) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}

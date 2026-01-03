import SwiftUI

@main
struct CyberdeckLoginApp: App {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var cryptoService = CryptoService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(cryptoService)
        }
    }
}

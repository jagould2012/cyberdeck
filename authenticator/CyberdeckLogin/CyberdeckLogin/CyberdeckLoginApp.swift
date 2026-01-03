import SwiftUI

@main
struct CyberdeckLoginApp: App {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var cryptoService: CryptoService
    
    init() {
        let crypto = CryptoService()
        _cryptoService = StateObject(wrappedValue: crypto)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(cryptoService)
                .onAppear {
                    // Configure Watch connectivity
                    WatchConnectivityService.shared.configure(bleManager: bleManager)
                }
        }
    }
}

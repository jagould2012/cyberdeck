import SwiftUI

@main
struct CyberdeckLoginApp: App {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var cryptoService = CryptoService()
    
    init() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(white: 0.08, alpha: 1)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(white: 0.7, alpha: 1),
            .font: UIFont.systemFont(ofSize: 17, weight: .light)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(white: 0.7, alpha: 1),
            .font: UIFont.systemFont(ofSize: 34, weight: .light)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure table/list appearance for dark rows
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = UIColor(white: 0.12, alpha: 1)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(cryptoService)
                .preferredColorScheme(.dark)
                .onAppear {
                    WatchConnectivityService.shared.configure(bleManager: bleManager, cryptoService: cryptoService)
                }
        }
    }
}

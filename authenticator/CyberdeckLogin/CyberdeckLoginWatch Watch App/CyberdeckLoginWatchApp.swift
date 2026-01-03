import SwiftUI

@main
struct CyberdeckLoginWatchApp: App {
    @StateObject private var connectivityService = PhoneConnectivityService.shared
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(connectivityService)
        }
    }
}

import SwiftUI

@main
struct GenkiWatchApp: App {
    @StateObject private var session = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(session)
                .tint(GenkiPalette.primary)
        }
    }
}

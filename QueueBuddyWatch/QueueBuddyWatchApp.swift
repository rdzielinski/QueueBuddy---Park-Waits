import SwiftUI

@main
struct QueueBuddyWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    var body: some View {
        NavigationStack {
            WatchHomeView()
        }
    }
}

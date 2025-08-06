import SwiftUI
import BackgroundTasks
import UIKit

@main
struct ThemeParkTimesApp: App {
    @StateObject private var viewModel = WaitTimeViewModel()

    // FIXED: Simplified the background task registration.
    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: WaitTimeViewModel.backgroundAppRefreshTaskId,
            using: nil
        ) { task in
            // The task is passed to a new instance of the view model to handle the refresh.
            WaitTimeViewModel().handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    init() {
        ThemeParkTimesApp.registerBackgroundTasks()
        // All your global appearance settings for UINavigationBar and UITabBar are great.
        // No changes were needed here.
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = .clear
        navBarAppearance.shadowColor = .clear
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = .systemPurple
    }

    var body: some Scene {
        WindowGroup {
            // The RootView is the main view of the app.
            RootView()
                .environmentObject(viewModel)
                .task {
                    // Load initial data when the app starts.
                    await viewModel.loadInitialData()
                }
        }
    }
}

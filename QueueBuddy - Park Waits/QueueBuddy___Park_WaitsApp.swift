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
            // Ensure we have the correct task type.
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            // Schedule the next refresh task to run in the future.
            WaitTimeViewModel.scheduleNextAppRefresh()

            // Create a temporary view model instance to perform the data fetch.
            // This instance will be retained by the `operation` Task below.
            let viewModel = WaitTimeViewModel()
            
            // Create the async operation that will fetch the data.
            let operation = Task {
                await viewModel.loadInitialData()
                // After fetching, complete the background task.
                // Success is determined by whether an error message was set.
                let success = viewModel.errorMessage == nil
                refreshTask.setTaskCompleted(success: success)
            }

            // Set an expiration handler. If the task takes too long,
            // the system will call this, and we should cancel our work.
            refreshTask.expirationHandler = {
                operation.cancel()
            }
        }
    }

    init() {
        ThemeParkTimesApp.registerBackgroundTasks()
        #if !os(tvOS)
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
        #endif
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

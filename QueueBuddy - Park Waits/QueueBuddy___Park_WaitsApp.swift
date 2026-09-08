import SwiftUI
import BackgroundTasks
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct ThemeParkTimesApp: App {
    @StateObject private var viewModel = WaitTimeViewModel()

    static func registerBackgroundTasks() {
        let identifier = WaitTimeViewModel.backgroundAppRefreshTaskId
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            dprint("🔄 BG task fired: \(identifier) at \(Date())")
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            // Re-arm the next slot immediately — if we don't, the chain
            // ends here and iOS never wakes us again.
            WaitTimeViewModel.scheduleNextAppRefresh()

            // Spin up a transient view model for the fetch. State that
            // matters across invocations (dedup, Live Activity, cache)
            // is persisted via UserDefaults / ActivityKit, not held on
            // the view model, so a fresh instance is fine.
            let viewModel = WaitTimeViewModel()
            let operation = Task {
                await viewModel.loadInitialData()
                let success = viewModel.errorMessage == nil
                dprint("🔄 BG task completed: success=\(success)")
                refreshTask.setTaskCompleted(success: success)
            }
            refreshTask.expirationHandler = {
                dprint("⏱️ BG task expired before completion")
                operation.cancel()
            }
        }
        // If registration fails, submit() will *crash* later. Almost
        // always means the identifier isn't in Info.plist's
        // BGTaskSchedulerPermittedIdentifiers, or register() ran twice.
        dprint(registered
              ? "✅ Registered BG task handler: \(identifier)"
              : "❌ Failed to register BG task handler: \(identifier) — check Info.plist BGTaskSchedulerPermittedIdentifiers")
    }

    init() {
        UserPreferences.registerDefaults()
        #if canImport(GoogleMobileAds)
        if AdConfig.adsEnabled {
            #if DEBUG
            // Serve test ads in debug builds so development never triggers
            // billable impressions / clicks on the live unit. The simulator
            // is a test device automatically; for a physical device, copy
            // the identifier the SDK logs on first ad load and add it here.
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
                "SIMULATOR",
                "fc5d9c0862f1e89c3bbc774fdf9921df",
            ]
            #endif
            MobileAds.shared.start(completionHandler: nil)
        }
        #endif
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

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            // The RootView is the main view of the app.
            RootView()
                .environmentObject(viewModel)
                .task {
                    // Load initial data when the app starts, then schedule
                    // the first BG refresh and start the foreground timer.
                    // The BG handler reschedules itself, but the *first*
                    // request only ever gets submitted from here — without
                    // it iOS never fires the periodic refresh at all.
                    await viewModel.loadInitialData()
                    WaitTimeViewModel.scheduleNextAppRefresh()
                    viewModel.startForegroundAutoRefresh()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        viewModel.startForegroundAutoRefresh()
                    case .background, .inactive:
                        viewModel.stopForegroundAutoRefresh()
                        // Re-arm the BG refresh — submitting on background
                        // is the documented place to ensure the next slot
                        // is queued before the OS suspends us.
                        WaitTimeViewModel.scheduleNextAppRefresh()
                    @unknown default:
                        break
                    }
                }
        }
    }
}

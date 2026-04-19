import Foundation
import Network
import Combine

/// Lightweight reachability monitor used to show the "no signal" banner and
/// to stamp when live data was last successfully refreshed.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline: Bool = true
    @Published private(set) var lastSuccessfulSync: Date?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Dzielinski.QueueBuddy.NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    func markSuccessfulSync() {
        lastSuccessfulSync = Date()
    }

    var lastSyncText: String? {
        guard let date = lastSuccessfulSync else { return nil }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins) min ago" }
        let hours = mins / 60
        return "\(hours) hr ago"
    }
}

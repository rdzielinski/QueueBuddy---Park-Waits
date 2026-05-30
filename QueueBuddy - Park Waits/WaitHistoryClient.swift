import Foundation

/// Pulls long-form wait-time samples from the Cloudflare push worker's
/// `/history` endpoint, which is backed by D1 and sampled every 5
/// minutes for every known park. Used by `WaitHistoryStore` when the
/// on-device 24h ring buffer can't cover the requested window.
///
/// Returns an empty list on any network or decode error — long-form
/// history is a nice-to-have, never a blocker for the rest of the UI.
enum WaitHistoryClient {
    /// Coarsely categorized time ranges. The picker on the detail view
    /// exposes these directly; pick the smallest one the user needs
    /// to keep the response payload modest.
    enum Range: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var seconds: TimeInterval {
            switch self {
            case .day:   return 24 * 3600
            case .week:  return 7 * 86400
            case .month: return 30 * 86400
            }
        }
        var label: String {
            switch self {
            case .day:   return "24H"
            case .week:  return "7D"
            case .month: return "30D"
            }
        }
    }

    /// Returned by `/history` — one row per recorded sample. `minutes` is
    /// nil when the ride was closed at the sampling moment.
    struct Sample: Decodable {
        let at: Int             // unix seconds
        let wait: Int?
        let status: String
    }

    private struct Response: Decodable {
        let ok: Bool
        let samples: [Sample]
    }

    static func fetchHistory(attractionName: String, range: Range) async -> [Sample] {
        guard let base = LiveActivityBackend.baseURL else { return [] }
        let since = Int(Date().timeIntervalSince1970 - range.seconds)
        var components = URLComponents(url: base.appendingPathComponent("history"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "name", value: attractionName),
            URLQueryItem(name: "since", value: String(since)),
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                dprint("⚠️ /history HTTP \(http.statusCode) for \(attractionName)")
                return []
            }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            return decoded.samples
        } catch {
            dprint("⚠️ /history fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}

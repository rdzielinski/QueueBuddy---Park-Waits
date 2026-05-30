import Foundation

/// Thin client for the Cloudflare push worker that keeps in-line Live
/// Activities updated while the app is suspended / killed. See
/// `cloudflare/README.md` for deployment.
///
/// Calls are fire-and-forget; if the network's down we log and move on.
/// The activity still works locally via the app's foreground refresh
/// loop — push is an enhancement, not a hard dependency.
enum LiveActivityBackend {
    /// Set to your deployed Worker URL after running `wrangler deploy`.
    /// Without this, registration is a no-op and Live Activities only
    /// update while the app is in the foreground.
    ///
    /// Example: `https://queuebuddy-push.your-subdomain.workers.dev`
    static var baseURL: URL? {
        // Pulled from UserDefaults so dev builds can override without
        // recompiling. Fall back to the compiled-in constant otherwise.
        if let raw = UserDefaults.standard.string(forKey: "qb.pushWorkerURL"),
           let url = URL(string: raw) {
            return url
        }
        return compiledInDefault
    }

    /// Edit this once you've deployed the Worker. Leave nil to disable
    /// remote Live Activity updates entirely.
    private static let compiledInDefault: URL? =
        URL(string: "https://queuebuddy-push.robbydz-villages.workers.dev")

    static func register(
        attractionId: Int,
        parkUUID: String,
        pushToken: String,
        activityId: String,
        attractionName: String,
        parkAccentHex: UInt32,
        startedAt: Double
    ) async {
        guard let base = baseURL else {
            dprint("ℹ️ LiveActivityBackend.baseURL not set — skipping register")
            return
        }
        let body: [String: Any] = [
            "attractionId": attractionId,
            "parkUUID": parkUUID,
            "pushToken": pushToken,
            "activityId": activityId,
            "attractionName": attractionName,
            "parkAccentHex": parkAccentHex,
            "startedAt": startedAt,
        ]
        await post(base.appendingPathComponent("register"), body: body, name: "register")
    }

    static func unregister(pushToken: String) async {
        guard let base = baseURL else { return }
        await post(base.appendingPathComponent("unregister"),
                   body: ["pushToken": pushToken],
                   name: "unregister")
    }

    // MARK: - Private

    private static func post(_ url: URL, body: [String: Any], name: String) async {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            dprint("❌ \(name) JSON encode failed: \(error)")
            return
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                dprint("⚠️ \(name) returned HTTP \(http.statusCode)")
            } else {
                dprint("✅ \(name) ok")
            }
        } catch {
            dprint("⚠️ \(name) network failed: \(error.localizedDescription)")
        }
    }
}

import Foundation
import CoreLocation

// MARK: - Decoded shape of the routing engine's JSON response

/// Strict-JSON output from the Claude routing system prompt. The prompt
/// guarantees this exact schema; any drift here means Claude didn't follow
/// instructions and the call is treated as a failure.
public struct RouteDecision: Codable, Hashable, Identifiable {
    public let rerouteTriggered: Bool
    public let nextDestination: NextDestination
    public let lockScreenMessage: String

    /// Decision identity for SwiftUI sheet/banner lifecycle. Recomputed on
    /// every decode so the same payload always has the same id.
    public var id: String {
        "\(nextDestination.attractionId)|\(lockScreenMessage)"
    }

    public struct NextDestination: Codable, Hashable {
        public let attractionId: String
        public let attractionName: String
        public let actionType: ActionType
        public let expectedWaitMinutes: Int

        public enum ActionType: String, Codable, Hashable {
            case ride = "Ride"
            case show = "Show"
            case dining = "Dining"
            case transit = "Transit"
        }

        enum CodingKeys: String, CodingKey {
            case attractionId = "attraction_id"
            case attractionName = "attraction_name"
            case actionType = "action_type"
            case expectedWaitMinutes = "expected_wait_minutes"
        }
    }

    enum CodingKeys: String, CodingKey {
        case rerouteTriggered = "reroute_triggered"
        case nextDestination = "next_destination"
        case lockScreenMessage = "lock_screen_message"
    }
}

// MARK: - Inputs the evaluator needs

/// Snapshot of everything Claude needs to make a routing decision. Built
/// once on the main actor (because it reads UI state), then handed to the
/// `RouteEvaluator` static call which can run anywhere.
public struct RouteContext {
    public let parkName: String
    public let nextStepName: String
    public let nextStepTargetTime: Date?
    public let waitTimes: [WaitSnapshot]
    public let currentLocationLabel: String?
    public let maxWaitToleranceMinutes: Int
    public let groupProfile: String?

    public struct WaitSnapshot {
        public let name: String
        public let waitMinutes: Int?
        public let status: String?  // OPERATING / DOWN / CLOSED / REFURBISHMENT
    }
}

// MARK: - Evaluator

/// Calls the Claude routing engine and parses its strict-JSON response.
/// Stateless — all the conversational stuff lives elsewhere; this is a
/// fire-and-forget evaluator that returns a typed decision or nil.
public enum RouteEvaluator {

    /// System prompt that forces Claude into pure-JSON routing-engine mode.
    /// See the task description for the contract; if you tweak this prompt
    /// you almost certainly need to re-test the JSON parser too.
    private static let systemPrompt: String = """
You are the dynamic routing engine for QueueBuddy, a theme park itinerary optimization app. Your objective is to keep users moving efficiently through the park by continuously evaluating their scheduled itinerary against real-time wait time data.

RULES:
1. You will be provided with the user's `Current_Plan`, `Live_Wait_Times`, `User_Preferences`, and `Current_Location`.
2. Evaluate the next scheduled attraction. If its live wait time significantly exceeds the historical average, hits the user's maximum wait tolerance, or indicates a delay/closure, you MUST reroute the user.
3. When rerouting, select a nearby alternative that fits the user's preferences and has a manageable wait time.
4. If the current plan remains optimal, output the next scheduled step without changes.
5. You must respond ONLY with valid, raw JSON matching the exact schema below. Do not include any conversational text, pleasantries, or markdown code blocks (e.g., do not use ```json).

EXPECTED JSON SCHEMA:
{
  "reroute_triggered": true,
  "next_destination": {
    "attraction_id": "String",
    "attraction_name": "String",
    "action_type": "Ride | Show | Dining | Transit",
    "expected_wait_minutes": Int
  },
  "lock_screen_message": "String (A punchy, 1-sentence explanation for the Live Activity. e.g., 'Hagrid's spiked to 120m. Rerouting to VelociCoaster.')"
}
"""

    /// Evaluates the user's plan against current wait times using
    /// whichever AI provider the user has selected (Claude / OpenAI /
    /// Gemini / Apple Intelligence).
    /// - Returns: A typed `RouteDecision` on success, or `nil` if the
    ///   active provider isn't configured (no key for cloud providers,
    ///   not available on this device for Apple), the response wasn't
    ///   valid JSON, or anything else went wrong. Routing is an
    ///   optimization — never surface failures to the user as errors.
    public static func evaluate(_ context: RouteContext,
                                client: (any AIChatProvider)? = nil) async -> RouteDecision? {
        guard AIProviderRegistry.currentIsConfigured() else { return nil }

        let resolvedClient = client ?? AIProviderRegistry.currentClient()
        let userMessage = buildUserMessage(from: context)

        let raw: String
        do {
            raw = try await resolvedClient.complete(
                systemPrompt: systemPrompt,
                contextBlock: nil,
                history: [],
                userMessage: userMessage,
                maxTokens: 600
            )
        } catch {
            dprint("RouteEvaluator: AI call failed — \(error)")
            return nil
        }

        return decode(raw)
    }

    // MARK: - Prompt assembly

    private static func buildUserMessage(from context: RouteContext) -> String {
        var lines: [String] = []

        lines.append("<current_plan>")
        lines.append("Next Step: \(context.nextStepName)")
        if let target = context.nextStepTargetTime {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            lines.append("Target Time: \(f.string(from: target))")
        }
        lines.append("</current_plan>")
        lines.append("")

        lines.append("<live_wait_times>")
        for w in context.waitTimes {
            let waitText: String
            if let m = w.waitMinutes {
                waitText = "\(m) mins"
            } else {
                waitText = "—"
            }
            let statusFragment: String
            switch (w.status ?? "").uppercased() {
            case "DOWN":          statusFragment = " (Status: Down)"
            case "REFURBISHMENT": statusFragment = " (Status: Refurbishment)"
            case "CLOSED":        statusFragment = " (Status: Closed)"
            case "OPERATING", "": statusFragment = ""
            default:              statusFragment = " (Status: \(w.status!))"
            }
            lines.append("\(w.name): \(waitText)\(statusFragment)")
        }
        lines.append("</live_wait_times>")
        lines.append("")

        lines.append("<user_context>")
        lines.append("Park: \(context.parkName)")
        if let loc = context.currentLocationLabel {
            lines.append("Location: \(loc)")
        }
        lines.append("Max Wait Tolerance: \(context.maxWaitToleranceMinutes) mins")
        if let profile = context.groupProfile, !profile.isEmpty {
            lines.append("Group Profile: \(profile)")
        }
        lines.append("</user_context>")
        lines.append("")

        lines.append("Evaluate and output the next step.")
        return lines.joined(separator: "\n")
    }

    // MARK: - JSON decoding

    /// Pulls a JSON object out of Claude's raw reply. The system prompt
    /// forbids markdown fences, but defenses-in-depth: if a future model
    /// regression slips one in, trim around the first `{` and last `}`
    /// before decoding so we don't drop a perfectly good decision on the
    /// floor.
    static func decode(_ raw: String) -> RouteDecision? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String
        if let openIdx = trimmed.firstIndex(of: "{"),
           let closeIdx = trimmed.lastIndex(of: "}"),
           openIdx <= closeIdx {
            candidate = String(trimmed[openIdx...closeIdx])
        } else {
            candidate = trimmed
        }

        guard let data = candidate.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(RouteDecision.self, from: data)
        } catch {
            dprint("RouteEvaluator: JSON decode failed — \(error). Raw: \(candidate.prefix(200))")
            return nil
        }
    }
}


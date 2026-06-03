import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device Apple Intelligence client via the Foundation Models
/// framework. No API key — the model runs on the user's device.
///
/// Availability:
/// - The framework itself requires iOS 26+ (canImport check below).
/// - The runtime also requires Apple-Intelligence-capable hardware
///   (`SystemLanguageModel.default.isAvailable`), which the user might
///   not have even on iOS 26.
///
/// On any combination that doesn't support it, `complete(...)` throws
/// `AIProviderError.unavailableOnThisDevice` and the caller falls
/// back as if no provider were configured.
public struct AppleIntelligenceClient: AIChatProvider {
    public init() {}

    public func complete(
        systemPrompt: String,
        contextBlock: String?,
        history: [AIChatTurn],
        userMessage: String,
        maxTokens: Int
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await runFoundationModelsRequest(
                systemPrompt: systemPrompt,
                contextBlock: contextBlock,
                history: history,
                userMessage: userMessage,
                maxTokens: maxTokens
            )
        } else {
            throw AIProviderError.unavailableOnThisDevice
        }
        #else
        throw AIProviderError.unavailableOnThisDevice
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func runFoundationModelsRequest(
        systemPrompt: String,
        contextBlock: String?,
        history: [AIChatTurn],
        userMessage: String,
        maxTokens: Int
    ) async throws -> String {
        // Hardware gate: if the device doesn't support Apple
        // Intelligence (older A-series chip, EU region without opt-in,
        // model not yet downloaded), we surface the same "unavailable"
        // error rather than letting a system error leak through.
        guard SystemLanguageModel.default.isAvailable else {
            throw AIProviderError.unavailableOnThisDevice
        }

        // Foundation Models splits durable guidance (instructions) from the
        // turn text (prompt). Put the system prompt AND the park context in
        // the instructions so the on-device model is grounded the same way
        // the cloud providers are. Previously the context block and history
        // were composed and then dropped — the session was built from the
        // system prompt alone and answered the bare user message, so it had
        // no idea which park it was in or what attractions actually exist
        // there. We don't keep a long-lived session because routing eval and
        // one-off chat turns don't benefit from it.
        var instructions = systemPrompt
        if let contextBlock, !contextBlock.isEmpty {
            instructions += "\n\n" + contextBlock
        }

        var prompt = ""
        for turn in history {
            let label = turn.role == .user ? "User" : "Assistant"
            prompt += "\(label): \(turn.text)\n\n"
        }
        prompt += "User: \(userMessage)"

        let session = LanguageModelSession(instructions: instructions)
        let response: String
        do {
            response = try await session.respond(to: prompt).content
        } catch {
            throw AIProviderError.network(error)
        }

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIProviderError.emptyResponse }
        return trimmed
    }
    #endif

    /// Tells the settings UI whether to enable the "Apple Intelligence"
    /// row or render it as a coming-soon placeholder.
    public static var isAvailableOnThisDevice: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
        #else
        return false
        #endif
    }
}

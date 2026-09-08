import Foundation
import Security

// MARK: - Shared types

/// One conversational turn in a chat exchange. Provider-agnostic; each
/// concrete client maps this into whatever shape its API requires.
public struct AIChatTurn: Codable, Hashable {
    public enum Role: String, Codable { case user, assistant }
    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// Uniform errors across providers so the call sites don't have to know
/// which API misbehaved.
public enum AIProviderError: LocalizedError {
    case missingAPIKey
    case unavailableOnThisDevice
    case network(Error)
    case badResponse(status: Int, body: String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an API key in Settings → AI Assistant first."
        case .unavailableOnThisDevice:
            return "This AI provider isn't available on this device."
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .badResponse(let status, let body):
            return "Provider returned HTTP \(status): \(body.prefix(200))"
        case .emptyResponse:
            return "Provider returned an empty response."
        }
    }
}

// MARK: - Provider protocol

/// Contract every concrete AI client conforms to. The existing Claude
/// client picked this shape first; OpenAI and Gemini are adapted to fit
/// rather than the other way around, so the call sites don't have to
/// care which one is active.
public protocol AIChatProvider {
    func complete(
        systemPrompt: String,
        contextBlock: String?,
        history: [AIChatTurn],
        userMessage: String,
        maxTokens: Int
    ) async throws -> String
}

// MARK: - Known providers

/// All AI services QueueBuddy knows how to talk to. The user picks one
/// in Settings. Each case knows enough about itself (display name,
/// model list, keychain identifier) that the settings view can render
/// a row without hardcoded knowledge of which providers exist.
public enum AIProviderKind: String, CaseIterable, Identifiable, Codable {
    case claude
    case openai
    case gemini
    case apple

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Anthropic Claude"
        case .openai: return "OpenAI ChatGPT"
        case .gemini: return "Google Gemini"
        case .apple:  return "Apple Intelligence"
        }
    }

    /// Short pill text for the active-provider chip in Settings.
    public var shortName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "ChatGPT"
        case .gemini: return "Gemini"
        case .apple:  return "Apple AI"
        }
    }

    /// Placeholder shown in the SecureField when no key is stored yet.
    public var keyPlaceholder: String {
        switch self {
        case .claude: return "sk-ant-..."
        case .openai: return "sk-..."
        case .gemini: return "AIza..."
        case .apple:  return ""
        }
    }

    public var keyHelpURL: URL? {
        switch self {
        case .claude: return URL(string: "https://console.anthropic.com/account/keys")
        case .openai: return URL(string: "https://platform.openai.com/api-keys")
        case .gemini: return URL(string: "https://aistudio.google.com/app/apikey")
        case .apple:  return nil
        }
    }

    /// Apple Intelligence runs on-device and needs no key.
    public var requiresAPIKey: Bool {
        switch self {
        case .apple: return false
        default:     return true
        }
    }

    /// One-liner shown under the provider name in the picker.
    public var blurb: String {
        switch self {
        case .claude: return "Fast, thoughtful. Default."
        case .openai: return "GPT-4-class models with broad knowledge."
        case .gemini: return "Google's models. Free tier is generous."
        case .apple:  return "On-device, private. Requires iOS 26+ on supported hardware."
        }
    }

    public var availableModels: [AIModelOption] {
        switch self {
        case .claude:
            return [
                AIModelOption(id: "claude-opus-4-7", displayName: "Claude Opus 4.7", subtitle: "Most capable. Slower, pricier."),
                AIModelOption(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", subtitle: "Balanced — recommended default."),
                AIModelOption(id: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5", subtitle: "Fastest, cheapest. Great for routing.")
            ]
        case .openai:
            return [
                AIModelOption(id: "gpt-4o", displayName: "GPT-4o", subtitle: "Flagship. Balanced cost / quality."),
                AIModelOption(id: "gpt-4o-mini", displayName: "GPT-4o mini", subtitle: "Cheap and quick — great for routing."),
                AIModelOption(id: "o1-mini", displayName: "o1-mini", subtitle: "Reasoning model. Slower, deeper.")
            ]
        case .gemini:
            return [
                AIModelOption(id: "gemini-2.0-flash", displayName: "Gemini 2.0 Flash", subtitle: "Fast, generous free tier."),
                AIModelOption(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", subtitle: "Highest-quality Gemini."),
                AIModelOption(id: "gemini-2.0-flash-lite", displayName: "Gemini 2.0 Flash-Lite", subtitle: "Cheapest. Good for routing.")
            ]
        case .apple:
            // The on-device Foundation Models framework only exposes
            // one model from the system — there's no "pick a variant"
            // story. Listed once so the settings UI still renders a row.
            return [AIModelOption(id: "apple-foundation",
                                  displayName: "Apple Foundation Model",
                                  subtitle: "On-device LLM. Picked automatically by iOS.")]
        }
    }

    public var defaultModelID: String {
        availableModels.first?.id ?? ""
    }
}

public struct AIModelOption: Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let subtitle: String
}

// MARK: - Registry

/// Single source of truth for "which AI service is active and what's its
/// key/model". Backed by UserDefaults for picks + Keychain for keys.
public enum AIProviderRegistry {

    /// UserDefaults key backing the active-provider choice. Exposed (not
    /// private) so views can observe it directly via @AppStorage and update
    /// the moment the user switches providers in Settings.
    static let activeProviderKey = "ai.activeProvider"

    /// Currently-selected provider. Defaults to Claude for back-compat
    /// with the original Claude-only build.
    public static func currentKind() -> AIProviderKind {
        guard let raw = UserDefaults.standard.string(forKey: activeProviderKey),
              let kind = AIProviderKind(rawValue: raw)
        else { return .claude }
        return kind
    }

    public static func setCurrentKind(_ kind: AIProviderKind) {
        UserDefaults.standard.set(kind.rawValue, forKey: activeProviderKey)
    }

    /// Instantiates a fresh client for whichever provider is active.
    /// Each call returns a value type / new instance — cheap, no need to
    /// cache.
    public static func currentClient() -> any AIChatProvider {
        switch currentKind() {
        case .claude: return ClaudeAIClient.shared
        case .openai: return OpenAIClient()
        case .gemini: return GeminiAIClient()
        case .apple:  return AppleIntelligenceClient()
        }
    }

    // MARK: - Per-provider key storage (Keychain)
    //
    // Claude's key keeps living in its original Keychain item
    // (`com.queuebuddy.anthropic`) so users who upgraded from the
    // Claude-only build don't lose their key. New providers get
    // identifiers under `QueueBuddy.AI.{rawValue}`.

    private static func keychainService(for kind: AIProviderKind) -> String {
        "QueueBuddy.AI.\(kind.rawValue)"
    }

    private static let keychainAccount = "apiKey"

    public static func readAPIKey(for kind: AIProviderKind) -> String? {
        if kind == .claude {
            return ClaudeAIClient.readAPIKey()
        }

        var query = baseQuery(for: kind)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    public static func storeAPIKey(_ key: String, for kind: AIProviderKind) {
        if kind == .claude {
            ClaudeAIClient.storeAPIKey(key)
            return
        }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            SecItemDelete(baseQuery(for: kind) as CFDictionary)
            return
        }
        guard let data = trimmed.data(using: .utf8) else { return }
        let query = baseQuery(for: kind)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert.merge(attributes) { _, new in new }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private static func baseQuery(for kind: AIProviderKind) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService(for: kind),
            kSecAttrAccount as String: keychainAccount
        ]
    }

    // MARK: - Per-provider model selection (UserDefaults)

    private static func modelKey(for kind: AIProviderKind) -> String {
        "ai.model.\(kind.rawValue)"
    }

    public static func currentModelID(for kind: AIProviderKind) -> String {
        if kind == .claude {
            return ClaudeAIClient.currentModelID()
        }
        return UserDefaults.standard.string(forKey: modelKey(for: kind)) ?? kind.defaultModelID
    }

    public static func setModelID(_ id: String, for kind: AIProviderKind) {
        if kind == .claude {
            ClaudeAIClient.setModelID(id)
            return
        }
        UserDefaults.standard.set(id, forKey: modelKey(for: kind))
    }

    // MARK: - Active-provider convenience

    /// True if the currently-selected provider is ready to use (has a
    /// key, or doesn't need one). Used by `RouteEvaluator` etc. to skip
    /// silently when there's nothing they can do.
    public static func currentIsConfigured() -> Bool {
        let kind = currentKind()
        if !kind.requiresAPIKey { return true }
        return readAPIKey(for: kind)?.isEmpty == false
    }
}

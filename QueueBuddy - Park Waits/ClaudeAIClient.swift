import Foundation

/// Anthropic API client for QueueBuddy's AI Assistant.
///
/// Talks to https://api.anthropic.com/v1/messages directly. Keeps the
/// system prompt and any bulky park context in cache_control blocks so
/// follow-up questions in the same session reuse the cache (much cheaper
/// and ~3-4x faster after the first turn).
actor ClaudeAIClient {
    static let shared = ClaudeAIClient()

    static let apiKeyDefaultsKey = "anthropicAPIKey"
    static let modelDefaultsKey = "anthropicModel"

    static let availableModels: [Model] = [
        Model(id: "claude-haiku-4-5-20251001",
              displayName: "Claude Haiku 4.5",
              subtitle: "Fastest • great for quick park questions"),
        Model(id: "claude-sonnet-4-6",
              displayName: "Claude Sonnet 4.6",
              subtitle: "Balanced reasoning and speed"),
        Model(id: "claude-opus-4-7",
              displayName: "Claude Opus 4.7",
              subtitle: "Deepest trip planning")
    ]

    struct Model: Identifiable, Hashable {
        let id: String
        let displayName: String
        let subtitle: String
    }

    struct Turn: Codable, Hashable {
        enum Role: String, Codable { case user, assistant }
        let role: Role
        let text: String
    }

    enum ClaudeError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case badResponse(status: Int, body: String)
        case emptyResponse
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add your Anthropic API key in AI Settings to start chatting."
            case .invalidURL:
                return "Couldn't build the Anthropic request URL."
            case .badResponse(let status, let body):
                return "Anthropic API returned \(status). \(body)"
            case .emptyResponse:
                return "The model replied with no text. Try again."
            case .network(let underlying):
                return "Network error: \(underlying.localizedDescription)"
            }
        }
    }

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let anthropicVersion = "2023-06-01"
    private let urlSession: URLSession

    init(session: URLSession = .shared) {
        self.urlSession = session
    }

    // MARK: - Public entry point

    func complete(
        systemPrompt: String,
        contextBlock: String?,
        history: [Turn],
        userMessage: String,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard let apiKey = Self.readAPIKey(), !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body = buildRequestBody(
            systemPrompt: systemPrompt,
            contextBlock: contextBlock,
            history: history,
            userMessage: userMessage,
            maxTokens: maxTokens
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw ClaudeError.network(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let bodyString = String(data: data, encoding: .utf8) ?? "<no body>"
            throw ClaudeError.badResponse(status: http.statusCode, body: bodyString)
        }

        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        let text = decoded.content.compactMap { $0.text }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ClaudeError.emptyResponse }
        return text
    }

    // MARK: - Configuration helpers

    nonisolated static func readAPIKey() -> String? {
        UserDefaults.standard.string(forKey: apiKeyDefaultsKey)
    }

    nonisolated static func storeAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: apiKeyDefaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: apiKeyDefaultsKey)
        }
    }

    nonisolated static func currentModelID() -> String {
        UserDefaults.standard.string(forKey: modelDefaultsKey) ?? availableModels[0].id
    }

    nonisolated static func setModelID(_ id: String) {
        UserDefaults.standard.set(id, forKey: modelDefaultsKey)
    }

    // MARK: - Request building

    private func buildRequestBody(
        systemPrompt: String,
        contextBlock: String?,
        history: [Turn],
        userMessage: String,
        maxTokens: Int
    ) -> [String: Any] {
        // System is an array of typed content blocks so we can mark the
        // expensive pieces (full system prompt + park context) as cacheable.
        var systemBlocks: [[String: Any]] = [[
            "type": "text",
            "text": systemPrompt,
            "cache_control": ["type": "ephemeral"]
        ]]
        if let contextBlock, !contextBlock.isEmpty {
            systemBlocks.append([
                "type": "text",
                "text": contextBlock,
                "cache_control": ["type": "ephemeral"]
            ])
        }

        var messages: [[String: Any]] = history.map { turn in
            [
                "role": turn.role.rawValue,
                "content": turn.text
            ]
        }
        messages.append([
            "role": "user",
            "content": userMessage
        ])

        return [
            "model": Self.currentModelID(),
            "max_tokens": maxTokens,
            "system": systemBlocks,
            "messages": messages
        ]
    }

    // MARK: - Response decoding

    private struct MessagesResponse: Decodable {
        let content: [ContentBlock]
    }

    private struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

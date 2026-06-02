import Foundation

/// OpenAI Chat Completions client. Adapts the provider-agnostic
/// `AIChatProvider` contract onto `https://api.openai.com/v1/chat/completions`.
///
/// API docs: https://platform.openai.com/docs/api-reference/chat
public struct OpenAIClient: AIChatProvider {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let urlSession: URLSession

    public init(session: URLSession = .shared) {
        self.urlSession = session
    }

    public func complete(
        systemPrompt: String,
        contextBlock: String?,
        history: [AIChatTurn],
        userMessage: String,
        maxTokens: Int
    ) async throws -> String {
        guard let apiKey = AIProviderRegistry.readAPIKey(for: .openai),
              !apiKey.isEmpty
        else { throw AIProviderError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        request.httpBody = try JSONSerialization.data(
            withJSONObject: buildBody(
                systemPrompt: systemPrompt,
                contextBlock: contextBlock,
                history: history,
                userMessage: userMessage,
                maxTokens: maxTokens
            ),
            options: []
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AIProviderError.network(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AIProviderError.badResponse(status: http.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw AIProviderError.emptyResponse }
        return text
    }

    // MARK: - Request body

    private func buildBody(
        systemPrompt: String,
        contextBlock: String?,
        history: [AIChatTurn],
        userMessage: String,
        maxTokens: Int
    ) -> [String: Any] {
        // OpenAI's chat schema: a flat array of {role, content} messages
        // with system rolled into role:"system". We fold the optional
        // context block into the system message rather than spawning a
        // second system entry — the spec technically allows multiple
        // system messages but some downstream models behave better with
        // one consolidated block.
        let mergedSystem: String
        if let contextBlock, !contextBlock.isEmpty {
            mergedSystem = systemPrompt + "\n\n" + contextBlock
        } else {
            mergedSystem = systemPrompt
        }

        var messages: [[String: Any]] = [["role": "system", "content": mergedSystem]]
        for turn in history {
            messages.append([
                "role": turn.role == .user ? "user" : "assistant",
                "content": turn.text
            ])
        }
        messages.append(["role": "user", "content": userMessage])

        return [
            "model": AIProviderRegistry.currentModelID(for: .openai),
            "messages": messages,
            "max_tokens": maxTokens
        ]
    }

    // MARK: - Response decoding

    private struct ChatCompletionResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: Message
            struct Message: Decodable {
                let content: String?
            }
        }
    }
}

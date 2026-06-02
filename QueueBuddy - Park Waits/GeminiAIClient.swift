import Foundation

/// Google Gemini client. Adapts the provider-agnostic `AIChatProvider`
/// contract onto Gemini's REST API at
/// `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`.
///
/// API docs: https://ai.google.dev/api/generate-content
public struct GeminiAIClient: AIChatProvider {
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
        guard let apiKey = AIProviderRegistry.readAPIKey(for: .gemini),
              !apiKey.isEmpty
        else { throw AIProviderError.missingAPIKey }

        let model = AIProviderRegistry.currentModelID(for: .gemini)
        // Gemini takes the key as a query parameter rather than a header.
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw AIProviderError.badResponse(status: -1, body: "Could not build Gemini URL for model \(model)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        let text = decoded.candidates
            .first?
            .content
            .parts
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        // Gemini uses `systemInstruction` for system content and a
        // `contents` array of {role, parts: [{text}]} for turns. The role
        // is "user" or "model" (not "assistant" — small but important).
        var systemText = systemPrompt
        if let contextBlock, !contextBlock.isEmpty {
            systemText += "\n\n" + contextBlock
        }

        var contents: [[String: Any]] = history.map { turn in
            [
                "role": turn.role == .user ? "user" : "model",
                "parts": [["text": turn.text]]
            ]
        }
        contents.append([
            "role": "user",
            "parts": [["text": userMessage]]
        ])

        return [
            "systemInstruction": ["parts": [["text": systemText]]],
            "contents": contents,
            "generationConfig": [
                "maxOutputTokens": maxTokens
            ]
        ]
    }

    // MARK: - Response decoding

    private struct GenerateContentResponse: Decodable {
        let candidates: [Candidate]
        struct Candidate: Decodable {
            let content: Content
            struct Content: Decodable {
                let parts: [Part]
                struct Part: Decodable {
                    let text: String?
                }
            }
        }
    }
}

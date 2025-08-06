// GeminiAIClient.swift

import Foundation
import GoogleGenerativeAI

class GeminiAIClient {
    static let shared = GeminiAIClient()
    
    private let model: GenerativeModel

    // Load your API key securely. For demo, you can hardcode it, but for production use a plist or environment variable.
    private let apiKey = "AIzaSyB6LFww5x83PhVkFYccEBD42hWaSgNHczo" // <-- Replace with your actual Gemini API key

    private init() {
        // Use the latest Gemini model name, e.g., "gemini-1.5-flash" or "gemini-1.5-pro"
        self.model = GenerativeModel(name: "gemini-1.5-flash", apiKey: apiKey)
    }

    /// Fetches a Gemini AI response for a given prompt and (optionally) context.
    func fetchGeminiResponse(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let response = try await model.generateContent(prompt)
                if let text = response.text {
                    completion(.success(text))
                } else {
                    completion(.failure(NSError(domain: "GeminiAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response text from Gemini."])))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}

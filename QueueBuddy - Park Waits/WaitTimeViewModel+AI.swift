import Foundation

extension WaitTimeViewModel {

    // MARK: - AI Conversation (Claude API)

    private static var systemPrompt: String {
        """
        You are QueueBuddy, a friendly and concise theme park guide for Walt Disney World and Universal Orlando (including Epic Universe).
        Use the park context provided to answer with specifics: current wait times, weather, and any height or accessibility constraints you're told about.
        The park context lists every ride under its correct land — treat that list as authoritative.
        Do NOT infer a ride's land from its name. If the context says Mine-Cart Madness is in Super Nintendo World — Donkey Kong Country, that's where it is, even if the name sounds like something else.
        Prefer bullet lists when recommending multiple rides. Keep answers under 180 words unless the question needs a step-by-step plan.
        If a ride is closed or the park is likely closed today, say so and suggest alternatives.
        If you don't know something, say so honestly instead of guessing.
        """
    }

    func fetchAIResponse(
        for query: String,
        parkContext: Park?,
        childHeight: Int? = nil,
        likes: [String]? = nil,
        dislikes: [String]? = nil
    ) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        isAILoading = true
        aiError = nil

        if let park = parkContext, weatherByPark[park.id] == nil {
            await fetchWeather(for: park)
        }

        let contextBlock = buildContextBlock(
            park: parkContext,
            childHeight: childHeight,
            likes: likes,
            dislikes: dislikes
        )

        // History must already exclude the brand-new user turn — we'll pass
        // the fresh message separately so the client can append it cleanly.
        let history = aiConversation.map { msg in
            ClaudeAIClient.Turn(
                role: msg.speaker == .user ? .user : .assistant,
                text: msg.text
            )
        }

        aiConversation.append(AIMessage(speaker: .user, text: trimmedQuery))

        do {
            let reply = try await aiClient.complete(
                systemPrompt: Self.systemPrompt,
                contextBlock: contextBlock,
                history: history,
                userMessage: trimmedQuery
            )
            aiConversation.append(AIMessage(speaker: .ai, text: reply))
            aiResponse = reply
        } catch let error as ClaudeAIClient.ClaudeError {
            aiError = error.errorDescription
        } catch {
            aiError = "Failed to get a response. \(error.localizedDescription)"
        }
        isAILoading = false
    }

    func buildContextBlock(
        park: Park?,
        childHeight: Int?,
        likes: [String]?,
        dislikes: [String]?
    ) -> String? {
        var parts: [String] = []

        if let park {
            parts.append("Park: \(park.name)")
            if isParkLikelyClosed(parkId: park.id) {
                parts.append("Note: this park appears to be closed or nearly closed right now.")
            }
            if let weather = weatherByPark[park.id] {
                parts.append("Weather: \(UserPreferences.formatTemperature(weather.temperature)), \(weather.description).")
            }
            if let attractions = attractionsByPark[park.id], !attractions.isEmpty {
                // Group by land so the AI sees each ride under its correct
                // location — prevents hallucinated lands (e.g. putting
                // Mine-Cart Madness in the Wizarding World because the
                // name sounds mine-themed).
                let byLand = Dictionary(grouping: attractions) { a in
                    StaticData.attractionToLandMapping[a.id] ?? "Other"
                }

                var block = "Live attraction status (grouped by land — use these land assignments as ground truth):"
                for landName in byLand.keys.sorted() {
                    block += "\n\n" + landName.uppercased()
                    let sorted = (byLand[landName] ?? []).sorted { $0.name < $1.name }
                    for attraction in sorted {
                        let wait: String
                        if attraction.is_open == false {
                            wait = "Closed"
                        } else if let time = attraction.wait_time {
                            wait = time == 0 ? "walk-on" : "\(time) min"
                        } else {
                            wait = "wait unknown"
                        }
                        var line = "\n  - \(attraction.name): \(wait)"
                        if let minHeight = attraction.min_height_inches, minHeight > 0 {
                            line += " (min height \(minHeight)\")"
                        }
                        block += line
                    }
                }
                parts.append(block)
            }
        }

        if let childHeight { parts.append("Traveling child height: \(childHeight) inches.") }
        let planItems = ParkDayPlanStore.shared.items(for: park?.id)
        if !planItems.isEmpty {
            let names = planItems.map { item in
                item.isDone ? "\(item.attractionName) (done)" : item.attractionName
            }
            parts.append("My Day plan: \(names.joined(separator: ", ")).")
        }
        if let likes, !likes.isEmpty { parts.append("User likes: \(likes.joined(separator: ", ")).") }
        if let dislikes, !dislikes.isEmpty { parts.append("User dislikes: \(dislikes.joined(separator: ", ")).") }

        guard !parts.isEmpty else { return nil }
        return "[Current Context]\n" + parts.joined(separator: "\n\n")
    }

    func resetAIConversation() {
        aiConversation = []
        aiResponse = ""
        aiError = nil
    }
}

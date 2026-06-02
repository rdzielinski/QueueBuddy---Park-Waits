import Foundation

extension WaitTimeViewModel {

    // MARK: - AI Conversation (Claude API)

    private static var systemPrompt: String {
        """
        You are QueueBuddy, a friendly, concise theme park guide for Walt Disney World and Universal Orlando (including Epic Universe). You help guests plan their day around live wait times.

        PARK SCOPE — the most important rule:
        - When the context names a park, the guest is at (or planning) THAT park only. Every ride, show, or restaurant you recommend MUST come from that park's attraction list in the context.
        - Do NOT recommend, list, or build a plan around attractions from any other park or resort, and do NOT organize your answer by other parks. Only bring up another park if the guest explicitly asks you to compare parks or switch parks.
        - The attraction list in the context is the COMPLETE and authoritative roster for that park. If something is not in that list, it is not in this park — never invent attractions or pull in ones you remember from training.
        - Each attraction is listed under its land. Do NOT infer a ride's land from its name; use the land you are given. (If the context says Mine-Cart Madness is in Super Nintendo World — Donkey Kong Country, that's where it is, even if the name sounds like something else.)
        - Use the live wait times provided; never fabricate a wait time. If a wait is unknown, say so.
        - When no park is named in the context, you may discuss and compare the Orlando parks freely.

        Prefer bullet lists when recommending multiple rides. For a day plan, sequence the rides sensibly (group nearby lands to cut walking, or hit the shortest waits first) using only rides from the list. Keep answers under ~200 words unless a step-by-step plan needs more. If a ride or the whole park is closed, say so and suggest open alternatives from the same park. If you don't know something, say so honestly instead of guessing.
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
                userMessage: trimmedQuery,
                maxTokens: 1024
            )
            aiConversation.append(AIMessage(speaker: .ai, text: reply))
            aiResponse = reply
        } catch let error as AIProviderError {
            aiError = error.errorDescription
        } catch let error as ClaudeAIClient.ClaudeError {
            // Pre-multi-provider error type; kept so any code path still
            // throwing it surfaces a friendly message.
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
            parts.append("Planning park: \(park.name). Help the guest with THIS park only — every attraction you recommend must come from the list below, and don't bring up any other park unless the guest explicitly asks to compare or switch parks.")
            if isParkLikelyClosed(parkId: park.id) {
                parts.append("Note: this park appears to be closed or nearly closed right now.")
            }
            if let weather = weatherByPark[park.id] {
                parts.append("Weather: \(UserPreferences.formatTemperature(weather.temperature)), \(weather.description).")
            }
            // Ground on the live roster when we have it, otherwise fall back to
            // the static roster so the model always sees the authoritative list
            // of what's actually in this park. An empty list is what lets a
            // weaker model wander into other parks and invent rides.
            let liveAttractions = attractionsByPark[park.id] ?? []
            let attractions = liveAttractions.isEmpty
                ? StaticData.getStaticAttractions(for: park.id)
                : liveAttractions
            if !attractions.isEmpty {
                // Group by land so the AI sees each ride under its correct
                // location — prevents hallucinated lands (e.g. putting
                // Mine-Cart Madness in the Wizarding World because the
                // name sounds mine-themed).
                let byLand = Dictionary(grouping: attractions) { a in
                    StaticData.attractionToLandMapping[a.id] ?? "Other"
                }

                var block = "These are the ONLY attractions at \(park.name), grouped by land. Treat this list, the land assignments, and the wait times as ground truth — do NOT recommend or mention any attraction that is not in this list:"
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
            let names = planItems.map { $0.attractionName }
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

    /// Best-effort scan of an AI reply for ride mentions in the given
    /// park. Used by Plan to surface an "Add to My Day" affordance under
    /// AI suggestions — false negatives are fine, false positives are
    /// what we work to avoid (hence the 5-char floor and full-name match
    /// after normalization).
    func attractionsMentioned(in reply: String, parkId: Int) -> [Attraction] {
        guard let attractions = attractionsByPark[parkId] else { return [] }
        let normalizedReply = Self.normalizeForRideMatch(reply)
        var seen = Set<Int>()
        var hits: [Attraction] = []
        for attraction in attractions {
            let normalizedName = Self.normalizeForRideMatch(attraction.name)
            guard normalizedName.count >= 5 else { continue }
            guard normalizedReply.contains(normalizedName) else { continue }
            if seen.insert(attraction.id).inserted {
                hits.append(attraction)
            }
        }
        return hits
    }

    private static func normalizeForRideMatch(_ s: String) -> String {
        let lowered = s.lowercased()
        var buffer = ""
        buffer.reserveCapacity(lowered.count)
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
            } else {
                buffer.append(" ")
            }
        }
        return buffer.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }
}

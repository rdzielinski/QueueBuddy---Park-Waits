import Foundation
import SwiftUI
import Combine
import BackgroundTasks
import UserNotifications
import GoogleGenerativeAI
import CoreLocation

@MainActor
class WaitTimeViewModel: ObservableObject {

    // MARK: - Published Properties
    
    @Published var resortGroups: [ResortGroup] = []
    @Published var attractionsByPark: [Int: [Attraction]] = [:]
    @Published var attractionsByParkGroupedByLand: [Int: [LandDisplayGroup]] = [:]
    @Published var eventsByPark: [Int: [Event]] = [:]
    @Published var weatherByPark: [Int: WeatherForecast] = [:]
    @Published var favoriteAttractionIds: Set<Int> = []
    @Published var notificationPreferences: [NotificationPreference] = []
    @Published var isLoading: Bool = true
    @Published var isAILoading: Bool = false
    @Published var aiResponse: String = ""
    @Published var aiError: String?
    @Published var searchTerm: String = ""
    @Published var currentSort: AttractionSort = .nameAsc
    @Published var currentFilter: AttractionFilter = .all
    @Published var showMaxWaitTimeFilter: Bool = false
    @Published var maxWaitTimeFilterValue: Int = 60
    @Published var isTiming: Bool = false
    @Published var timingEntityId: Int?
    @Published var elapsed: TimeInterval = 0
    @Published var recordedWaitTimes: [Int: [TimeInterval]] = [:]
    @Published var errorMessage: String?
    @Published var aiConversation: [String] = []
    @Published var myDayMapCenter: CLLocationCoordinate2D?

    // MARK: - Private Properties
    
    static let backgroundAppRefreshTaskId = "Dzielinski.QueueBuddy---Park-Waits.apprefresh"
    static let backgroundDataRefreshTaskId = "Dzielinski.QueueBuddy---Park-Waits.datarefresh"
    private var timerTask: Task<Void, Error>?
    private let api = ThemeParkAPI.shared
    private let attractionDetails: [Int: (name: String, parkId: Int, type: String?, description: String?, minHeight: Int?, lat: Double?, lon: Double?)]

    // Gemini AI SDK
    private let geminiModel: GenerativeModel

    init() {
        self.attractionDetails = StaticData.getAttractionDetails()
        self.geminiModel = GenerativeModel(name: "gemini-1.5-flash", apiKey: "AIzaSyB6LFww5x83PhVkFYccEBD42hWaSgNHczo")
        loadFavorites()
        loadNotificationPreferences()
        requestNotificationAuthorization()
    }

    // MARK: - Notification Authorization

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            if granted {
                print("Notification authorization granted.")
            } else {
                print("Notification authorization denied.")
            }
        }
    }

    // MARK: - Computed Properties
    
    var globalSearchResults: [Attraction] {
        let allAttractions = attractionsByPark.values.flatMap { $0 }
        let searchedAttractions = allAttractions.filter { searchTerm.isEmpty || $0.name.localizedCaseInsensitiveContains(searchTerm) }
        let filteredAttractions = searchedAttractions.filter { attraction in
            switch currentFilter {
            case .all: return true
            case .operating: return attraction.is_open == true
            case .shortWait: return (attraction.wait_time ?? Int.max) < 20
            case .moderateWait:
                guard let wait = attraction.wait_time else { return false }
                return wait >= 20 && wait <= 60
            case .longWait: return (attraction.wait_time ?? 0) > 60
            }
        }
        switch currentSort {
        case .nameAsc: return filteredAttractions.sorted { $0.name < $1.name }
        case .waitTimeAsc: return filteredAttractions.sorted { $0.comparableWaitTime < $1.comparableWaitTime }
        case .waitTimeDesc: return filteredAttractions.sorted { $0.comparableWaitTime > $1.comparableWaitTime }
        }
    }

    // MARK: - Data Loading & Processing

    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        do {
            let groups = try await api.fetchResortGroups()
            self.resortGroups = groups

            // Pre-populate all parks with their complete attraction list from static data.
            for park in groups.flatMap({ $0.parks }) {
                let staticAttractions = StaticData.getStaticAttractions(for: park.id)
                self.processAndStoreAttractions(staticAttractions, for: park.id, isUpdating: false)
            }

            // Fetch live data one park at a time, with a delay to avoid rate limiting.
            for group in groups {
                for park in group.parks {
                    do {
                        let liveAttractions = try await self.api.fetchWaitTimes(for: park.id)
                        self.processAndStoreAttractions(liveAttractions, for: park.id, isUpdating: true)
                        // Add a small delay to avoid rate limiting (0.5 seconds)
                        try await Task.sleep(nanoseconds: 500_000_000)
                    } catch {
                        print("Error fetching for park \(park.id): \(error)")
                    }
                }
            }
            // After loading, check for notification triggers
            await checkAndSendAttractionNotifications()
        } catch {
            print("❌ ERROR during initial data load: \(error.localizedDescription)")
            self.errorMessage = "Failed to load park data. Please check your internet connection and try again."
        }
        isLoading = false
    }

    private func processAndStoreAttractions(_ attractions: [Attraction], for parkId: Int, isUpdating: Bool) {
        let staticAttractions = StaticData.getStaticAttractions(for: parkId)
        var mergedAttractions: [Attraction] = []

        if !isUpdating {
            // Initial setup from static data
            mergedAttractions = staticAttractions
        } else {
            // Merge live data with static data
            var staticMap = Dictionary(uniqueKeysWithValues: staticAttractions.map { ($0.id, $0) })
            for live in attractions {
                if var staticAttr = staticMap[live.id] {
                    staticAttr.wait_time = live.wait_time
                    staticAttr.is_open = live.is_open
                    staticAttr.status = live.status
                    staticAttr.last_updated = Date().ISO8601Format()
                    staticMap[live.id] = staticAttr
                } else {
                    staticMap[live.id] = live
                }
            }
            mergedAttractions = Array(staticMap.values)
        }
        self.attractionsByPark[parkId] = mergedAttractions.sorted { $0.name < $1.name }
    }

    // MARK: - Notification Logic

    private func checkAndSendAttractionNotifications() async {
        let center = UNUserNotificationCenter.current()
        for preference in notificationPreferences {
            if let attraction = attractionsByPark.values.flatMap({ $0 }).first(where: { $0.id == preference.id }),
               let wait = attraction.wait_time,
               attraction.is_open == true,
               wait <= preference.thresholdMinutes {
                let content = UNMutableNotificationContent()
                content.title = "QueueBuddy Alert"
                content.body = "\(attraction.name) is now at \(wait) min wait or less!"
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "wait-\(attraction.id)-\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: nil // deliver immediately
                )
                do {
                    try await center.add(request)
                } catch {
                    print("Failed to schedule notification: \(error)")
                }
            }
        }
    }

    // MARK: - Background Refresh

    func handleAppRefresh(task: BGAppRefreshTask) {
        Self.scheduleNextAppRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        Task {
            await self.loadInitialData()
            task.setTaskCompleted(success: true)
        }
    }

    static func scheduleNextAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundAppRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60) // every 10 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule next app refresh: \(error)")
        }
    }

    // MARK: - Attractions By Land (Public Function Needed for ParkDetailView)
    func attractionsByLand(for parkId: Int) -> [LandDisplayGroup] {
        guard let parkAttractions = attractionsByPark[parkId] else { return [] }
        let groupedByLand = Dictionary(grouping: parkAttractions) { StaticData.attractionToLandMapping[$0.id] ?? "Other Attractions" }
        return groupedByLand.map { LandDisplayGroup(name: $0.key, attractions: $0.value.sorted(by: { $0.name < $1.name })) }.sorted { $0.name < $1.name }
    }

    func averageWaitTime(for parkId: Int) -> String {
        guard let attractions = attractionsByPark[parkId], !attractions.isEmpty else { return "N/A" }
        let waitTimes = attractions.compactMap { $0.wait_time }
        guard !waitTimes.isEmpty else { return "N/A" }
        let total = waitTimes.reduce(0, +)
        return "\(total / waitTimes.count) min"
    }

    func operatingAttractionCount(for parkId: Int) -> Int {
        return attractionsByPark[parkId]?.filter { $0.is_open == true }.count ?? 0
    }

    // MARK: - Weather (Open-Meteo, imperial units)
    func fetchWeather(for park: Park) async {
        if weatherByPark[park.id] != nil { return }
        do {
            if let forecast = try await api.fetchWeatherForecast(for: park.id) {
                self.weatherByPark[park.id] = forecast
            }
        } catch {
            print("Error fetching weather for park \(park.id): \(error.localizedDescription)")
        }
    }

    // MARK: - Events & Timer

    func startTimer<T: Identifiable>(for entity: T) where T.ID == Int {
        resetTimer()
        isTiming = true
        timingEntityId = entity.id
        
        timerTask = Task {
            while !Task.isCancelled {
                try await Task.sleep(for: .milliseconds(100))
                elapsed += 0.1
            }
        }
    }

    func stopTimerAndSave() {
        guard let id = timingEntityId else { return }
        timerTask?.cancel()
        timerTask = nil
        var times = recordedWaitTimes[id, default: []]
        times.append(elapsed)
        recordedWaitTimes[id] = times
        isTiming = false
        timingEntityId = nil
    }

    func resetTimer() {
        timerTask?.cancel()
        timerTask = nil
        isTiming = false
        timingEntityId = nil
        elapsed = 0
    }
    
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func waitTimes(forEntityId id: Int) -> [TimeInterval] {
        return recordedWaitTimes[id, default: []]
    }

    // MARK: - Manual Wait Time
    
    func addWaitTime(_ seconds: Double, forEntityId id: Int) {
        let minutes = Int(seconds / 60)
        print("✅ Manually adding a wait time of \(minutes) minutes for entity ID: \(id).")
    }
    
    // MARK: - Favorites
    
    func isFavorited(attractionId: Int) -> Bool {
        favoriteAttractionIds.contains(attractionId)
    }

    func toggleFavorite(attractionId: Int) {
        if isFavorited(attractionId: attractionId) {
            favoriteAttractionIds.remove(attractionId)
        } else {
            favoriteAttractionIds.insert(attractionId)
        }
        saveFavorites()
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteAttractionIds) {
            UserDefaults.standard.set(data, forKey: "favorites")
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favorites") {
            if let decoded = try? JSONDecoder().decode(Set<Int>.self, from: data) {
                self.favoriteAttractionIds = decoded
            }
        }
    }
    
    // MARK: - Notifications
    
    func isNotificationSet(for attractionId: Int) -> Bool {
        notificationPreferences.contains { $0.id == attractionId }
    }

    func addNotification(for attraction: Attraction, threshold: Int) {
        removeNotification(for: attraction.id)
        let newPreference = NotificationPreference(id: attraction.id, attractionName: attraction.name, thresholdMinutes: threshold)
        notificationPreferences.append(newPreference)
        saveNotificationPreferences()
    }

    func removeNotification(for attractionId: Int) {
        notificationPreferences.removeAll { $0.id == attractionId }
        saveNotificationPreferences()
    }
    
    private func saveNotificationPreferences() {
        if let data = try? JSONEncoder().encode(notificationPreferences) {
            UserDefaults.standard.set(data, forKey: "notifications")
        }
    }

    private func loadNotificationPreferences() {
        if let data = UserDefaults.standard.data(forKey: "notifications") {
            if let decoded = try? JSONDecoder().decode([NotificationPreference].self, from: data) {
                self.notificationPreferences = decoded
            }
        }
    }
    
    // MARK: - AI Conversation (Gemini SDK, Context-Aware, Weather in Imperial)
    func fetchAIResponse(
        for query: String,
        parkContext: Park?,
        childHeight: Int? = nil,
        likes: [String]? = nil,
        dislikes: [String]? = nil
    ) async {
        isAILoading = true
        aiError = nil

        if let park = parkContext, weatherByPark[park.id] == nil {
            await fetchWeather(for: park)
        }

        aiConversation.append("User: \(query)")

        var prompt = "You are QueueBuddy, a helpful, friendly, and concise theme park assistant. You are having a conversation with the user. Remember what the user has said so far and use all the data provided below. If you don't know, say so honestly.\n\n"
        prompt += aiConversation.joined(separator: "\n") + "\n"

        if let park = parkContext {
            prompt += "\nCurrent Park: \(park.name)"
        }

        if let park = parkContext, let weather = weatherByPark[park.id] {
            prompt += "\nCurrent Weather: \(Int(weather.temperature))°F, \(weather.description.capitalized)."
        }

        if let park = parkContext, let attractions = attractionsByPark[park.id], !attractions.isEmpty {
            prompt += "\n\nCurrent Attraction Wait Times:\n"
            for attraction in attractions.sorted(by: { $0.name < $1.name }) {
                let wait = attraction.is_open == true ? "\(attraction.wait_time ?? 0) min" : "Closed"
                prompt += "- \(attraction.name): \(wait)\n"
            }
        }

        if let height = childHeight {
            prompt += "\nChild Height: \(height) inches."
        }

        if let likes = likes, !likes.isEmpty {
            prompt += "\nUser Likes: \(likes.joined(separator: ", "))."
        }
        if let dislikes = dislikes, !dislikes.isEmpty {
            prompt += "\nUser Dislikes: \(dislikes.joined(separator: ", "))."
        }

        prompt += "\n\nIf the user asks for recommendations, consider the weather, wait times, height requirements, and their likes/dislikes. If the user asks for a specific wait time or weather, answer directly. If you don't have enough info, ask a clarifying question or say so. Be logical, reason step by step, and remember the conversation context."

        do {
            let response = try await geminiModel.generateContent(prompt)
            if let text = response.text {
                aiConversation.append("AI: \(text)")
                self.aiResponse = text
            } else {
                self.aiError = "No response text from Gemini."
            }
        } catch {
            self.aiError = "Failed to get a response from the AI assistant. \(error.localizedDescription)"
        }
        isAILoading = false
    }

    func resetAIConversation() {
        aiConversation = []
        aiResponse = ""
        aiError = nil
    }
    
    // MARK: - Color Logic
    
    static func statusColor(status: String?, waitTime: Int?, isOpen: Bool?) -> Color {
        guard isOpen ?? true else { return .gray }
        if let status = status?.lowercased(), status == "closed" || status == "down" {
            return .red
        }
        guard let wait = waitTime else { return .purple }
        
        switch wait {
        case 0...19: return .green
        case 20...45: return .orange
        default: return .red
        }
    }
}
import Foundation

extension WaitTimeViewModel {
    /// Returns true if the park is likely closed (most attractions are closed or down).
    func isParkLikelyClosed(parkId: Int) -> Bool {
        guard let attractions = attractionsByPark[parkId], !attractions.isEmpty else { return false }
        let closedOrDown = attractions.filter {
            let status = $0.status?.lowercased() ?? ""
            return $0.is_open == false || status == "closed" || status == "down"
        }
        let open = attractions.filter {
            let status = $0.status?.lowercased() ?? ""
            return $0.is_open == true && status != "closed" && status != "down"
        }
        // If more than 80% of attractions are closed/down and fewer than 3 are open, assume park is closed
        return closedOrDown.count > Int(Double(attractions.count) * 0.8) && open.count < 3
    }
}

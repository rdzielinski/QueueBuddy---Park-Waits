import Foundation
import SwiftUI
import Combine
import BackgroundTasks
import UserNotifications
import CoreLocation
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
class WaitTimeViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var resortGroups: [ResortGroup] = []
    @Published var attractionsByPark: [Int: [Attraction]] = [:]
    @Published var attractionsByParkGroupedByLand: [Int: [LandDisplayGroup]] = [:]
    @Published var eventsByPark: [Int: [Event]] = [:]
    @Published var weatherByPark: [Int: WeatherForecast] = [:]
    /// Today's operating schedule per park (live hours + Early Entry +
    /// Lightning Lane purchases). Populated only for parks routed through
    /// ThemeParks.wiki; falls back to `StaticData.parkHours` otherwise.
    @Published var scheduleByPark: [Int: ParkSchedule] = [:]
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
    @Published var aiConversation: [AIMessage] = []
    /// Drives chrome accents (tab bar, system tint) based on whichever park
    /// the user is currently viewing. Nil when no park is focused.
    @Published var activeParkId: Int? = nil

    struct AIMessage: Identifiable, Hashable {
        enum Speaker { case user, ai }
        let id = UUID()
        let speaker: Speaker
        let text: String
    }

    // MARK: - Private Properties

    static let backgroundAppRefreshTaskId = "Dzielinski.QueueBuddy---Park-Waits.apprefresh"
    static let backgroundDataRefreshTaskId = "Dzielinski.QueueBuddy---Park-Waits.datarefresh"
    private var timerTask: Task<Void, Error>?
    private var foregroundRefreshTask: Task<Void, Never>?
    /// How often to auto-refresh while the app is foregrounded. Lower than
    /// the BG refresh cadence so an active Live Activity stays current.
    private static let foregroundRefreshInterval: TimeInterval = 5 * 60
    private let api = ThemeParkAPI.shared
    let aiClient = ClaudeAIClient.shared

    init() {
        loadFavorites()
        loadNotificationPreferences()
        requestNotificationAuthorization()
    }

    // MARK: - Notification Authorization

    private func requestNotificationAuthorization() {
        #if os(tvOS)
        let options: UNAuthorizationOptions = [.badge]
        #else
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        #endif
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
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

            // Pre-populate all parks. Use offline-first data (typical waits) when
            // no cached snapshot exists, so the UI has useful data immediately.
            let hasCachedData = WaitCacheStore.hasCachedData()
            for park in groups.flatMap({ $0.parks }) {
                let staticAttractions = hasCachedData
                    ? StaticData.getStaticAttractions(for: park.id)
                    : StaticData.getOfflineAttractions(for: park.id)
                self.processAndStoreAttractions(staticAttractions, for: park.id, isUpdating: false)
            }

            // Fetch live data for all parks concurrently. Much faster than the
            // old serial-with-sleep loop, and resilient to the enclosing Task
            // being cancelled mid-refresh (we detect it and skip the
            // not-yet-started work rather than printing CancellationError for
            // every remaining park).
            let allParks = groups.flatMap { $0.parks }
            let apiRef = api
            let results: [(Int, [Attraction])] = await withTaskGroup(of: (Int, [Attraction])?.self) { group in
                for park in allParks {
                    group.addTask {
                        if Task.isCancelled { return nil }
                        do {
                            let attractions = try await apiRef.fetchWaitTimes(for: park.id)
                            return (park.id, attractions)
                        } catch is CancellationError {
                            return nil
                        } catch {
                            print("Error fetching for park \(park.id): \(error)")
                            return nil
                        }
                    }
                }
                var collected: [(Int, [Attraction])] = []
                for await result in group {
                    if let result { collected.append(result) }
                }
                return collected
            }

            for (parkId, liveAttractions) in results {
                AttractionDataAudit.record(parkId: parkId, liveAttractions: liveAttractions)
                processAndStoreAttractions(liveAttractions, for: parkId, isUpdating: true)
                for attraction in liveAttractions where attraction.is_open == true {
                    if let wait = attraction.wait_time {
                        WaitHistoryStore.shared.record(attractionId: attraction.id, minutes: wait)
                    }
                }
            }

            if !results.isEmpty {
                NetworkMonitor.shared.markSuccessfulSync()
                updateSharedCache()
            }

            // Fetch park schedules (live hours + LL prices) in parallel.
            // Only ThemeParks.wiki-routed parks return data; the rest no-op.
            await refreshParkSchedules(parks: allParks)

            // After loading, check for notification triggers and push the
            // freshest wait into any running in-line Live Activity.
            await checkAndSendAttractionNotifications()
            AttractionDataAudit.logReport()
            refreshActiveLiveActivity()
        } catch is CancellationError {
            // Refresh was cancelled (user navigated away). Not an error.
        } catch {
            print("❌ ERROR during initial data load: \(error.localizedDescription)")
            self.errorMessage = "Failed to load park data. Please check your internet connection and try again."
        }
        isLoading = false
    }

    /// Refresh live waits for a single park. Safe to call from pull-to-refresh
    /// inside ParkDetailView without triggering the global fetch loop.
    func refreshPark(_ park: Park) async {
        do {
            let liveAttractions = try await api.fetchWaitTimes(for: park.id)
            AttractionDataAudit.record(parkId: park.id, liveAttractions: liveAttractions)
            processAndStoreAttractions(liveAttractions, for: park.id, isUpdating: true)
            recordHistory(liveAttractions)
            if let schedule = await api.fetchSchedule(for: park.id) {
                scheduleByPark[park.id] = schedule
            }
            updateSharedCache()
            await checkAndSendAttractionNotifications()
            refreshActiveLiveActivity()
        } catch is CancellationError {
            // Ignore — user left the view.
        } catch {
            print("Error refreshing park \(park.id): \(error.localizedDescription)")
        }
    }

    private func recordHistory(_ attractions: [Attraction]) {
        for attraction in attractions where attraction.is_open == true {
            if let wait = attraction.wait_time {
                WaitHistoryStore.shared.record(attractionId: attraction.id, minutes: wait)
            }
        }
    }

    /// Snapshot the current state into the shared cache so the widget,
    /// watch, App Intents, and Live Activity can read it without a network.
    func updateSharedCache() {
        let parks = resortGroups.flatMap { $0.parks }
        let snapshots: [WaitCacheStore.CachedPark] = parks.map { park in
            let attractions = (attractionsByPark[park.id] ?? [])
                .sorted { $0.name < $1.name }
                .map {
                    WaitCacheStore.CachedAttraction(
                        id: $0.id,
                        name: $0.name,
                        waitMinutes: $0.wait_time,
                        isOpen: $0.is_open ?? true,
                        minHeightInches: $0.min_height_inches
                    )
                }
            let openCount = attractions.filter { $0.isOpen }.count
            let validWaits = attractions.compactMap { $0.waitMinutes }
            let avg = validWaits.isEmpty ? nil : validWaits.reduce(0, +) / validWaits.count
            let accent = DB.accentHexValue(for: park.id)
            return WaitCacheStore.CachedPark(
                id: park.id,
                name: park.name,
                accentHex: accent,
                openCount: openCount,
                totalCount: attractions.count,
                avgWait: avg,
                attractions: attractions
            )
        }
        WaitCacheStore.save(parks: snapshots)
    }

    /// Refresh live waits for every park without resetting their attraction
    /// lists first. Meant for pull-to-refresh on aggregate views like
    /// Favorites — won't wipe already-loaded data if a fetch fails.
    func refreshAllWaits() async {
        let allParks = resortGroups.flatMap { $0.parks }
        guard !allParks.isEmpty else {
            await loadInitialData()
            return
        }

        let apiRef = api
        let results: [(Int, [Attraction])] = await withTaskGroup(of: (Int, [Attraction])?.self) { group in
            for park in allParks {
                group.addTask {
                    if Task.isCancelled { return nil }
                    do {
                        let attractions = try await apiRef.fetchWaitTimes(for: park.id)
                        return (park.id, attractions)
                    } catch is CancellationError {
                        return nil
                    } catch {
                        print("Error refreshing park \(park.id): \(error.localizedDescription)")
                        return nil
                    }
                }
            }
            var collected: [(Int, [Attraction])] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }

        for (parkId, liveAttractions) in results {
            AttractionDataAudit.record(parkId: parkId, liveAttractions: liveAttractions)
            processAndStoreAttractions(liveAttractions, for: parkId, isUpdating: true)
            recordHistory(liveAttractions)
        }

        if !results.isEmpty {
            NetworkMonitor.shared.markSuccessfulSync()
            updateSharedCache()
        }

        await refreshParkSchedules(parks: allParks)
        await checkAndSendAttractionNotifications()
        refreshActiveLiveActivity()
    }

    /// Refresh today's schedule (open/close, LL purchases, Early Entry) for
    /// every park concurrently. No-op for parks still on queue-times.
    private func refreshParkSchedules(parks: [Park]) async {
        let apiRef = api
        let results: [(Int, ParkSchedule)] = await withTaskGroup(of: (Int, ParkSchedule)?.self) { group in
            for park in parks {
                group.addTask {
                    if Task.isCancelled { return nil }
                    if let schedule = await apiRef.fetchSchedule(for: park.id) {
                        return (park.id, schedule)
                    }
                    return nil
                }
            }
            var collected: [(Int, ParkSchedule)] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }
        for (parkId, schedule) in results {
            scheduleByPark[parkId] = schedule
        }
    }

    /// Today's Early Entry window for the park, if Disney/Universal is
    /// running one. Resort-guest users get exclusive early access; we
    /// surface this on the park detail so they know to arrive early.
    func earlyEntryWindow(parkId: Int) -> (Date, Date)? {
        guard let ee = scheduleByPark[parkId]?.earlyEntry else { return nil }
        return (ee.openingTime, ee.closingTime)
    }

    /// Today's Lightning Lane purchase options for the park (multi-pass,
    /// per-attraction LL, etc.), with live availability and pricing.
    func lightningLane(parkId: Int) -> [LightningLanePurchase] {
        scheduleByPark[parkId]?.lightningLane ?? []
    }

    private func processAndStoreAttractions(_ attractions: [Attraction], for parkId: Int, isUpdating: Bool) {
        let staticAttractions = StaticData.getStaticAttractions(for: parkId)
        var mergedAttractions: [Attraction] = []

        if !isUpdating {
            // Initial setup from static data
            mergedAttractions = staticAttractions
        } else {
            // Merge live data with static data. ThemeParks.wiki adds
            // forecast, per-attraction operating hours, and Lightning
            // Lane / return-time state — preserve those on the merged
            // entity. Static metadata (lands, descriptions, coordinates)
            // stays from the static row.
            var staticMap = Dictionary(uniqueKeysWithValues: staticAttractions.map { ($0.id, $0) })
            for live in attractions {
                if var staticAttr = staticMap[live.id] {
                    staticAttr.wait_time = live.wait_time
                    staticAttr.is_open = live.is_open
                    staticAttr.status = live.status
                    staticAttr.last_updated = Date().ISO8601Format()
                    staticAttr.forecast = live.forecast
                    staticAttr.operatingStart = live.operatingStart
                    staticAttr.operatingEnd = live.operatingEnd
                    staticAttr.returnTime = live.returnTime
                    staticMap[live.id] = staticAttr
                } else {
                    staticMap[live.id] = live
                }
            }
            mergedAttractions = Array(staticMap.values)
        }
        self.attractionsByPark[parkId] = mergedAttractions.sorted { $0.name < $1.name }
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

    /// Submit the next BG refresh request. Idempotent — calling repeatedly
    /// just resets the earliest-begin window. Must be called on launch
    /// (the in-handler reschedule alone never fires the *first* task).
    static func scheduleNextAppRefresh() {
        // Honor the in-app toggle. Also cancels any previously-queued
        // request so the OS won't wake us if the user just turned it off.
        guard UserPreferences.backgroundRefreshEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundAppRefreshTaskId)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: backgroundAppRefreshTaskId)
        let earliest = Date(timeIntervalSinceNow: 10 * 60)
        request.earliestBeginDate = earliest
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 BG refresh queued, earliest: \(earliest)")
        } catch {
            // Common failures:
            //   - BGTaskSchedulerErrorDomain code 1 (unavailable): iOS
            //     simulator or Background App Refresh disabled in Settings
            //   - code 3 (tooManyPendingTaskRequests): already queued
            print("❌ Could not schedule BG refresh: \(error.localizedDescription)")
        }
    }

    // MARK: - Foreground auto-refresh

    /// Start a repeating foreground refresh while the app is active. The
    /// background task only fires every 10+ minutes at the OS's discretion,
    /// so without this an in-line Live Activity displayed while the app is
    /// open would only refresh on user pull-to-refresh.
    func startForegroundAutoRefresh() {
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.foregroundRefreshInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self.refreshAllWaits()
            }
        }
    }

    func stopForegroundAutoRefresh() {
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = nil
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
        WaitHistoryStore.shared.record(attractionId: id, minutes: minutes)
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
            WaitCacheStore.defaults.set(data, forKey: WaitCacheStore.favoritesKey)
        }
        updateSharedCache()
    }

    private func loadFavorites() {
        if let data = WaitCacheStore.defaults.data(forKey: WaitCacheStore.favoritesKey)
            ?? UserDefaults.standard.data(forKey: "favorites") {
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
        // Forget the dedup edge state too so a future re-add starts fresh.
        NotificationDedupStore.clear(attractionId: attractionId)
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

    // MARK: - Crowd Level

    func crowdLevel(for parkId: Int) -> CrowdLevel? {
        guard let attractions = attractionsByPark[parkId] else { return nil }
        let waits = attractions.compactMap { $0.is_open == true ? $0.wait_time : nil }
        guard !waits.isEmpty else { return nil }
        let avg = waits.reduce(0, +) / waits.count
        return CrowdLevel.from(averageWait: avg)
    }

    /// Today's park hours as a human-readable range. Uses live data from
    /// ThemeParks.wiki when available; falls back to `StaticData.parkHours`
    /// for parks still on queue-times.
    func parkHoursText(for parkId: Int) -> String? {
        if let live = scheduleByPark[parkId]?.today {
            let f = UserPreferences.timeFormatter()
            f.timeZone = scheduleByPark[parkId]?.timezone.flatMap(TimeZone.init(identifier:)) ?? .current
            return "\(f.string(from: live.openingTime)) – \(f.string(from: live.closingTime))"
        }
        guard let hours = StaticData.parkHours[parkId] else { return nil }
        func fmt(_ h: Int) -> String {
            let twelve = ((h % 12) == 0) ? 12 : (h % 12)
            let suffix = h >= 12 && h < 24 ? "PM" : "AM"
            return "\(twelve) \(suffix)"
        }
        return "\(fmt(hours.openHour)) – \(fmt(hours.closeHour))"
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

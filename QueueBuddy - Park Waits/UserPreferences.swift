import Foundation

/// Centralized user-facing display preferences. All settings live in
/// `UserDefaults` so they round-trip across launches; static formatter
/// helpers below let display code render without owning the AppStorage
/// binding directly.
enum UserPreferences {

    // MARK: - Keys

    enum Key {
        static let tempUnit = "qb.settings.tempUnit"
        static let timeFormat = "qb.settings.timeFormat"
        static let defaultTab = "qb.settings.defaultTab"
        static let backgroundRefreshEnabled = "qb.settings.backgroundRefreshEnabled"
        static let notificationsEnabled = "qb.settings.notificationsEnabled"
        static let quietHoursEnabled = "qb.settings.quietHoursEnabled"
        static let quietHoursStart = "qb.settings.quietHoursStart"   // minutes from midnight
        static let quietHoursEnd = "qb.settings.quietHoursEnd"       // minutes from midnight
        static let defaultThresholdMinutes = "qb.settings.defaultThresholdMinutes"
    }

    // MARK: - Enums

    enum TempUnit: String, CaseIterable, Identifiable {
        case fahrenheit, celsius
        var id: String { rawValue }
        var symbol: String { self == .fahrenheit ? "°F" : "°C" }
        var shortLabel: String { self == .fahrenheit ? "F" : "C" }
    }

    enum TimeFormat: String, CaseIterable, Identifiable {
        case twelveHour, twentyFourHour
        var id: String { rawValue }
        var label: String { self == .twelveHour ? "12-hour" : "24-hour" }
    }

    // MARK: - Defaults

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.tempUnit: TempUnit.fahrenheit.rawValue,
            Key.timeFormat: TimeFormat.twelveHour.rawValue,
            Key.defaultTab: 0,                 // QBTab.parks
            Key.backgroundRefreshEnabled: true,
            Key.notificationsEnabled: true,
            Key.quietHoursEnabled: false,
            Key.quietHoursStart: 22 * 60,      // 10:00 PM
            Key.quietHoursEnd: 8 * 60,         // 8:00 AM
            Key.defaultThresholdMinutes: 15
        ])
    }

    // MARK: - Current values (read-only accessors)

    static var tempUnit: TempUnit {
        TempUnit(rawValue: UserDefaults.standard.string(forKey: Key.tempUnit) ?? "") ?? .fahrenheit
    }

    static var timeFormat: TimeFormat {
        TimeFormat(rawValue: UserDefaults.standard.string(forKey: Key.timeFormat) ?? "") ?? .twelveHour
    }

    static var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.notificationsEnabled)
    }

    static var backgroundRefreshEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.backgroundRefreshEnabled)
    }

    static var defaultThresholdMinutes: Int {
        let v = UserDefaults.standard.integer(forKey: Key.defaultThresholdMinutes)
        return v > 0 ? v : 15
    }

    // MARK: - Quiet hours

    /// Returns true if the current local time falls inside the configured
    /// quiet-hours window. Window wraps midnight when end <= start
    /// (e.g. 10pm → 8am).
    static func isInQuietHours(now: Date = Date()) -> Bool {
        guard UserDefaults.standard.bool(forKey: Key.quietHoursEnabled) else { return false }
        let start = UserDefaults.standard.integer(forKey: Key.quietHoursStart)
        let end = UserDefaults.standard.integer(forKey: Key.quietHoursEnd)
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if start == end { return false }
        if start < end {
            return nowMin >= start && nowMin < end
        } else {
            // Wraps midnight
            return nowMin >= start || nowMin < end
        }
    }

    /// True when notifications should be allowed to fire right now.
    static func shouldDeliverNotification(now: Date = Date()) -> Bool {
        notificationsEnabled && !isInQuietHours(now: now)
    }

    // MARK: - Temperature formatting

    /// Input is assumed Fahrenheit (the Open-Meteo client requests it that
    /// way). Converts to the user's chosen unit and returns a rounded
    /// integer with the degree symbol — e.g. "84°F" or "29°C".
    static func formatTemperature(_ fahrenheit: Double, includeUnit: Bool = true) -> String {
        let unit = tempUnit
        let value: Double
        switch unit {
        case .fahrenheit: value = fahrenheit
        case .celsius:    value = (fahrenheit - 32) * 5.0 / 9.0
        }
        let rounded = Int(value.rounded())
        return includeUnit ? "\(rounded)\(unit.symbol)" : "\(rounded)°"
    }

    // MARK: - Time formatting

    /// Returns a DateFormatter matching the user's 12/24-hour preference.
    /// Mirrors the `"h:mm a"` / `"HH:mm"` patterns used across the app.
    static func timeFormatter(compact: Bool = false) -> DateFormatter {
        let f = DateFormatter()
        switch timeFormat {
        case .twelveHour:
            f.dateFormat = compact ? "ha" : "h:mm a"
        case .twentyFourHour:
            f.dateFormat = compact ? "HH" : "HH:mm"
        }
        return f
    }
}

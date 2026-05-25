import Foundation

/// Google AdMob identifiers.
///
/// The companion `GADApplicationIdentifier` (the AdMob App ID) lives in
/// Info.plist; the SDK throws on launch if it's missing or invalid.
///
/// These are live production IDs. During development, register your test
/// devices (see `QueueBuddy___Park_WaitsApp`) so you never serve billable
/// ads to yourself — clicking your own live ads flags the account for
/// invalid traffic.
enum AdConfig {
    /// QueueBuddy banner ad unit.
    static let bannerUnitID = "ca-app-pub-4715603786314162/6303223159"

    /// Whether ad code should run at all. Lets you kill ads app-wide
    /// from one place (e.g. a future "remove ads" purchase).
    static let adsEnabled = true
}

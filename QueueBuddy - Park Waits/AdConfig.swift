import Foundation

/// Google AdMob identifiers.
///
/// These are seeded with Google's official *test* IDs so the app runs
/// (the SDK throws on launch if `GADApplicationIdentifier` is missing or
/// invalid) without risk of serving live ads to yourself during
/// development. Before shipping:
///
///   1. Replace `bannerUnitID` below with the banner unit you create for
///      QueueBuddy in the AdMob console.
///   2. Replace `GADApplicationIdentifier` in Info.plist with this app's
///      AdMob App ID.
///
/// AdMob App IDs and ad unit IDs are per-app — do not reuse IDs from
/// another app, or AdMob may flag the account for invalid traffic.
enum AdConfig {
    /// Google's public test banner unit. Always shows a "Test Ad".
    /// TODO: replace with the real QueueBuddy banner unit ID.
    static let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    /// Whether ad code should run at all. Lets you kill ads app-wide
    /// from one place (e.g. a future "remove ads" purchase).
    static let adsEnabled = true
}

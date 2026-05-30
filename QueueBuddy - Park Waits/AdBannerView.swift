import SwiftUI

// Targets Google Mobile Ads SDK v12+ (the class names dropped their
// "GAD" prefix in v12). If you pin v11 or earlier, the types below need
// the GAD prefix (GADBannerView, GADRequest, GADExtras, etc.).
//
// The whole banner is behind `#if canImport(GoogleMobileAds)` so the
// project keeps compiling before the Swift Package is added; once you
// add it in Xcode (File ▸ Add Package Dependencies ▸
// https://github.com/googleads/swift-package-manager-google-mobile-ads),
// the banner activates automatically.

#if canImport(GoogleMobileAds)
import GoogleMobileAds

/// SwiftUI container that pins a fixed 320×50 banner above the tab bar
/// and centers it horizontally. Mirrors the AdBannerContainerView
/// pattern from VillagesRemake, which has been stable in production.
struct BottomAdBanner: View {
    var body: some View {
        if AdConfig.adsEnabled {
            AdBannerRepresentable(adUnitID: AdConfig.bannerUnitID)
                .frame(width: 320, height: 50)
                .frame(maxWidth: .infinity)
                .background(DB.bg)
        }
    }
}

private struct AdBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        context.coordinator.bannerView = banner
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // Set rootViewController lazily — on first updateUIView the key
        // window isn't always attached yet.
        if banner.rootViewController == nil {
            banner.rootViewController = Self.rootViewController()
        }
        // One-shot load guard. SwiftUI calls updateUIView on every
        // parent re-render; without this gate each one would call
        // `.load()` again, every load spawns a fresh WKWebView, and a
        // handful of those is enough for jetsam to kill the process
        // with signal 9.
        if banner.rootViewController != nil && !context.coordinator.hasLoadedOnce {
            context.coordinator.hasLoadedOnce = true
            banner.load(Self.nonPersonalizedRequest())
        }
    }

    /// Non-personalized ad request — `npa=1` tells Google not to use
    /// the user's data for ad personalization, so we don't need ATT or
    /// a consent SDK.
    static func nonPersonalizedRequest() -> Request {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        weak var bannerView: BannerView?
        var hasLoadedOnce = false

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            dprint("AdMob: Banner ad loaded successfully")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            dprint("AdMob: Failed to load banner — \(error.localizedDescription)")
            // Retry after a delay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.hasLoadedOnce = false
                bannerView.load(AdBannerRepresentable.nonPersonalizedRequest())
            }
        }
    }
}

#else

/// Fallback used until the Google Mobile Ads package is added. Takes no
/// space so layouts are unaffected.
struct BottomAdBanner: View {
    var body: some View { EmptyView() }
}

#endif

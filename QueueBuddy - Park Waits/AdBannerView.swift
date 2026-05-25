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

/// SwiftUI container that pins an anchored adaptive banner above the tab
/// bar. Collapses to zero height until an ad is actually loaded, so there
/// is never an empty gap.
struct BottomAdBanner: View {
    @State private var adHeight: CGFloat = 0

    var body: some View {
        Group {
            if AdConfig.adsEnabled {
                GeometryReader { geo in
                    AdBannerRepresentable(
                        width: geo.size.width,
                        adUnitID: AdConfig.bannerUnitID,
                        onHeightChange: { adHeight = $0 }
                    )
                }
                .frame(height: adHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .background(adHeight > 0 ? DB.bg : .clear)
        .animation(.easeInOut(duration: 0.25), value: adHeight)
    }
}

private struct AdBannerRepresentable: UIViewRepresentable {
    let width: CGFloat
    let adUnitID: String
    let onHeightChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onHeightChange: onHeightChange)
    }

    func makeUIView(context: Context) -> BannerView {
        let size = adSize()
        let banner = BannerView(adSize: size)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = Self.rootViewController()
        banner.load(Self.nonPersonalizedRequest())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // Re-size + reload only on a real width change (e.g. rotation),
        // not on sub-pixel layout jitter, to avoid reload loops.
        let size = adSize()
        if abs(banner.adSize.size.width - size.size.width) > 1 {
            banner.adSize = size
            banner.load(Self.nonPersonalizedRequest())
        }
    }

    private func adSize() -> AdSize {
        let safeWidth = width > 0 ? width : UIScreen.main.bounds.width
        return currentOrientationAnchoredAdaptiveBanner(width: safeWidth)
    }

    /// Non-personalized ad request — `npa=1` tells Google not to use the
    /// user's data for ad personalization, so we don't need ATT or a
    /// consent SDK.
    private static func nonPersonalizedRequest() -> Request {
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
        let onHeightChange: (CGFloat) -> Void

        init(onHeightChange: @escaping (CGFloat) -> Void) {
            self.onHeightChange = onHeightChange
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onHeightChange(bannerView.adSize.size.height)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("AdMob banner failed to load: \(error.localizedDescription)")
            onHeightChange(0)
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

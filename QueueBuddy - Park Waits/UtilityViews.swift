import SwiftUI

struct ScrollAwareModifier: ViewModifier {
    //@ObservedObject var viewModel: WaitTimeViewModel // Assuming viewModel is passed if needed

    @State private var lastContentOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo -> Color in
                    let offset = geo.frame(in: .global).minY
                    DispatchQueue.main.async {
                        if offset > lastContentOffset {
                            // Scrolling down
                            // FIXME: Handle isTabBarVisible logic elsewhere or add isTabBarVisible to WaitTimeViewModel if needed
                            // viewModel.isTabBarVisible = true
                        } else if offset < lastContentOffset {
                            // Scrolling up
                            // FIXME: Handle isTabBarVisible logic elsewhere or add isTabBarVisible to WaitTimeViewModel if needed
                            // viewModel.isTabBarVisible = false
                        }
                        lastContentOffset = offset
                    }
                    return Color.clear
                }
            )
    }
}

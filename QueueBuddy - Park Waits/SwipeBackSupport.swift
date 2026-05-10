import SwiftUI

#if canImport(UIKit)
import UIKit

private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        Controller()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        controller.enableSwipeBackWhenPossible()
    }

    private final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enableSwipeBackWhenPossible()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableSwipeBackWhenPossible()
        }
    }
}

private extension UIViewController {
    func enableSwipeBackWhenPossible() {
        guard let navigationController else { return }
        navigationController.interactivePopGestureRecognizer?.isEnabled = navigationController.viewControllers.count > 1
        navigationController.interactivePopGestureRecognizer?.delegate = nil
    }
}
#endif

extension View {
    func swipeBackEnabled() -> some View {
        #if canImport(UIKit)
        background(SwipeBackEnabler().frame(width: 0, height: 0))
        #else
        self
        #endif
    }
}

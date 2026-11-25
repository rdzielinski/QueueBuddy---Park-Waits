import SwiftUI

// Hinge awareness for foldables (iPhone Duo). iOS 27.1 reports the hinge's
// status; it doesn't report where the crease is, so that comes from the
// screen: the Duo's inner display folds across its long side (each half is
// roughly the cover screen), so the crease runs down the middle of the
// longer dimension. The app's window can be narrower than the screen (the
// system keeps a status column on one edge), so the crease is located in
// screen space and then converted into window coordinates.

/// Where the crease sits while the device is half open, in window
/// coordinates. Nil when flat, closed, or not a foldable.
struct FoldCrease: Equatable {
    enum Axis { case vertical, horizontal }

    /// `.vertical`: held like a book (inner display landscape), the crease
    /// splits left from right. `.horizontal`: held like a laptop (inner
    /// display portrait), upright top half over a flat bottom half.
    let axis: Axis
    /// Window-space x of a vertical crease, or y of a horizontal one.
    let position: CGFloat

    static func current(halfOpen: Bool, placement: ScreenPlacement?) -> FoldCrease? {
        guard halfOpen, let placement else { return nil }
        let screen = placement.screenSize
        let window = placement.windowFrame
        guard screen.width > 0, screen.height > 0 else { return nil }
        return screen.width > screen.height
            ? FoldCrease(axis: .vertical, position: screen.width / 2 - window.minX)
            : FoldCrease(axis: .horizontal, position: screen.height / 2 - window.minY)
    }
}

private struct FoldCreaseKey: EnvironmentKey {
    static let defaultValue: FoldCrease? = nil
}

extension EnvironmentValues {
    var foldCrease: FoldCrease? {
        get { self[FoldCreaseKey.self] }
        set { self[FoldCreaseKey.self] = newValue }
    }
}

/// Where the app's window sits on its screen, in the screen's
/// interface-oriented coordinates.
struct ScreenPlacement: Equatable {
    var windowFrame: CGRect
    var screenSize: CGSize
}

/// Reports the window's placement on screen whenever layout changes
/// (rotation, fold/unfold, moving between displays).
struct ScreenPlacementReader: UIViewRepresentable {
    var onChange: (ScreenPlacement) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onChange = onChange
    }

    final class ProbeView: UIView {
        var onChange: ((ScreenPlacement) -> Void)?
        private var last: ScreenPlacement?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard let window, let screen = window.windowScene?.screen else { return }
            let placement = ScreenPlacement(
                windowFrame: window.convert(window.bounds, to: screen.coordinateSpace),
                screenSize: screen.bounds.size
            )
            guard placement != last else { return }
            last = placement
            DispatchQueue.main.async { [weak self] in self?.onChange?(placement) }
        }
    }
}

/// Tracks whether the hinge is partially open. No-op before iOS 27.1 and on
/// devices without a hinge.
struct HingeReader: ViewModifier {
    @Binding var isHalfOpen: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, new in
                let halfOpen = new.hinge?.status == .partiallyOpen
                if halfOpen != isHalfOpen {
                    withAnimation(.easeInOut(duration: 0.3)) { isHalfOpen = halfOpen }
                }
            }
        } else {
            content
        }
    }
}

/// Parks list, gutter, detail. Columns (list left) when flat or held like a
/// book; rows (detail on the upright top half, list on the flat bottom
/// half) when held like a laptop. One Layout type for every mode, so the
/// list keeps its scroll position and search across posture changes.
/// With a single subview (single-column layout) it just fills the space.
struct ParksSplitLayout: Layout {
    enum Mode: Equatable {
        case columns(lead: CGFloat)
        case rows(top: CGFloat)
    }

    var mode: Mode
    var gutter: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else {
            for view in subviews {
                view.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            }
            return
        }
        let list = subviews[0], divider = subviews[1], detail = subviews[2]
        switch mode {
        case .columns(let lead):
            list.place(at: bounds.origin,
                       proposal: ProposedViewSize(width: lead, height: bounds.height))
            divider.place(at: CGPoint(x: bounds.minX + lead, y: bounds.minY),
                          proposal: ProposedViewSize(width: gutter, height: bounds.height))
            detail.place(at: CGPoint(x: bounds.minX + lead + gutter, y: bounds.minY),
                         proposal: ProposedViewSize(width: bounds.width - lead - gutter, height: bounds.height))
        case .rows(let top):
            detail.place(at: bounds.origin,
                         proposal: ProposedViewSize(width: bounds.width, height: top))
            divider.place(at: CGPoint(x: bounds.minX, y: bounds.minY + top),
                          proposal: ProposedViewSize(width: bounds.width, height: gutter))
            list.place(at: CGPoint(x: bounds.minX, y: bounds.minY + top + gutter),
                       proposal: ProposedViewSize(width: bounds.width, height: bounds.height - top - gutter))
        }
    }
}

/// The seam between panes: a hairline, inside a wider gutter centred on
/// the crease when half open so no text lands in the fold.
struct ParksSeam: View {
    let axis: FoldCrease.Axis

    var body: some View {
        ZStack {
            DB.bg
            if axis == .vertical {
                Rectangle().fill(DB.line).frame(width: 1)
            } else {
                Rectangle().fill(DB.line).frame(height: 1)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

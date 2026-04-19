import SwiftUI

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .foregroundColor(.primary)
            .padding(.vertical, 20)
            .padding(.horizontal, 30)
            .background(
                // A semi-transparent material background is highly readable
                .regularMaterial
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // The system automatically handles scale and shadow on tvOS
            // when a view is focusable.
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle {
        CardButtonStyle()
    }
}

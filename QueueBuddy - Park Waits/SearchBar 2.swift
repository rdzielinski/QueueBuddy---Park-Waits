import SwiftUI

/// Terminal-style search input matching the Departure-Board aesthetic.
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "search attractions…"

    var body: some View {
        HStack(spacing: 10) {
            Text(">")
                .font(DB.mono(14, weight: .bold))
                .foregroundStyle(DB.amber)
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundStyle(DB.muted)
                    .font(DB.mono(14))
            )
            .font(DB.mono(14))
            .foregroundStyle(DB.text)
            .tint(DB.amber)
            .autocorrectionDisabled(true)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DB.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

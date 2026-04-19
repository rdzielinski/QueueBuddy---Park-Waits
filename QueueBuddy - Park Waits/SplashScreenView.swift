import SwiftUI
import UIKit

struct SplashScreenView: View {
    @Binding var isActive: Bool
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var flapValue: Int = 0

    var body: some View {
        ZStack {
            DB.bg.ignoresSafeArea()

            RadialGradient(
                colors: [DB.amber.opacity(0.14), .clear],
                center: .center,
                startRadius: 10, endRadius: 360
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack(spacing: 10) {
                    RouteStripe(color: DB.amber, width: 30)
                    Text("BOARDING")
                        .font(DB.mono(11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(DB.amber)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("QueueBuddy")
                        .font(DB.displayTitle(40))
                        .foregroundStyle(DB.text)
                        .tracking(-1)
                    Text(".")
                        .font(DB.displayTitle(40))
                        .foregroundStyle(DB.amber)
                }
                .opacity(titleOpacity)

                FlapDigits(value: flapValue, size: 54, tone: DB.amber, label: "WAIT")
                    .opacity(titleOpacity)

                Text("Orlando theme parks · live waits")
                    .font(DB.mono(11))
                    .tracking(1.8)
                    .foregroundStyle(DB.muted)
                    .opacity(subtitleOpacity)
            }
        }
        .onAppear {
            Task {
                withAnimation(.easeIn(duration: 0.6)) { titleOpacity = 1 }
                // Ticker animation: flip through a few values to settle on 00
                for value in stride(from: 75, through: 0, by: -15) {
                    try? await Task.sleep(nanoseconds: 90_000_000)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        flapValue = value
                    }
                }
                withAnimation(.easeIn(duration: 0.5)) { subtitleOpacity = 1 }

                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif

                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.easeOut(duration: 0.5)) {
                    isActive = false
                }
            }
        }
    }
}

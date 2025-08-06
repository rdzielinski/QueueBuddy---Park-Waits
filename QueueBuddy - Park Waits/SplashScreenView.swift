// SplashScreenView.swift

import SwiftUI
import UIKit

struct SplashScreenView: View {
    @Binding var isActive: Bool // This binding communicates back to the RootView.
    @State private var textOpacity: Double = 0
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
                .ignoresSafeArea(.all, edges: .all)
            GeometryReader { geometry in
                ZStack {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .opacity(logoOpacity)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            VStack(spacing: 20) {
                Text("QueueBuddy - Park Waits")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .opacity(textOpacity)
            }
            .offset(y: UIScreen.main.bounds.height / 18)
        }
        .onAppear {
            Task {
                // Animate the logo fading in.
                withAnimation(.easeIn(duration: 1.0)) {
                    logoOpacity = 1
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1s for image fade in
                
                // Animate the text fading in.
                withAnimation(.easeIn(duration: 1.0)) {
                    textOpacity = 1
                }
                
                try? await Task.sleep(nanoseconds: 1_050_000_000) // Wait 1.05s for text animation + small delay
                
                // Trigger light haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s display time
                
                // Animate the transition to the main app.
                withAnimation(.easeOut(duration: 0.5)) {
                    // This tells the RootView to switch to the main app content.
                    isActive = false
                }
            }
        }
    }
}

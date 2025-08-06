import SwiftUI

// A simple, reusable function to trigger light haptic feedback.
func triggerHapticFeedback() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
}

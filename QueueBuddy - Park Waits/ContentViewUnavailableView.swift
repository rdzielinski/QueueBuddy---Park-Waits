// ContentViewUnavailableView.swift
import SwiftUI

struct ContentViewUnavailableView: View {
    let message: String
    let systemImage: String?
    
    var body: some View {
        VStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

import SwiftUI

struct WeatherView: View {
    let forecast: WeatherForecast

    private var backgroundGradient: LinearGradient {
        let desc = forecast.description.lowercased()
        if desc.contains("sun") || desc.contains("clear") {
            return LinearGradient(
                gradient: Gradient(colors: [Color.yellow.opacity(0.7), Color.orange.opacity(0.5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if desc.contains("cloud") {
            return LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.5), Color.gray.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if desc.contains("rain") || desc.contains("drizzle") {
            return LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.gray.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if desc.contains("storm") || desc.contains("thunder") {
            return LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.gray.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if desc.contains("snow") {
            return LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.8), Color.blue.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color.accentColor.opacity(0.3), Color.gray.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Weather")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(forecast.description.capitalized)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Spacer()
            HStack(spacing: 8) {
                if let iconURL = forecast.iconURL {
                    AsyncImage(url: iconURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 44, height: 44)
                    .shadow(radius: 4)
                }
                Text("\(Int(forecast.temperature))°F")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
        .padding()
        .background(
            backgroundGradient
                .opacity(0.95)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

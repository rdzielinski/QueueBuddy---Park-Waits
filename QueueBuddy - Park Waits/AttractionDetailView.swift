import SwiftUI
import UIKit

/// A simple light haptic tap you can call anywhere.
private func triggerLightHaptic() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
}

// This enum defines the two possible sheets that can be presented from this view.
// It conforms to Identifiable so it can be used with the .sheet(item:) modifier.
private enum ActiveSheet: Identifiable {
    case notification, manualEntry
    var id: Int {
        switch self {
        case .notification: return 0
        case .manualEntry: return 1
        }
    }
}

/// Detailed screen for one attraction.
struct AttractionDetailView: View {
    @EnvironmentObject private var viewModel: WaitTimeViewModel
    let attraction: Attraction
    @State private var activeSheet: ActiveSheet? = nil

    var body: some View {
        let vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: — Header —
                HStack(alignment: .top, spacing: 15) {
                    Image(systemName: attraction.type ?? "questionmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(attraction.name)
                            .font(.largeTitle.bold())
                        
                        HStack(spacing: 15) {
                            Text(attraction.waitTimeDisplay)
                                .font(.title2.weight(.bold))
                            Spacer()
                            // Favorite toggle
                            Button {
                                vm.toggleFavorite(attractionId: attraction.id)
                                triggerLightHaptic()
                            } label: {
                                Image(systemName: vm.isFavorited(attractionId: attraction.id) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            
                            // Notification bell
                            Button {
                                if vm.isNotificationSet(for: attraction.id) {
                                    vm.removeNotification(for: attraction.id)
                                } else {
                                    activeSheet = .notification
                                }
                                triggerLightHaptic()
                            } label: {
                                Image(systemName: vm.isNotificationSet(for: attraction.id) ? "bell.fill" : "bell")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundColor(
                            WaitTimeViewModel.statusColor(
                                status: attraction.status,
                                waitTime: attraction.wait_time,
                                isOpen: attraction.is_open
                            )
                        )
                    }
                }
                .padding(.horizontal)
                
                Divider()

                // MARK: — About —
                if let desc = attraction.description, !desc.isEmpty, desc != "No additional details available." {
                    InfoSection(title: "About", content: desc)
                }

                // MARK: — Requirements —
                if let minH = attraction.min_height_inches, minH > 0 {
                    let cm = String(format: "%.0f", Double(minH) * 2.54)
                    InfoSection(
                        title: "Requirements",
                        content: "Minimum Height: \(minH)\" (\(cm) cm)",
                        symbol: "ruler.fill"
                    )
                }
                
                Divider()

                // MARK: — Manual Wait Entry —
                Button("Manually Add Wait Time") {
                    activeSheet = .manualEntry
                    triggerLightHaptic()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(attraction.name)
        .navigationBarTitleDisplayMode(.inline)
        // This modifier presents a sheet based on the value of 'activeSheet'.
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .notification:
                // FIXED: The call to NotificationSettingView is now simpler and correct.
                // It no longer needs the 'isPresented' binding.
                NotificationSettingView(attraction: attraction)
                    .environmentObject(vm)
            case .manualEntry:
                ManualWaitTimeEntryView(attraction: attraction)
                    .environmentObject(vm)
            }
        }
    }
}

/// A small “info” box with an optional SF symbol.
private struct InfoSection: View {
    let title: String
    let content: String
    var symbol: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline)
            HStack {
                if let sym = symbol {
                    Image(systemName: sym)
                }
                Text(content)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

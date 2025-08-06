import SwiftUI
import MapKit
import CoreLocation

private struct EquatableCoordinate: Equatable {
    let coord: CLLocationCoordinate2D?
    static func ==(lhs: EquatableCoordinate, rhs: EquatableCoordinate) -> Bool {
        switch (lhs.coord, rhs.coord) {
        case (nil, nil): return true
        case (let l?, let r?):
            return l.latitude == r.latitude && l.longitude == r.longitude
        default: return false
        }
    }
}

struct MyDayMapView: View {
    @Binding var centerOnCoordinate: CLLocationCoordinate2D?
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var sessionManager = MyDaySessionManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.4189, longitude: -81.5812),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isTracking = false
    @State private var isReplaying = false
    @State private var replayIndex: Int = 0
    @State private var replayTimer: Timer?
    @State private var animateFeet: Bool = false
    @State private var showSaveSheet = false
    @State private var customSessionName = ""
    @State private var steps: Int = 0
    @State private var distance: Double = 0
    @State private var showHistorySheet = false
    @State private var selectedSession: MyDaySession?
    @State private var hasCenteredOnUser = false

    private var equatableCenterOnCoordinate: EquatableCoordinate {
        EquatableCoordinate(coord: centerOnCoordinate)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    GeometryReader { geo in
                        MapView(
                            attractions: allAttractions,
                            trackedLocations: isReplaying ? Array(matchedLocations.prefix(replayIndex + 1)) : matchedLocations,
                            region: $region,
                            replayMarker: isReplaying && replayIndex < matchedLocations.count ? matchedLocations[replayIndex].coordinate : nil,
                            showFeet: true,
                            feetTrail: isReplaying ? Array(matchedLocations.prefix(replayIndex + 1)) : matchedLocations,
                            animateFeet: animateFeet
                        )
                        .frame(height: geo.size.height)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color(.systemBackground).opacity(0.7),
                                    Color(.systemBackground)
                                ]),
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                            .ignoresSafeArea(edges: .bottom)
                            .allowsHitTesting(false),
                            alignment: .bottom
                        )
                        .onAppear {
                            centerOnUserIfNeeded()
                        }
                        .onChange(of: locationManager.locations.count) { _ in
                            centerOnUserIfNeeded()
                        }
                        .onChange(of: equatableCenterOnCoordinate) { newValue in
                            if let coord = newValue.coord {
                                region.center = coord
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)

                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                if let lastLocation = locationManager.locations.last {
                                    region.center = lastLocation.coordinate
                                    triggerHapticFeedback()
                                }
                            }) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Circle().fill(Color.accentColor))
                                    .shadow(radius: 3)
                            }
                            .accessibilityLabel("Show My Location")
                            .padding(.top, 16)
                            .padding(.trailing, 22)
                        }
                        Spacer()
                    }

                    if isReplaying, replayIndex < matchedLocations.count {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Time: \(formattedTime(matchedLocations[replayIndex].timestamp))")
                                    .font(.caption)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(10)
                                    .padding()
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            VStack(spacing: 0) {
                // Custom bottom bar for action buttons
                HStack(spacing: 12) {
                    Button("Save My Day") {
                        showSaveSheet = true
                        triggerHapticFeedback()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .sheet(isPresented: $showSaveSheet) {
                        NavigationStack {
                            Form {
                                Section("Name Your Day") {
                                    TextField("e.g. Magic Kingdom July 2025", text: $customSessionName)
                                }
                                Section {
                                    Button("Save") {
                                        sessionManager.saveSession(locations: matchedLocations, name: customSessionName.isEmpty ? formattedTime(Date()) : customSessionName)
                                        showSaveSheet = false
                                        customSessionName = ""
                                    }
                                    .disabled(matchedLocations.isEmpty)
                                }
                            }
                            .navigationTitle("Save My Day")
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") { showSaveSheet = false }
                                }
                            }
                        }
                    }

                    Button("My Day History") {
                        showHistorySheet = true
                        triggerHapticFeedback()
                    }
                    .buttonStyle(.bordered)
                    .sheet(isPresented: $showHistorySheet) {
                        MyDaySessionsListView(sessionManager: sessionManager, allAttractions: allAttractions, selectedSession: $selectedSession)
                    }

                    Button(isTracking ? "Stop Tracking" : "Start Tracking") {
                        if isTracking {
                            locationManager.stopTracking()
                        } else {
                            locationManager.startTracking()
                        }
                        isTracking.toggle()
                        triggerHapticFeedback()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isTracking ? .red : .blue)

                    Button(isReplaying ? "Stop Replay" : "Replay My Day") {
                        if isReplaying {
                            stopReplay()
                        } else {
                            startReplay()
                        }
                        triggerHapticFeedback()
                    }
                    .buttonStyle(.bordered)
                    .disabled(matchedLocations.count < 2)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    BlurView(style: .systemMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: -2)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

                // HealthKit stats
                if !matchedLocations.isEmpty {
                    VStack(spacing: 4) {
                        Text("Steps: \(steps)")
                        Text(String(format: "Distance: %.2f miles", distance / 1609.34))
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                    .onAppear {
                        healthKitManager.requestAuthorization()
                        if let first = matchedLocations.first?.timestamp, let last = matchedLocations.last?.timestamp {
                            healthKitManager.fetchStepsAndDistance(start: first, end: last) { s, d in
                                steps = s
                                distance = d
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Day Map")
        .onDisappear {
            stopReplay()
        }
    }

    private var allAttractions: [Attraction] {
        viewModel.attractionsByPark.values.flatMap { $0 }
    }

    private var matchedLocations: [TrackedLocation] {
        locationManager.locations.map { $0.matchedToAttraction(allAttractions) }
    }

    private func startReplay() {
        guard matchedLocations.count > 1 else { return }
        isReplaying = true
        replayIndex = 0
        animateFeet = false
        replayTimer?.invalidate()
        replayTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
            if replayIndex < matchedLocations.count - 1 {
                replayIndex += 1
                animateFeet.toggle()
                triggerFootstepHaptic()
            } else {
                stopReplay()
            }
        }
    }

    private func stopReplay() {
        isReplaying = false
        replayTimer?.invalidate()
        replayTimer = nil
        animateFeet = false
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func centerOnUserIfNeeded() {
        guard !hasCenteredOnUser, let userLoc = locationManager.locations.last else { return }
        region.center = userLoc.coordinate
        hasCenteredOnUser = true
    }
}

// --- BlurView Helper ---

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// --- Haptic Helper for Footsteps ---

func triggerFootstepHaptic() {
    let generator = UIImpactFeedbackGenerator(style: .soft)
    generator.impactOccurred()
}

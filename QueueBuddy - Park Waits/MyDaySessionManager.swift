// MyDaySessionManager.swift

import Foundation

class MyDaySessionManager: ObservableObject {
    @Published var sessions: [MyDaySession] = []

    private let storageKey = "myDaySessions"

    init() {
        loadSessions()
    }

    func saveSession(locations: [TrackedLocation], name: String) {
        let session = MyDaySession(id: UUID(), date: Date(), name: name, locations: locations)
        sessions.append(session)
        persist()
    }

    func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MyDaySession].self, from: data) {
            sessions = decoded
        }
    }
}

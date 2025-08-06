// MyDaySession.swift

import Foundation

struct MyDaySession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let name: String
    let locations: [TrackedLocation]
}

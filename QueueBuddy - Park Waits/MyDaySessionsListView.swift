import SwiftUI

struct MyDaySessionsListView: View {
    @ObservedObject var sessionManager: MyDaySessionManager
    let allAttractions: [Attraction]
    @Binding var selectedSession: MyDaySession?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(sessionManager.sessions) { session in
                Button(action: {
                    selectedSession = session
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(session.name.isEmpty ? "Unnamed Day" : session.name)
                            .font(.headline)
                        Text(session.date, style: .date)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("My Day History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

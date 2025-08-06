import SwiftUI

struct EventListView: View {
    let park: Park
    @EnvironmentObject var viewModel: WaitTimeViewModel
    
    private var displayEvents: [Event] {
        // This call is now valid.
        viewModel.eventsByPark[park.id]?
            .filter { $0.nextUpcomingTime != nil }
            .sorted { $0.nextUpcomingTime! < $1.nextUpcomingTime! } ?? []
    }
    
    var body: some View {
        // The compiler can now understand this view because 'displayEvents' is valid.
        if displayEvents.isEmpty {
            ContentUnavailableView("No Upcoming Events", systemImage: "calendar.badge.exclamationmark")
        } else {
            Section(header: Text("Upcoming Events")) {
                ForEach(displayEvents) { event in
                    NavigationLink(value: event) {
                        EventRowView(event: event)
                    }
                }
            }
        }
    }
}

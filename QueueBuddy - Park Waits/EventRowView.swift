// EventRowView.swift

import SwiftUI

struct EventRowView: View {
    let event: Event
    
    var body: some View {
        HStack {
            Image(systemName: event.type.symbol)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 35)
            
            VStack(alignment: .leading) {
                Text(event.name).font(.headline)
                Text(event.location).font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let nextTime = event.nextUpcomingTime {
                Text(nextTime, style: .time)
                    .font(.headline)
            }
        }
    }
}

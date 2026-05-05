import WidgetKit
import SwiftUI

@main
struct QueueBuddyWidgetBundle: WidgetBundle {
    var body: some Widget {
        FavoritesWaitWidget()
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            ParkDayLiveActivity()
        }
        if #available(iOS 16.2, *) {
            InLineLiveActivity()
        }
        #endif
    }
}

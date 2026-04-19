import Foundation
import UserNotifications
import SwiftUI

// This class is responsible for handling how notifications are managed and displayed
// by the system when your app is running.
class NotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

#if !os(tvOS)
    // This function is called when a notification arrives while the app is in the foreground.
    // By default, notifications don't show up if the app is open. This code tells
    // the system to go ahead and show it as a banner and play a sound.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  willPresent notification: UNNotification,
                                  withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Show the notification as a banner, in the notification list, and play a sound.
        completionHandler([.banner, .sound, .list])
    }

    // This function is called when the user taps on the notification banner itself.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  didReceive response: UNNotificationResponse,
                                  withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // In the future, you could add logic here. For example, you could read
        // data from the notification to navigate the user directly to the
        // specific attraction that the alert was for.
        
        completionHandler()
    }
#endif
}

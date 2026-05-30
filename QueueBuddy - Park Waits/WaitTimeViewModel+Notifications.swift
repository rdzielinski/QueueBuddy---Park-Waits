import Foundation
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

extension WaitTimeViewModel {

    // MARK: - Notification Logic

    /// Per-attraction notification firing. Each registered alert can
    /// trigger up to four distinct kinds of push, all edge-triggered
    /// via `NotificationDedupStore` so no kind ever re-fires on the
    /// same condition:
    ///
    ///   * `wait`  — wait dropped at-or-below the user's threshold
    ///   * `down`  — ride went DOWN/REFURBISHMENT (operational problem)
    ///   * `back`  — ride returned to OPERATING after being down
    ///   * `ll`    — Lightning Lane / virtual queue became AVAILABLE again
    func checkAndSendAttractionNotifications() async {
        for preference in notificationPreferences {
            guard let attraction = attractionsByPark.values
                .flatMap({ $0 })
                .first(where: { $0.id == preference.id }) else { continue }

            await fireWaitThresholdAlert(for: attraction, preference: preference)
            await fireStatusAlert(for: attraction)
            await fireLightningLaneAlert(for: attraction)
        }
    }

    private func fireWaitThresholdAlert(for attraction: Attraction, preference: NotificationPreference) async {
        guard let wait = attraction.wait_time, attraction.is_open == true else {
            NotificationDedupStore.resetState(attractionId: preference.id)
            return
        }
        guard NotificationDedupStore.shouldFire(
            attractionId: preference.id,
            currentWait: wait,
            threshold: preference.thresholdMinutes
        ) else { return }
        await postNotification(
            title: "QueueBuddy Alert",
            body: "\(attraction.name) is now at \(wait) min wait or less!",
            identifier: "wait-\(attraction.id)"
        )
    }

    private func fireStatusAlert(for attraction: Attraction) async {
        let status = (attraction.status ?? "").uppercased()
        let isDown = status == "DOWN" || status == "REFURBISHMENT"
        let isOperating = status == "OPERATING"

        let downKey = "down-\(attraction.id)"
        let backKey = "back-\(attraction.id)"
        let isFirstSampleDown = !NotificationDedupStore.hasStateRecorded(forKey: downKey)
        let isFirstSampleBack = !NotificationDedupStore.hasStateRecorded(forKey: backKey)

        if NotificationDedupStore.shouldFire(key: downKey, isActive: isDown) {
            let detail = status == "REFURBISHMENT" ? "is under refurbishment" : "just went down"
            await postNotification(
                title: "Ride status",
                body: "\(attraction.name) \(detail).",
                identifier: downKey
            )
        }

        if !isFirstSampleBack,
           NotificationDedupStore.shouldFire(key: backKey, isActive: isOperating) {
            await postNotification(
                title: "Ride status",
                body: "\(attraction.name) is back open.",
                identifier: backKey
            )
        } else if isFirstSampleBack {
            _ = NotificationDedupStore.shouldFire(key: backKey, isActive: isOperating)
        }
        _ = isFirstSampleDown
    }

    private func fireLightningLaneAlert(for attraction: Attraction) async {
        let available = attraction.returnTime?.state == .available
        let key = "ll-\(attraction.id)"
        let isFirstSample = !NotificationDedupStore.hasStateRecorded(forKey: key)
        let edge = NotificationDedupStore.shouldFire(key: key, isActive: available)
        guard !isFirstSample, edge else { return }
        let when: String = {
            guard let start = attraction.returnTime?.returnStart else { return "is available now" }
            let f = UserPreferences.timeFormatter()
            return "is available · return at \(f.string(from: start))"
        }()
        await postNotification(
            title: "Lightning Lane",
            body: "\(attraction.name) \(when).",
            identifier: key
        )
    }

    func postNotification(title: String, body: String, identifier: String) async {
        #if !os(tvOS)
        // Respect master toggle + quiet hours. We still log to the
        // in-app alerts list (caller writes there separately); we just
        // suppress the OS-level banner / sound.
        guard UserPreferences.shouldDeliverNotification() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            dprint("Failed to post notification \(identifier): \(error)")
        }
        #endif
    }

    // MARK: - Live Activity sync

    /// Push the latest cached wait into any running in-line Live Activity.
    func refreshActiveLiveActivity() {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            guard let activity = Activity<InLineAttributes>.activities.first else { return }
            let id = activity.attributes.attractionId
            let attraction = attractionsByPark.values
                .flatMap({ $0 })
                .first(where: { $0.id == id })
            InLineActivityController.update(
                attractionId: id,
                currentWait: attraction?.wait_time
            )
        }
        #endif
    }
}

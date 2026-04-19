# QueueBuddy — Widget, Live Activity & Apple Watch setup

All source files are already in place under `QueueBuddyWidget/` and
`QueueBuddyWatch/`. You only need to add them as targets in Xcode. Total
time: ~5 minutes.

## 1. Widget + Live Activity extension

1. Open `QueueBuddy - Park Waits.xcodeproj` in Xcode.
2. **File → New → Target → Widget Extension**.
   - Product Name: **QueueBuddyWidget**
   - Include Live Activity: **✓ yes**
   - Configuration Intent: **no** (we use App Intents in the main app)
3. When Xcode offers to activate the scheme, click **Activate**.
4. In the Project Navigator, **delete the default widget files** that the
   template created (keep nothing inside the new `QueueBuddyWidget` group).
5. **Right-click the `QueueBuddyWidget` group → Add Files to "QueueBuddy - Park Waits"**.
   Select the existing `QueueBuddyWidget/` folder on disk:
   - `QueueBuddyWidgetBundle.swift`
   - `SharedWaitModels.swift`
   - `FavoritesWaitWidget.swift`
   - `ParkDayLiveActivity.swift`
   - Also include the provided `Info.plist` (replace the template one)
   - And the provided `QueueBuddyWidget.entitlements`
   Ensure **Target Membership** is set to `QueueBuddyWidget` only (not the main app).
6. Select the `QueueBuddyWidget` target → **Signing & Capabilities**:
   - Click **+ Capability → App Groups**, add `group.Dzielinski.QueueBuddy`
     (same group already configured on the main app).
   - Point `CODE_SIGN_ENTITLEMENTS` at `QueueBuddyWidget/QueueBuddyWidget.entitlements`.
7. Build and run on iPhone Simulator. Add the widget to the home screen.

## 2. Apple Watch app

QueueBuddy's Watch app is **standalone** (no iPhone pairing required) — it
reads the shared cache via the App Group.

1. **File → New → Target → Watch App** (not "Watch App for iOS App").
2. Product Name: **QueueBuddyWatch**. Interface: SwiftUI. Lifecycle: App.
3. When prompted, set the bundle identifier to
   `Dzielinski.QueueBuddy---Park-Waits.watchkitapp` (or similar).
4. Delete the template files inside the new watch group.
5. Add the existing `QueueBuddyWatch/` folder to the project, with Target
   Membership set to the new Watch target:
   - `QueueBuddyWatchApp.swift`
   - `WatchSharedCache.swift`
   - `WatchHomeView.swift`
   - `Info.plist`
   - `QueueBuddyWatch.entitlements`
6. In Signing & Capabilities, add the **App Groups** capability and enable
   `group.Dzielinski.QueueBuddy`.

### Keeping the watch cache in sync

Because the Watch app is standalone, it reads whatever the iPhone app last
wrote to the App Group. If you want live updates even when the user doesn't
open the iPhone app, add a `WatchConnectivity` push from
`WaitTimeViewModel.updateSharedCache()` to the watch.

For now, the Watch will display whatever the iPhone last synced.

## 3. (Optional) Starting a Live Activity

The main app can launch the "Park Day" Live Activity when the user opens a
park detail screen by calling:

```swift
import ActivityKit

let attrs = ParkDayAttributes(sessionName: "Park Day")
let state = ParkDayAttributes.ContentState(
    parkId: park.id,
    parkName: park.name,
    parkAccentHex: DB.accentHexValue(for: park.id),
    primaryName: topFavorite.name,
    primaryWait: topFavorite.wait_time,
    primaryIsOpen: topFavorite.is_open ?? true,
    secondaryLines: [...],
    updatedAt: Date()
)
let activity = try Activity<ParkDayAttributes>.request(
    attributes: attrs,
    content: .init(state: state, staleDate: nil),
    pushType: nil
)
```

The Live Activity attribute type (`ParkDayAttributes`) is shared between the
main app and the widget extension — copy the struct definition from
`QueueBuddyWidget/ParkDayLiveActivity.swift` into the main target if you
want to import it there, or mark that file as a member of both targets.

## 4. Siri / Shortcuts

Already wired. `QueueBuddyIntents.swift` in the main app exposes:

- "Hey Siri, what's the wait for Space Mountain in QueueBuddy?"
- "Shortest waits at Epic Universe in QueueBuddy"

The intents read the shared cache so they work instantly without a network
fetch.

## Known gotchas

- **App Group ID**: all targets must use exactly `group.Dzielinski.QueueBuddy`.
- **Shared cache is populated by the main app** — the user must open
  QueueBuddy at least once after install for the widget/watch to have data.
  `WaitTimeViewModel.updateSharedCache()` runs automatically after every
  refresh.
- **Icon**: regenerated via `make_icon.py` in `/tmp/qb-design/`. Live in
  `Assets.xcassets/AppIcon.appiconset/`.

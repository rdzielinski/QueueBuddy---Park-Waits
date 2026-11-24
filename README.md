# QueueBuddy: Park Waits

Live wait times for the Orlando theme parks on iPhone and Apple Watch, for park-goers who want to know when a line drops without refreshing an app all day.

## What it does

- Live standby waits for all seven Orlando parks, with single-rider lines flagged
- Favorites and alerts when a wait drops below your threshold
- Wait-history sparklines so you can see if a line is climbing or falling
- Home Screen and Lock Screen widgets, Live Activities on the Lock Screen and Dynamic Island, and an Apple Watch app
- Siri and Shortcuts: "check a wait" and "shortest waits"
- Optional AI park-day helper (Apple Intelligence on device, or bring your own Claude, OpenAI or Gemini key)

## Tech

- iOS: Swift, SwiftUI, ActivityKit, WidgetKit, App Intents, MapKit, CoreLocation, UserNotifications, BackgroundTasks, FoundationModels
- watchOS companion app sharing data through an App Group
- Backend: Cloudflare Worker in TypeScript with cron jobs that push Live Activity updates over APNs every minute (JWT signed with Web Crypto), KV for push tokens, and D1 for long-term wait history
- Web: a React + Vite "departure board" version on Cloudflare Pages
- Monetization: Google Mobile Ads
- Wait data from [ThemeParks.wiki](https://themeparks.wiki)

<!-- If QueueBuddy is live, add: [Download on the App Store](https://apps.apple.com/...) -->

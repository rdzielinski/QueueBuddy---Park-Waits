# QueueBuddy Push Worker

Cloudflare Worker that updates QueueBuddy's in-line Live Activities via
APNs every minute. Free-tier friendly: one cron tick per minute, a single
KV namespace, and no external dependencies (APNs JWTs are signed via
Web Crypto).

## Setup (one-time)

### 1. Apple Developer Portal

Generate an APNs Authentication Key (.p8 file):

1. <https://developer.apple.com/account/resources/authkeys/list>
2. **Create a Key** → check **Apple Push Notifications service (APNs)** → Continue
3. Download the `.p8` file (you can only download it once — keep it safe)
4. Note the **Key ID** (10 chars, shown on the key's detail page)
5. Note your **Team ID** (top-right of the developer portal)
6. Note the app's **Bundle ID** (matches `PRODUCT_BUNDLE_IDENTIFIER`
   in Xcode — for this app, `Dzielinski.QueueBuddy---Park-Waits`)

### 2. Install Wrangler and log in

```bash
cd cloudflare
npm install
npx wrangler login
```

### 3. Push secrets to the Worker

```bash
# .p8 contents — paste the entire file including the BEGIN/END lines
npx wrangler secret put APNS_KEY

# Short identifiers — just the literal strings from above
npx wrangler secret put APNS_KEY_ID
npx wrangler secret put APNS_TEAM_ID
npx wrangler secret put APNS_BUNDLE_ID
```

### 4. Deploy

```bash
npx wrangler deploy
```

Wrangler prints the deployed URL, something like
`https://queuebuddy-push.<subdomain>.workers.dev`. Copy that.

### 5. Tell the iOS app where the Worker lives

In `QueueBuddy - Park Waits/LiveActivityBackend.swift`, set
`LiveActivityBackend.baseURL` to the URL Wrangler printed.

### 6. (Dev only) Use the APNs sandbox

If you're building from Xcode to a device, push tokens are *sandbox*
tokens — Apple's production APNs server (`api.push.apple.com`) will
reject them. Override the host for dev:

```bash
npx wrangler deploy --var APNS_HOST:api.sandbox.push.apple.com
```

Or temporarily edit `wrangler.toml` and switch back before shipping.

## How it works

```
iOS app                Worker (cron, every 1m)             APNs
─────────              ────────────────────────             ─────
Live Activity          1. List active tokens in KV          Update push delivered;
starts with     ───►   2. Group by parkUUID                 ActivityKit refreshes
pushType: .token       3. Fetch waits from                  the lock-screen pin
Captures token         api.themeparks.wiki                  (no app code runs)
Sends to /register     4. Diff vs last sample
                       5. POST to APNs
                       6. Drop tokens on 410 Gone
Live Activity end ───► /unregister
```

## KV layout

| Key                          | Value                                   | Notes |
|------------------------------|-----------------------------------------|-------|
| `activity:<pushToken>`       | `RegisteredActivity` JSON              | One per active Live Activity |
| `lastwait:<attractionId>`    | `LastWaitSample` JSON                  | 24h TTL, used for push dedup |

## Cron cadence

`* * * * *` — every minute. Apple recommends ≤1 Live Activity push per
minute, so this is the floor; tighter wouldn't help. Pushes within a tick
are skipped when neither `wait` nor `status` changed since the previous
sample (heartbeat every 10 min to stop the activity going stale).

## Troubleshooting

- **APNs returns 403 `InvalidProviderToken`** — your `.p8` doesn't match
  the configured `APNS_KEY_ID` + `APNS_TEAM_ID`. Re-check the IDs.
- **APNs returns 400 `BadTopic`** — `APNS_BUNDLE_ID` is wrong, or the
  worker is appending the wrong topic suffix (must be
  `<bundle>.push-type.liveactivity`).
- **APNs returns 410 `Unregistered`** — token retired by Apple. The
  worker handles this and deletes the entry.
- **Cron isn't firing** — check `npx wrangler tail` to see live logs.
  Cron triggers don't fire when there are deploy-time errors.
- **Nothing pushes** — make sure the iOS app called `/register`. Hit
  `https://<your-worker>/health` to confirm the Worker is reachable.

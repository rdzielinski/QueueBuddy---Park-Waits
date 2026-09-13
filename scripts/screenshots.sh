#!/bin/bash
# Capture App Store screenshots from the iOS Simulator, headlessly.
#
#   scripts/screenshots.sh              -> screenshots/<device>/NN-name.png
#   scripts/screenshots.sh out/dir      -> custom output root
#   DEVICES="iphone-6.9" scripts/screenshots.sh   -> just one size
#   SKIP_BUILD=1 scripts/screenshots.sh           -> reuse the last build
#
# Builds the app + QueueBuddyUITests once, then for each App Store device
# size: creates (or reuses) a simulator, boots it, sets the simulated
# location to Magic Kingdom, grants location, cleans the status bar, and runs
# ScreenshotTests with SCREENSHOT_DIR pointed at the output folder.
#
# Requires the Xcode 27 beta toolchain on this Mac (the release Xcode cannot
# talk to simulators on macOS 27). Override DEVELOPER_DIR to use another.
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT_ROOT="${1:-screenshots}"
PROJECT="QueueBuddy - Park Waits.xcodeproj"
SCHEME="QueueBuddy - Park Waits"
BUNDLE_ID="Dzielinski.QueueBuddy---Park-Waits"
DERIVED="build/DerivedData"
LOCATION="28.4177,-81.5812"   # Magic Kingdom hub

# slug|simctl device type|display name
ALL_DEVICES=(
  "iphone-6.9|com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max|iPhone 17 Pro Max"
  "ipad-13|com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-8GB|iPad Pro 13-inch (M4)"
)
WANT="${DEVICES:-}"

RUNTIME=$(xcrun simctl list runtimes | grep "^iOS" | tail -1 | sed -E 's/.*(com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+).*/\1/')
[ -n "$RUNTIME" ] || { echo "No iOS simulator runtime found"; exit 1; }
echo "▶ runtime: $RUNTIME"

# Compiling with a simulator booted has run this 16 GB Mac out of memory,
# so park every screenshot simulator before the build and boot one at a time.
{ xcrun simctl list devices | grep "QB Shots — " | grep Booted || true; } \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' \
  | while read -r u; do xcrun simctl shutdown "$u" >/dev/null 2>&1 || true; done

if [ "${SKIP_BUILD:-0}" = "1" ]; then
  echo "▶ SKIP_BUILD=1, reusing the last build-for-testing products"
else
  echo "▶ build-for-testing (simulator)"
  set +e
  xcodebuild build-for-testing \
    -project "$PROJECT" -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$DERIVED" \
    -only-testing:QueueBuddyUITests \
    CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | grep -E "error:|BUILD"
  BUILD_RC=${PIPESTATUS[0]}
  set -e
  [ "$BUILD_RC" -eq 0 ] || { echo "build-for-testing failed (exit $BUILD_RC)"; exit 1; }
fi

XCTESTRUN=$(ls -t "$DERIVED"/Build/Products/*.xctestrun | head -1)
APP=$(ls -d "$DERIVED"/Build/Products/Debug-iphonesimulator/*.app | grep -v xctest | head -1)
echo "▶ xctestrun: $XCTESTRUN"

# macOS has no `timeout`; perl's alarm kills the exec'd command instead.
with_timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }

# For 10-15 minutes after a cold boot, screenshot requests (simctl and
# XCTest alike) hang, and XCTest gives up with "Timed out while requesting
# screenshot". Poll a throwaway screenshot until it answers within 10 s.
warm_up() {
  local udid=$1
  local tmp="/tmp/qb-warmup-$udid.png"
  local deadline=$((SECONDS + 1500))
  local t0
  while [ "$SECONDS" -lt "$deadline" ]; do
    t0=$SECONDS
    if with_timeout 25 xcrun simctl io "$udid" screenshot "$tmp" >/dev/null 2>&1 \
       && [ $((SECONDS - t0)) -le 10 ]; then
      rm -f "$tmp"; echo "▶ simulator warm after $((SECONDS))s"; return 0
    fi
    sleep 20
  done
  echo "simulator never warmed up"; return 1
}

device_udid() {
  # $1 = display name; prints UDID of an existing "QB Shots — <name>" device, or empty
  xcrun simctl list devices | grep "QB Shots — $1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true
}

for spec in "${ALL_DEVICES[@]}"; do
  IFS='|' read -r SLUG TYPE NAME <<<"$spec"
  if [ -n "$WANT" ] && [[ " $WANT " != *" $SLUG "* ]]; then continue; fi

  echo ""
  echo "════ $NAME ($SLUG) ════"
  UDID=$(device_udid "$NAME")
  if [ -z "$UDID" ]; then
    UDID=$(xcrun simctl create "QB Shots — $NAME" "$TYPE" "$RUNTIME")
    echo "▶ created $UDID"
  else
    echo "▶ reusing $UDID"
  fi

  # One booted simulator at a time; three of them exhausted memory.
  { xcrun simctl list devices | grep "QB Shots — " | grep Booted | grep -v "$UDID" || true; } \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' \
    | while read -r u; do xcrun simctl shutdown "$u" >/dev/null 2>&1 || true; done
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  warm_up "$UDID"

  xcrun simctl install "$UDID" "$APP"
  xcrun simctl privacy "$UDID" grant location "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl privacy "$UDID" grant location-always "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl location "$UDID" set "$LOCATION" >/dev/null 2>&1 || true
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 \
    >/dev/null 2>&1 || true

  OUT="$PWD/$OUT_ROOT/$SLUG"
  mkdir -p "$OUT/.prev"
  # Stash the previous run's PNGs instead of deleting them, so a failed run
  # can't wipe a good set; xcodebuild refuses to reuse a result bundle.
  mv "$OUT"/*.png "$OUT/.prev/" 2>/dev/null || true
  rm -rf "$OUT/result.xcresult"

  # XCTest's accessibility bridge can lag the screenshot service by a few
  # minutes after a cold boot ("Timed out while loading Accessibility",
  # "Timed out while evaluating UI query"). Retry once after a pause.
  for attempt in 1 2; do
    echo "▶ running ScreenshotTests (attempt $attempt) → $OUT"
    rm -rf "$OUT/result.xcresult"
    TEST_RUNNER_SCREENSHOT_DIR="$OUT" xcodebuild test-without-building \
      -xctestrun "$XCTESTRUN" \
      -destination "id=$UDID" \
      -only-testing:QueueBuddyUITests/ScreenshotTests \
      -resultBundlePath "$OUT/result.xcresult" \
      -quiet 2>&1 | grep -E "error:|Test Case|passed|failed|Executed" || true
    RESULT=$(xcrun xcresulttool get test-results summary --path "$OUT/result.xcresult" 2>/dev/null \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("result",""))' 2>/dev/null || echo "")
    [ "$RESULT" = "Passed" ] && break
    [ "$attempt" = "1" ] && { echo "▶ attempt 1 did not pass ($RESULT); waiting 180 s for the simulator to settle"; sleep 180; }
  done

  xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
  xcrun xcresulttool get test-results summary --path "$OUT/result.xcresult" 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("▶ result:", d.get("result"), "| passed", d.get("passedTests"), "failed", d.get("failedTests"))
for f in d.get("testFailures", []): print("   FAIL:", f.get("testName"), "->", (f.get("failureText") or "")[:300])
' || true
  echo "▶ captured:"; ls -1 "$OUT" | grep '\.png' || echo "   (none)"
done

echo ""
echo "Done. Output under $OUT_ROOT/"

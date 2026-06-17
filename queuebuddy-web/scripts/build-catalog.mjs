// Regenerates src/data/catalog.json and public/attractions/<uuid>.png — the
// static attraction metadata + thumbnails the web app uses to enrich live data
// (land grouping, single-rider detection, per-attraction icons).
//
// Source of truth is the iOS app's static data, two levels up in the repo:
//   - "QueueBuddy - Park Waits/attractions.json"   (int id -> name/parkId/tpwUuid)
//   - "QueueBuddy - Park Waits/StaticData.swift"    (int id -> land)
//   - "QueueBuddy - Park Waits/Assets.xcassets/Attraction_<id>.imageset/*.png"
//
// We join on the queue-times int id and re-key by the ThemeParks.wiki UUID
// (`tpwUuid`) — exactly the `id` the live endpoint returns — so the runtime
// lookup is an O(1) hit with no fragile name matching. Thumbnails are copied
// out of the iOS asset catalog and renamed to <uuid>.png so the web can request
// them by attraction id.
//
// Run:  npm run build:catalog

import { readFileSync, writeFileSync, readdirSync, copyFileSync, mkdirSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const iosDir = resolve(__dirname, "../../QueueBuddy - Park Waits");
const attractionsPath = resolve(iosDir, "attractions.json");
const staticDataPath = resolve(iosDir, "StaticData.swift");
const assetsDir = resolve(iosDir, "Assets.xcassets");
const outPath = resolve(__dirname, "../src/data/catalog.json");
const imagesOutDir = resolve(__dirname, "../public/attractions");

// queue-times int parkId -> our URL slug. Mirror of PARKS in src/lib/parks.ts.
const PARK_SLUG_BY_INTERNAL_ID = {
  5: "epcot",
  6: "magic-kingdom",
  7: "hollywood-studios",
  8: "animal-kingdom",
  64: "islands-of-adventure",
  65: "universal-studios",
  334: "epic-universe",
};

/** Parse the `attractionToLandMapping` dictionary out of StaticData.swift. */
function parseLandMap(swift) {
  const start = swift.indexOf("attractionToLandMapping");
  if (start === -1) throw new Error("attractionToLandMapping not found in StaticData.swift");
  const end = swift.indexOf("\n    ]", start);
  const block = swift.slice(start, end === -1 ? undefined : end);
  const map = {};
  const re = /^\s*(\d+):\s*"((?:[^"\\]|\\.)*)"/gm;
  let m;
  while ((m = re.exec(block)) !== null) map[Number(m[1])] = m[2];
  return map;
}

/** Find the thumbnail PNG inside Attraction_<id>.imageset, if present. */
function imagesetPng(internalId) {
  const dir = join(assetsDir, `Attraction_${internalId}.imageset`);
  try {
    const png = readdirSync(dir).find((f) => f.toLowerCase().endsWith(".png"));
    return png ? join(dir, png) : null;
  } catch {
    return null;
  }
}

const attractions = JSON.parse(readFileSync(attractionsPath, "utf8"));
const landMap = parseLandMap(readFileSync(staticDataPath, "utf8"));
const isSingleRider = (a) => /single rider/i.test(a.name);

// Rebuild the image output dir from scratch so stale thumbnails don't linger.
rmSync(imagesOutDir, { recursive: true, force: true });
mkdirSync(imagesOutDir, { recursive: true });

// Several rides share one ThemeParks.wiki UUID with their single-rider variant
// (the live feed only ever returns the parent entity). Group by UUID and keep
// the parent as the canonical row, flagging that a single-rider queue exists.
const byUuid = new Map();
let missingUuid = 0;
for (const a of attractions) {
  if (!a.tpwUuid) {
    missingUuid++;
    continue;
  }
  const list = byUuid.get(a.tpwUuid) ?? [];
  list.push(a);
  byUuid.set(a.tpwUuid, list);
}

const catalog = [];
let missingLand = 0;
let withImage = 0;
for (const [uuid, rows] of byUuid) {
  const primary = rows.find((r) => !isSingleRider(r)) ?? rows[0];
  const land = landMap[primary.id] ?? null;
  if (!land) missingLand++;

  // Prefer the parent's thumbnail; fall back to any variant that has one.
  let src = imagesetPng(primary.id);
  if (!src) for (const r of rows) if ((src = imagesetPng(r.id))) break;
  let hasImage = false;
  if (src) {
    copyFileSync(src, join(imagesOutDir, `${uuid}.png`));
    hasImage = true;
    withImage++;
  }

  catalog.push({
    uuid,
    name: primary.name,
    parkSlug: PARK_SLUG_BY_INTERNAL_ID[primary.parkId] ?? null,
    land,
    type: primary.type ?? null,
    singleRider: rows.some(isSingleRider),
    image: hasImage,
  });
}

catalog.sort((x, y) => x.name.localeCompare(y.name));
writeFileSync(outPath, JSON.stringify(catalog, null, 0) + "\n");

console.log(
  `catalog.json: ${catalog.length} attractions ` +
    `(${withImage} with thumbnail, ${missingLand} without a land, ${missingUuid} skipped for missing tpwUuid)`,
);

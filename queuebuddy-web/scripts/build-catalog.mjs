// Regenerates src/data/catalog.json — the static attraction metadata the web
// app uses to enrich live data (land grouping, single-rider detection).
//
// Source of truth is the iOS app's static data, two files up in the repo:
//   - "QueueBuddy - Park Waits/attractions.json"  (int id -> name/parkId/tpwUuid)
//   - "QueueBuddy - Park Waits/StaticData.swift"   (int id -> land)
//
// We join them on the queue-times int id and re-key by the ThemeParks.wiki
// UUID (`tpwUuid`), which is exactly the `id` the live endpoint returns — so
// the runtime lookup is an O(1) hit with no fragile name matching.
//
// Run:  npm run build:catalog

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const iosDir = resolve(__dirname, "../../QueueBuddy - Park Waits");
const attractionsPath = resolve(iosDir, "attractions.json");
const staticDataPath = resolve(iosDir, "StaticData.swift");
const outPath = resolve(__dirname, "../src/data/catalog.json");

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
  // The dictionary literal closes on the first 4-space-indented `]`.
  const end = swift.indexOf("\n    ]", start);
  const block = swift.slice(start, end === -1 ? undefined : end);
  const map = {};
  // Match lines like:  130: "Frontierland",  // Big Thunder Mountain Railroad
  const re = /^\s*(\d+):\s*"((?:[^"\\]|\\.)*)"/gm;
  let m;
  while ((m = re.exec(block)) !== null) {
    map[Number(m[1])] = m[2];
  }
  return map;
}

const attractions = JSON.parse(readFileSync(attractionsPath, "utf8"));
const landMap = parseLandMap(readFileSync(staticDataPath, "utf8"));

const catalog = [];
let missingUuid = 0;
let missingLand = 0;
for (const a of attractions) {
  if (!a.tpwUuid) {
    missingUuid++;
    continue;
  }
  const land = landMap[a.id] ?? null;
  if (!land) missingLand++;
  catalog.push({
    uuid: a.tpwUuid,
    name: a.name,
    parkSlug: PARK_SLUG_BY_INTERNAL_ID[a.parkId] ?? null,
    land,
    type: a.type ?? null,
    singleRider: /single rider/i.test(a.name),
  });
}

catalog.sort((x, y) => x.name.localeCompare(y.name));
writeFileSync(outPath, JSON.stringify(catalog, null, 0) + "\n");

console.log(
  `catalog.json: ${catalog.length} attractions ` +
    `(${missingLand} without a land, ${missingUuid} skipped for missing tpwUuid)`,
);

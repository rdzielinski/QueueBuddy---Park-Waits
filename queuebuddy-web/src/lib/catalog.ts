import catalogJson from "../data/catalog.json";

/** One static attraction record, keyed at runtime by ThemeParks.wiki UUID
 *  (which is exactly the `id` the live endpoint returns). Generated from the
 *  iOS app's static data by scripts/build-catalog.mjs. */
export interface CatalogEntry {
  uuid: string;
  name: string;
  parkSlug: string | null;
  land: string | null;
  type: string | null;
  singleRider: boolean;
  /** True when a thumbnail exists at /attractions/<uuid>.png. */
  image: boolean;
}

const CATALOG = catalogJson as CatalogEntry[];
const BY_UUID = new Map(CATALOG.map((e) => [e.uuid, e]));

export function catalogEntry(uuid: string): CatalogEntry | undefined {
  return BY_UUID.get(uuid);
}

/** Public path to an attraction's thumbnail, or null when there isn't one. */
export function imageFor(uuid: string): string | null {
  return BY_UUID.get(uuid)?.image ? `/attractions/${uuid}.png` : null;
}

/** Substring search over attraction names, prefix matches ranked first. */
export function searchAttractions(query: string, limit = 16): CatalogEntry[] {
  const q = query.trim().toLowerCase();
  if (!q) return [];
  const hits: { entry: CatalogEntry; rank: number }[] = [];
  for (const e of CATALOG) {
    const idx = e.name.toLowerCase().indexOf(q);
    if (idx !== -1) hits.push({ entry: e, rank: idx === 0 ? 0 : 1 });
  }
  hits.sort((a, b) => a.rank - b.rank || a.entry.name.localeCompare(b.entry.name));
  return hits.slice(0, limit).map((h) => h.entry);
}

/** Land name for an attraction, or a generic bucket when we don't have it. */
export function landFor(uuid: string): string {
  return BY_UUID.get(uuid)?.land ?? "More";
}

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
}

const CATALOG = catalogJson as CatalogEntry[];
const BY_UUID = new Map(CATALOG.map((e) => [e.uuid, e]));

export function catalogEntry(uuid: string): CatalogEntry | undefined {
  return BY_UUID.get(uuid);
}

/** Land name for an attraction, or a generic bucket when we don't have it. */
export function landFor(uuid: string): string {
  return BY_UUID.get(uuid)?.land ?? "More";
}

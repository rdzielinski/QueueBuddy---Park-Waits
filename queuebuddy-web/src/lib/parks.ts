import type { ParkHours, Resort } from "./types";

/** Client-side park reference. The resort grouping + display names live here;
 *  the slug↔UUID mapping the Functions use is mirrored in functions/api/_shared.ts.
 *  `hours` are approximate year-round defaults — ParkPage shows real hours from
 *  the schedule endpoint and falls back to these. */
export interface ParkMeta {
  slug: string;
  name: string;
  shortName: string;
  resort: Resort;
  hours: ParkHours;
}

export const PARKS: ParkMeta[] = [
  { slug: "magic-kingdom", name: "Magic Kingdom Park", shortName: "Magic Kingdom", resort: "WDW", hours: { open: "9:00 AM", close: "10:00 PM" } },
  { slug: "epcot", name: "EPCOT", shortName: "EPCOT", resort: "WDW", hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "hollywood-studios", name: "Disney's Hollywood Studios", shortName: "Hollywood Studios", resort: "WDW", hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "animal-kingdom", name: "Disney's Animal Kingdom", shortName: "Animal Kingdom", resort: "WDW", hours: { open: "8:00 AM", close: "7:00 PM" } },
  { slug: "universal-studios", name: "Universal Studios Florida", shortName: "Universal Studios", resort: "UNIVERSAL", hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "islands-of-adventure", name: "Universal's Islands of Adventure", shortName: "Islands of Adventure", resort: "UNIVERSAL", hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "epic-universe", name: "Universal's Epic Universe", shortName: "Epic Universe", resort: "UNIVERSAL", hours: { open: "9:00 AM", close: "10:00 PM" } },
];

export const RESORT_LABELS: Record<Resort, string> = {
  WDW: "Walt Disney World",
  UNIVERSAL: "Universal Orlando Resort",
};

/** Resorts in display order, used to group the board. */
export const RESORT_ORDER: Resort[] = ["WDW", "UNIVERSAL"];

const PARK_BY_SLUG = new Map(PARKS.map((p) => [p.slug, p]));

export function parkBySlug(slug: string | undefined): ParkMeta | undefined {
  return slug ? PARK_BY_SLUG.get(slug) : undefined;
}

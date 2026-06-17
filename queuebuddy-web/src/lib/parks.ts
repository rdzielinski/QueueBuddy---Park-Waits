import type { ParkHours, Resort } from "./types";

/** Client-side park reference: resort grouping, display names, the per-park
 *  accent color + glyph the departure board uses, and approximate hours.
 *  The slug↔UUID mapping the Functions use is mirrored in functions/api/_shared.ts. */
export interface ParkMeta {
  slug: string;
  name: string;
  shortName: string;
  resort: Resort;
  /** Route-color accent (mirrors DB.accent in the iOS app). */
  accent: string;
  /** Emoji glyph shown on the park card (web stand-in for the iOS silhouette). */
  glyph: string;
  /** Approximate year-round hours, 24h local. ParkPage shows real hours. */
  openHour: number;
  closeHour: number;
  hours: ParkHours;
}

export const PARKS: ParkMeta[] = [
  { slug: "magic-kingdom", name: "Magic Kingdom Park", shortName: "Magic Kingdom", resort: "WDW", accent: "#6FA8FF", glyph: "🏰", openHour: 9, closeHour: 22, hours: { open: "9:00 AM", close: "10:00 PM" } },
  { slug: "epcot", name: "EPCOT", shortName: "EPCOT", resort: "WDW", accent: "#C8B8FF", glyph: "🌐", openHour: 9, closeHour: 21, hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "hollywood-studios", name: "Disney's Hollywood Studios", shortName: "Hollywood Studios", resort: "WDW", accent: "#FF8C7A", glyph: "🎬", openHour: 9, closeHour: 21, hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "animal-kingdom", name: "Disney's Animal Kingdom", shortName: "Animal Kingdom", resort: "WDW", accent: "#7FD4A0", glyph: "🌿", openHour: 8, closeHour: 19, hours: { open: "8:00 AM", close: "7:00 PM" } },
  { slug: "universal-studios", name: "Universal Studios Florida", shortName: "Universal Studios", resort: "UNIVERSAL", accent: "#FFB547", glyph: "⭐️", openHour: 9, closeHour: 21, hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "islands-of-adventure", name: "Universal's Islands of Adventure", shortName: "Islands of Adventure", resort: "UNIVERSAL", accent: "#FF6B6B", glyph: "🏝️", openHour: 9, closeHour: 21, hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "epic-universe", name: "Universal's Epic Universe", shortName: "Epic Universe", resort: "UNIVERSAL", accent: "#B583FF", glyph: "🪐", openHour: 9, closeHour: 22, hours: { open: "9:00 AM", close: "10:00 PM" } },
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

const DEFAULT_ACCENT = "#FFB547";

export function parkAccent(slug: string | undefined): string {
  return parkBySlug(slug)?.accent ?? DEFAULT_ACCENT;
}

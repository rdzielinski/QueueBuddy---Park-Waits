// Per-attraction icon, keyed by the catalog `type` (mirrors the categories the
// iOS app draws as silhouettes). Emoji keep it asset-free and render crisply on
// the Apple platforms this is built for.
const ICON_BY_TYPE: Record<string, string> = {
  coaster: "🎢",
  water: "🌊",
  boat: "🚤",
  train: "🚂",
  car: "🚗",
  carousel: "🎠",
  spinner: "🎡",
  drop: "🪂",
  darkride: "🌙",
  simulator: "🛸",
  shooter: "🎯",
  show: "🎭",
  meet: "👋",
  experience: "✨",
  safari: "🦁",
};

const FALLBACK = "🎟️";

export function iconForType(type: string | null | undefined): string {
  return (type && ICON_BY_TYPE[type]) || FALLBACK;
}

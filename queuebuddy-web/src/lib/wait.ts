import type { Attraction, WaitStatus } from "./types";

export type WaitTone = "low" | "med" | "high" | "down";

/** Minutes → tone. Tiers match the iOS app (DB.waitTone): ≤15 green, ≤45 amber, else red. */
export function waitTone(minutes: number | null | undefined): WaitTone {
  if (minutes == null) return "down";
  if (minutes <= 15) return "low";
  if (minutes <= 45) return "med";
  return "high";
}

/** Tone for an attraction, accounting for non-operating status. */
export function attractionTone(a: Pick<Attraction, "status" | "waitMinutes">): WaitTone {
  if (a.status !== "OPERATING") return "down";
  return waitTone(a.waitMinutes);
}

export const TONE_VAR: Record<WaitTone, string> = {
  low: "var(--color-wait-low)",
  med: "var(--color-wait-med)",
  high: "var(--color-wait-high)",
  down: "var(--color-status-down)",
};

export const TONE_CLASS: Record<WaitTone, string> = {
  low: "wait-low",
  med: "wait-med",
  high: "wait-high",
  down: "wait-down",
};

/** The 3-char board string for a wait: minutes, or an em dash when not open. */
export function waitGlyph(a: Pick<Attraction, "status" | "waitMinutes">): string {
  if (a.status !== "OPERATING" || a.waitMinutes == null) return "—";
  return String(a.waitMinutes);
}

const STATUS_LABEL: Record<WaitStatus, string> = {
  OPERATING: "Operating",
  DOWN: "Down",
  CLOSED: "Closed",
  REFURBISHMENT: "Refurb",
  UNKNOWN: "Unknown",
};

export function statusLabel(status: WaitStatus): string {
  return STATUS_LABEL[status] ?? "Unknown";
}

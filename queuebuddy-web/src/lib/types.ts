// Normalized shapes the UI consumes. The `/api/*` Pages Functions do the
// shape-wrangling against the upstreams (ThemeParks.wiki for live data, the
// QueueBuddy Worker for history) and return exactly these.

export type WaitStatus =
  | "OPERATING"
  | "DOWN"
  | "CLOSED"
  | "REFURBISHMENT"
  | "UNKNOWN";

export type Resort = "WDW" | "UNIVERSAL";

export interface ParkHours {
  open: string;
  close: string;
}

/** A single longest-wait attraction, surfaced for the board's hero. */
export interface HottestAttraction {
  id: string;
  name: string;
  waitMinutes: number;
}

export interface Park {
  id: string; // URL slug, e.g. "magic-kingdom"
  name: string; // full official name
  shortName: string; // board display name
  resort: Resort;
  openCount?: number;
  totalCount?: number;
  avgWait?: number | null;
  maxWait?: number | null;
  hours?: ParkHours | null;
  hottest?: HottestAttraction | null;
  /** Present when this park's live data couldn't be fetched. */
  stale?: boolean;
}

export interface Attraction {
  id: string; // ThemeParks.wiki entity UUID
  parkId: string; // park slug
  name: string;
  status: WaitStatus;
  waitMinutes: number | null; // null when closed/down
  singleRider?: boolean; // this row is a single-rider queue
  lastUpdated?: string; // ISO
}

export interface HistoryPoint {
  t: string; // ISO timestamp
  wait: number | null; // minutes
}
export type HistoryRange = "24h" | "7d" | "30d";

export interface LightningLane {
  id: string;
  name: string;
  price?: string | null;
  available: boolean;
}

export interface ParkSchedule {
  parkId: string;
  timezone?: string | null;
  today?: ParkHours | null;
  lightningLane: LightningLane[];
}

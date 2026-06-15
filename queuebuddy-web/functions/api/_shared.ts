// Shared helpers for the QueueBuddy Web API (Cloudflare Pages Functions).
//
// These Functions are a thin backend-for-frontend that gives the browser a
// same-origin /api/* surface (killing CORS) over two upstreams:
//   - ThemeParks.wiki  — live waits + park schedule (same source the iOS app uses)
//   - QueueBuddy Worker — long-form wait history (GET /history?name=…)
//
// The slug↔UUID table below mirrors src/lib/parks.ts on the client.

import type {
  Attraction,
  Park,
  ParkHours,
  Resort,
  WaitStatus,
} from "../../src/lib/types";

export interface Env {
  /** Origin of the existing QueueBuddy push/history Worker. Set as a Pages
   *  environment variable; falls back to the known production Worker. */
  WORKER_ORIGIN?: string;
}

export const DEFAULT_WORKER_ORIGIN = "https://queuebuddy-push.robbydz-villages.workers.dev";

const TPW_BASE = "https://api.themeparks.wiki/v1";
const TPW_HEADERS = {
  Accept: "application/json",
  "User-Agent": "QueueBuddy-Web/1.0 (+https://github.com/rdzielinski)",
};

export interface ParkRecord {
  slug: string;
  uuid: string;
  name: string;
  shortName: string;
  resort: Resort;
  hours: ParkHours; // approximate year-round defaults; ParkPage fetches real hours
}

export const PARKS: ParkRecord[] = [
  { slug: "magic-kingdom", uuid: "75ea578a-adc8-4116-a54d-dccb60765ef9", name: "Magic Kingdom Park", shortName: "Magic Kingdom", resort: "WDW", hours: { open: "9:00 AM", close: "10:00 PM" } },
  { slug: "epcot", uuid: "47f90d2c-e191-4239-a466-5892ef59a88b", name: "EPCOT", shortName: "EPCOT", resort: "WDW", hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "hollywood-studios", uuid: "288747d1-8b4f-4a64-867e-ea7c9b27bad8", name: "Disney's Hollywood Studios", shortName: "Hollywood Studios", resort: "WDW", hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "animal-kingdom", uuid: "1c84a229-8862-4648-9c71-378ddd2c7693", name: "Disney's Animal Kingdom", shortName: "Animal Kingdom", resort: "WDW", hours: { open: "8:00 AM", close: "7:00 PM" } },
  { slug: "universal-studios", uuid: "eb3f4560-2383-4a36-9152-6b3e5ed6bc57", name: "Universal Studios Florida", shortName: "Universal Studios", resort: "UNIVERSAL", hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "islands-of-adventure", uuid: "267615cc-8943-4c2a-ae2c-5da728ca591f", name: "Universal's Islands of Adventure", shortName: "Islands of Adventure", resort: "UNIVERSAL", hours: { open: "9:00 AM", close: "9:00 PM" } },
  { slug: "epic-universe", uuid: "12dbb85b-265f-44e6-bccf-f1faa17211fc", name: "Universal's Epic Universe", shortName: "Epic Universe", resort: "UNIVERSAL", hours: { open: "9:00 AM", close: "10:00 PM" } },
];

const PARK_BY_SLUG = new Map(PARKS.map((p) => [p.slug, p]));
export function parkBySlug(slug: string): ParkRecord | undefined {
  return PARK_BY_SLUG.get(slug);
}

// ---- ThemeParks.wiki live ----

interface TPWQueue {
  STANDBY?: { waitTime?: number | null } | null;
}
interface TPWLiveEntity {
  id: string;
  name: string;
  entityType: string;
  status?: string | null;
  queue?: TPWQueue | null;
  lastUpdated?: string | null;
}
interface TPWLiveResponse {
  liveData?: TPWLiveEntity[];
}

function normalizeStatus(raw: string | null | undefined): WaitStatus {
  switch ((raw ?? "").toUpperCase()) {
    case "OPERATING":
      return "OPERATING";
    case "DOWN":
      return "DOWN";
    case "CLOSED":
      return "CLOSED";
    case "REFURBISHMENT":
      return "REFURBISHMENT";
    default:
      return "UNKNOWN";
  }
}

const SINGLE_RIDER_RE = /single rider/i;

function toAttraction(e: TPWLiveEntity, parkSlug: string): Attraction {
  const status = normalizeStatus(e.status);
  const standby = e.queue?.STANDBY?.waitTime;
  return {
    id: e.id,
    parkId: parkSlug,
    name: e.name,
    status,
    waitMinutes: typeof standby === "number" ? standby : null,
    singleRider: SINGLE_RIDER_RE.test(e.name) || undefined,
    lastUpdated: e.lastUpdated ?? undefined,
  };
}

/** Fetch + normalize one park's live attractions. Throws on upstream failure. */
export async function fetchParkLive(uuid: string, parkSlug: string): Promise<Attraction[]> {
  const res = await fetch(`${TPW_BASE}/entity/${uuid}/live`, { headers: TPW_HEADERS });
  if (!res.ok) throw new Error(`themeparks.wiki ${uuid}: HTTP ${res.status}`);
  const body = (await res.json()) as TPWLiveResponse;
  const live = body.liveData ?? [];
  return live
    .filter((e) => e.entityType === "ATTRACTION")
    .map((e) => toAttraction(e, parkSlug))
    .sort((a, b) => a.name.localeCompare(b.name));
}

/** Aggregate one park's live attractions into the board's Park summary. */
export function summarize(park: ParkRecord, attractions: Attraction[]): Park {
  const operating = attractions.filter((a) => a.status === "OPERATING");
  const withWaits = operating.filter((a) => typeof a.waitMinutes === "number");
  const total = withWaits.reduce((sum, a) => sum + (a.waitMinutes ?? 0), 0);
  const avg = withWaits.length ? Math.round(total / withWaits.length) : null;

  let hottest: Park["hottest"] = null;
  for (const a of withWaits) {
    if (!hottest || (a.waitMinutes ?? 0) > hottest.waitMinutes) {
      hottest = { id: a.id, name: a.name, waitMinutes: a.waitMinutes as number };
    }
  }

  return {
    id: park.slug,
    name: park.name,
    shortName: park.shortName,
    resort: park.resort,
    openCount: operating.length,
    totalCount: attractions.length,
    avgWait: avg,
    maxWait: hottest?.waitMinutes ?? null,
    hours: park.hours,
    hottest,
  };
}

// ---- ThemeParks.wiki schedule ----

interface TPWPurchase {
  id: string;
  name: string;
  available?: boolean;
  price?: { formatted?: string | null } | null;
}
interface TPWScheduleEntry {
  date: string;
  type: string;
  openingTime?: string | null;
  closingTime?: string | null;
  purchases?: TPWPurchase[] | null;
}
export interface TPWScheduleResponse {
  timezone?: string | null;
  schedule?: TPWScheduleEntry[];
}

export async function fetchScheduleRaw(uuid: string): Promise<TPWScheduleResponse> {
  const res = await fetch(`${TPW_BASE}/entity/${uuid}/schedule`, { headers: TPW_HEADERS });
  if (!res.ok) throw new Error(`themeparks.wiki schedule ${uuid}: HTTP ${res.status}`);
  return (await res.json()) as TPWScheduleResponse;
}

/** Today's date (YYYY-MM-DD) in a given IANA timezone. */
export function todayInTz(tz: string): string {
  // en-CA gives ISO-style YYYY-MM-DD.
  return new Intl.DateTimeFormat("en-CA", { timeZone: tz }).format(new Date());
}

/** Format an ISO instant to a friendly park-local clock string. */
export function formatLocalTime(iso: string | null | undefined, tz: string): string | null {
  if (!iso) return null;
  const ms = Date.parse(iso);
  if (Number.isNaN(ms)) return null;
  return new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(ms));
}

// ---- HTTP helpers ----

export function json(data: unknown, init: { status?: number; maxAge?: number } = {}): Response {
  const { status = 200, maxAge = 0 } = init;
  const headers: Record<string, string> = {
    "content-type": "application/json; charset=utf-8",
    "access-control-allow-origin": "*",
  };
  if (maxAge > 0) headers["cache-control"] = `public, max-age=${maxAge}, s-maxage=${maxAge}`;
  return new Response(JSON.stringify(data), { status, headers });
}

export function errorJson(status: number, message: string): Response {
  return json({ error: message }, { status });
}

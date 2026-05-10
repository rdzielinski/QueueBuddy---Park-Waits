/**
 * Minimal wrapper around the ThemeParks.wiki live endpoint, scoped to
 * the fields we need to push to a Live Activity. The full schema is
 * larger; we ignore the rest.
 *
 * One park's worth of live data per call. Callers should batch by park
 * (fan out concurrently) — never one request per attraction.
 */

export interface LiveAttraction {
  externalName: string; // matched against the activity's stored attractionName
  waitMinutes: number | null;
  status: string; // "OPERATING" / "DOWN" / "CLOSED" / "REFURBISHMENT"
}

interface TPWLiveResponse {
  liveData: TPWEntity[];
}
interface TPWEntity {
  name: string;
  entityType: string;
  status?: string;
  queue?: { STANDBY?: { waitTime?: number | null } };
}

const BASE = "https://api.themeparks.wiki/v1";

export async function fetchPark(parkUUID: string): Promise<LiveAttraction[]> {
  const res = await fetch(`${BASE}/entity/${parkUUID}/live`, {
    headers: { Accept: "application/json", "User-Agent": "QueueBuddy-Push-Worker/1.0" },
  });
  if (!res.ok) {
    throw new Error(`themeparks.wiki ${parkUUID}: HTTP ${res.status}`);
  }
  const body = (await res.json()) as TPWLiveResponse;
  return body.liveData
    .filter((e) => e.entityType === "ATTRACTION")
    .map((e) => ({
      externalName: e.name,
      waitMinutes: e.queue?.STANDBY?.waitTime ?? null,
      status: (e.status ?? "UNKNOWN").toUpperCase(),
    }));
}

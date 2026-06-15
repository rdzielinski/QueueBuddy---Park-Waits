import { json, errorJson, DEFAULT_WORKER_ORIGIN, type Env } from "./_shared";
import type { HistoryPoint } from "../../src/lib/types";

const RANGE_SECONDS: Record<string, number> = {
  "24h": 24 * 60 * 60,
  "7d": 7 * 24 * 60 * 60,
  "30d": 30 * 24 * 60 * 60,
};

interface WorkerHistory {
  ok?: boolean;
  samples?: Array<{ at: number; wait: number | null; status?: string }>;
}

/**
 * GET /api/history?name=<attraction>&range=24h|7d|30d
 *
 * Proxies the QueueBuddy Worker's name-keyed /history endpoint and reshapes
 * its { at, wait } samples into the HistoryPoint[] the chart consumes.
 */
export const onRequestGet: PagesFunction<Env> = async ({ request, env }) => {
  const url = new URL(request.url);
  const name = url.searchParams.get("name");
  if (!name) return errorJson(400, "missing name");

  const range = url.searchParams.get("range") ?? "7d";
  const windowSeconds = RANGE_SECONDS[range] ?? RANGE_SECONDS["7d"];
  const since = Math.floor(Date.now() / 1000) - windowSeconds;
  const limit = range === "24h" ? 300 : range === "30d" ? 5000 : 2000;

  const origin = env.WORKER_ORIGIN ?? DEFAULT_WORKER_ORIGIN;
  const upstream =
    `${origin}/history?name=${encodeURIComponent(name)}` +
    `&since=${since}&limit=${limit}`;

  let res: Response;
  try {
    res = await fetch(upstream, { headers: { accept: "application/json" } });
  } catch (e) {
    return errorJson(502, `history upstream unreachable: ${(e as Error).message}`);
  }
  if (!res.ok) return errorJson(502, `history upstream HTTP ${res.status}`);

  const body = (await res.json()) as WorkerHistory;
  const points: HistoryPoint[] = (body.samples ?? []).map((s) => ({
    t: new Date(s.at * 1000).toISOString(),
    wait: s.wait,
  }));

  return json(points, { maxAge: range === "24h" ? 120 : 600 });
};

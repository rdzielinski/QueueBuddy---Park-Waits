import {
  parkBySlug,
  fetchScheduleRaw,
  todayInTz,
  formatLocalTime,
  json,
  errorJson,
  type Env,
} from "../../_shared";
import type { LightningLane, ParkSchedule } from "../../../../src/lib/types";

/** GET /api/parks/:parkId/schedule — today's hours + Lightning Lane options. */
export const onRequestGet: PagesFunction<Env> = async ({ params }) => {
  const slug = String(params.parkId);
  const park = parkBySlug(slug);
  if (!park) return errorJson(404, `unknown park: ${slug}`);

  try {
    const raw = await fetchScheduleRaw(park.uuid);
    const tz = raw.timezone ?? "America/New_York";
    const today = todayInTz(tz);
    const entries = (raw.schedule ?? []).filter((e) => e.date === today);

    const op = entries.find((e) => (e.type ?? "").toUpperCase() === "OPERATING");
    const todayHours = op
      ? {
          open: formatLocalTime(op.openingTime, tz) ?? "—",
          close: formatLocalTime(op.closingTime, tz) ?? "—",
        }
      : null;

    // Lightning Lane purchases ride under the day's entries; dedupe by id.
    const llById = new Map<string, LightningLane>();
    for (const e of entries) {
      for (const p of e.purchases ?? []) {
        if (!llById.has(p.id)) {
          llById.set(p.id, {
            id: p.id,
            name: p.name,
            price: p.price?.formatted ?? null,
            available: Boolean(p.available),
          });
        }
      }
    }

    const schedule: ParkSchedule = {
      parkId: slug,
      timezone: tz,
      today: todayHours,
      lightningLane: [...llById.values()],
    };
    return json(schedule, { maxAge: 300 });
  } catch (e) {
    return errorJson(502, `schedule fetch failed: ${(e as Error).message}`);
  }
};

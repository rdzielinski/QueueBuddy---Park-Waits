import { PARKS, fetchParkLive, summarize, json, type Env } from "./_shared";
import type { Park } from "../../src/lib/types";

/** GET /api/parks — board summary for all seven parks. */
export const onRequestGet: PagesFunction<Env> = async () => {
  const results = await Promise.allSettled(
    PARKS.map((p) => fetchParkLive(p.uuid, p.slug)),
  );

  const parks: Park[] = results.map((r, i) => {
    const park = PARKS[i];
    if (r.status === "fulfilled") return summarize(park, r.value);
    // One dark park shouldn't blank the whole board.
    return {
      id: park.slug,
      name: park.name,
      shortName: park.shortName,
      resort: park.resort,
      openCount: 0,
      totalCount: 0,
      avgWait: null,
      maxWait: null,
      hours: park.hours,
      hottest: null,
      stale: true,
    };
  });

  return json(parks, { maxAge: 60 });
};

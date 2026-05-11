import { fetchPark, type LiveAttraction } from "./themeparks";
import { KNOWN_PARKS } from "./parks";

/**
 * Long-form wait history sampler.
 *
 * Called from the every-5-minutes cron tick. For each known park, fetches
 * the live endpoint once and inserts one row per attraction into D1.
 * Rows are keyed by (attraction_name, sampled_at) so duplicate samples
 * (e.g. two cron ticks racing) just collide on the primary key and the
 * second one no-ops — no UPSERT needed.
 *
 * Storage cost (rough): 7 parks × ~35 attractions × 288 ticks/day ≈
 * 70k rows/day, well inside D1's 100k-write/day free tier. Each row
 * is ~30 bytes; 30 days of retention sits comfortably in the 5GB cap.
 */
export async function sampleAllParks(db: D1Database): Promise<{
  parks: number; samples: number; failures: string[];
}> {
  const sampledAt = Math.floor(Date.now() / 1000);
  const failures: string[] = [];

  // Fetch all 7 parks in parallel. One failed park shouldn't block the rest.
  const results = await Promise.allSettled(
    KNOWN_PARKS.map(async (park) => ({ park, live: await fetchPark(park.uuid) })),
  );

  let totalSamples = 0;
  let okParks = 0;
  const batch: D1PreparedStatement[] = [];
  const insertStmt = db.prepare(
    "INSERT OR IGNORE INTO wait_samples (attraction_name, park_uuid, sampled_at, wait_minutes, status) VALUES (?, ?, ?, ?, ?)",
  );

  for (const r of results) {
    if (r.status === "rejected") {
      failures.push(String(r.reason));
      continue;
    }
    okParks++;
    const { park, live } = r.value;
    for (const a of live) {
      batch.push(
        insertStmt.bind(
          a.externalName,
          park.uuid,
          sampledAt,
          a.waitMinutes,        // null is fine — INTEGER column allows null
          a.status,
        ),
      );
      totalSamples++;
    }
  }

  if (batch.length > 0) {
    // D1 batches commit atomically. ~250 rows per tick is well within
    // the per-statement-limit; if this ever grows past a few thousand
    // we'd want to chunk, but for the seven-park scope this is fine.
    await db.batch(batch);
  }

  return { parks: okParks, samples: totalSamples, failures };
}

/**
 * Query the rolling history for one attraction. The iOS app calls this
 * when its on-device 24h cache isn't enough (e.g. user picks "7 days"
 * in the sparkline picker).
 */
export async function queryHistory(db: D1Database, opts: {
  attractionName: string;
  sinceUnixSeconds: number;
  limit?: number;
}): Promise<Array<{ at: number; wait: number | null; status: string }>> {
  const limit = Math.min(opts.limit ?? 2000, 5000);
  const rows = await db
    .prepare(
      "SELECT sampled_at, wait_minutes, status FROM wait_samples " +
      "WHERE attraction_name = ? AND sampled_at >= ? " +
      "ORDER BY sampled_at ASC LIMIT ?",
    )
    .bind(opts.attractionName, opts.sinceUnixSeconds, limit)
    .all<{ sampled_at: number; wait_minutes: number | null; status: string }>();
  return (rows.results ?? []).map((r) => ({
    at: r.sampled_at,
    wait: r.wait_minutes,
    status: r.status,
  }));
}

// Re-export so callers can introspect what we sampled if they want.
export type { LiveAttraction };

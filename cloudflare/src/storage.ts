import type { RegisteredActivity, LastWaitSample } from "./types";

/**
 * KV layout:
 *   activity:<pushToken>   → RegisteredActivity   (one entry per active Live Activity)
 *   active:index           → JSON string[] of push tokens currently active
 *   lastwait:<attractionId> → LastWaitSample      (deduped across activities for the same ride)
 *
 * We key activities by the *push token* rather than attractionId so that
 * a user starting a fresh Live Activity for the same ride (after the old
 * one auto-ended) gets a new entry; the stale token expires naturally
 * the next time APNs returns 410 Gone.
 *
 * The `active:index` key was added to dodge KV's daily list-operation
 * cap (1000/day on the free tier — easily blown by a per-minute cron
 * even with zero activities). On register/unregister we read+write the
 * index alongside the activity entry; on cron we read the index once
 * and fetch each referenced key individually. That replaces ~1440
 * list ops/day with ~1440 GETs (well inside the 100k/day GET cap).
 */

const ACTIVITY_PREFIX = "activity:";
const LASTWAIT_PREFIX = "lastwait:";
const INDEX_KEY = "active:index";

export class Storage {
  constructor(private kv: KVNamespace) {}

  // ----- Active activities (push tokens) -----

  async putActivity(activity: RegisteredActivity): Promise<void> {
    await this.kv.put(ACTIVITY_PREFIX + activity.pushToken, JSON.stringify(activity));
    await this.updateIndex((tokens) =>
      tokens.includes(activity.pushToken) ? tokens : [...tokens, activity.pushToken],
    );
  }

  async deleteActivity(pushToken: string): Promise<void> {
    await this.kv.delete(ACTIVITY_PREFIX + pushToken);
    await this.updateIndex((tokens) => tokens.filter((t) => t !== pushToken));
  }

  async listActivities(): Promise<RegisteredActivity[]> {
    const indexRaw = await this.kv.get(INDEX_KEY);
    // First run after this upgrade: index key doesn't exist yet. Fall
    // back to a one-time list() to seed it from whatever's already in
    // KV. After that bootstrap, the index path takes over and we never
    // call list() again on the hot path.
    if (indexRaw === null) {
      return this.bootstrapIndex();
    }
    let tokens: string[];
    try {
      tokens = JSON.parse(indexRaw) as string[];
    } catch {
      tokens = [];
    }
    if (tokens.length === 0) return [];

    const out: RegisteredActivity[] = [];
    const orphans: string[] = [];
    for (const token of tokens) {
      const raw = await this.kv.get(ACTIVITY_PREFIX + token);
      if (raw === null) {
        // Entry disappeared (TTL'd out, manual delete, drift). Mark for
        // index repair so we don't keep re-reading a missing key.
        orphans.push(token);
        continue;
      }
      try {
        out.push(JSON.parse(raw) as RegisteredActivity);
      } catch {
        await this.kv.delete(ACTIVITY_PREFIX + token);
        orphans.push(token);
      }
    }
    if (orphans.length > 0) {
      await this.updateIndex((current) => current.filter((t) => !orphans.includes(t)));
    }
    return out;
  }

  private async bootstrapIndex(): Promise<RegisteredActivity[]> {
    const out: RegisteredActivity[] = [];
    let cursor: string | undefined;
    do {
      const page = await this.kv.list({ prefix: ACTIVITY_PREFIX, cursor });
      for (const entry of page.keys) {
        const raw = await this.kv.get(entry.name);
        if (!raw) continue;
        try {
          out.push(JSON.parse(raw) as RegisteredActivity);
        } catch {
          await this.kv.delete(entry.name);
        }
      }
      cursor = page.list_complete ? undefined : page.cursor;
    } while (cursor);
    await this.kv.put(INDEX_KEY, JSON.stringify(out.map((a) => a.pushToken)));
    return out;
  }

  private async updateIndex(transform: (tokens: string[]) => string[]): Promise<void> {
    const raw = await this.kv.get(INDEX_KEY);
    let tokens: string[] = [];
    if (raw) {
      try {
        tokens = JSON.parse(raw) as string[];
      } catch {
        tokens = [];
      }
    }
    const next = transform(tokens);
    await this.kv.put(INDEX_KEY, JSON.stringify(next));
  }

  // ----- Last-known wait per attraction (dedup) -----

  async getLastWait(attractionId: number): Promise<LastWaitSample | null> {
    const raw = await this.kv.get(LASTWAIT_PREFIX + attractionId);
    if (!raw) return null;
    try { return JSON.parse(raw) as LastWaitSample; } catch { return null; }
  }

  async putLastWait(attractionId: number, sample: LastWaitSample): Promise<void> {
    // Expire after a day — if no Live Activity is running for a ride for
    // 24h, the cached "last sample" is no longer useful and just wastes KV.
    await this.kv.put(
      LASTWAIT_PREFIX + attractionId,
      JSON.stringify(sample),
      { expirationTtl: 24 * 60 * 60 }
    );
  }
}

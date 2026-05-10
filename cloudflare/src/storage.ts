import type { RegisteredActivity, LastWaitSample } from "./types";

/**
 * KV layout:
 *   activity:<pushToken>   → RegisteredActivity   (one entry per active Live Activity)
 *   lastwait:<attractionId> → LastWaitSample      (deduped across activities for the same ride)
 *
 * We key activities by the *push token* rather than attractionId so that
 * a user starting a fresh Live Activity for the same ride (after the old
 * one auto-ended) gets a new entry; the stale token expires naturally
 * the next time APNs returns 410 Gone.
 */

const ACTIVITY_PREFIX = "activity:";
const LASTWAIT_PREFIX = "lastwait:";

export class Storage {
  constructor(private kv: KVNamespace) {}

  // ----- Active activities (push tokens) -----

  async putActivity(activity: RegisteredActivity): Promise<void> {
    await this.kv.put(ACTIVITY_PREFIX + activity.pushToken, JSON.stringify(activity));
  }

  async deleteActivity(pushToken: string): Promise<void> {
    await this.kv.delete(ACTIVITY_PREFIX + pushToken);
  }

  async listActivities(): Promise<RegisteredActivity[]> {
    const out: RegisteredActivity[] = [];
    // KV list is paginated; in practice we'll have very few active
    // Live Activities (in-line activities are short-lived) so one
    // page is almost always enough, but loop for safety.
    let cursor: string | undefined;
    do {
      const page = await this.kv.list({ prefix: ACTIVITY_PREFIX, cursor });
      for (const entry of page.keys) {
        const raw = await this.kv.get(entry.name);
        if (!raw) continue;
        try {
          out.push(JSON.parse(raw) as RegisteredActivity);
        } catch {
          // Corrupt entry — drop it so we don't keep tripping on it.
          await this.kv.delete(entry.name);
        }
      }
      cursor = page.list_complete ? undefined : page.cursor;
    } while (cursor);
    return out;
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

import { Storage } from "./storage";
import { fetchPark, type LiveAttraction } from "./themeparks";
import { sendLiveActivityUpdate, type ApnsEnv } from "./apns";
import type { ContentState, RegisteredActivity } from "./types";

/**
 * QueueBuddy Live Activity push worker.
 *
 * Two surfaces:
 *
 *   HTTP (called by the iOS app):
 *     POST /register   { attractionId, parkUUID, pushToken, activityId,
 *                        attractionName, parkAccentHex, startedAt }
 *     POST /unregister { pushToken }
 *     GET  /health
 *
 *   Cron (every minute):
 *     1. List active push tokens from KV
 *     2. Group by parkUUID, fetch live waits once per park
 *     3. For each active activity, send a Live Activity push if the
 *        wait or status changed since the last push
 *     4. Drop tokens that APNs reports as expired (410 Gone)
 */

export interface Env extends ApnsEnv {
  PUSH_KV: KVNamespace;
}

export default {
  // ----- HTTP -----
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const storage = new Storage(env.PUSH_KV);

    if (request.method === "GET" && url.pathname === "/health") {
      return Response.json({ ok: true });
    }
    if (request.method === "GET" && url.pathname === "/debug") {
      // Dev-only sanity check: dumps all active activities so we can
      // verify register actually persisted what we expected. Public —
      // no PII, just push tokens + ride names + timestamps.
      const activities = await storage.listActivities();
      return Response.json({ count: activities.length, activities });
    }
    if (request.method === "POST" && url.pathname === "/register") {
      return handleRegister(request, storage);
    }
    if (request.method === "POST" && url.pathname === "/unregister") {
      return handleUnregister(request, storage);
    }
    return new Response("Not found", { status: 404 });
  },

  // ----- Cron -----
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(runCronTick(env));
  },
};

// --------------- HTTP handlers ---------------

async function handleRegister(request: Request, storage: Storage): Promise<Response> {
  const body = await safeJson<Partial<RegisteredActivity>>(request);
  if (!body) {
    console.warn("register: invalid JSON");
    return badRequest("invalid JSON");
  }

  const missing = [
    "attractionId",
    "parkUUID",
    "pushToken",
    "activityId",
    "attractionName",
    "parkAccentHex",
    "startedAt",
  ].filter((k) => body[k as keyof RegisteredActivity] === undefined);
  if (missing.length) {
    console.warn(`register: missing fields ${missing.join(", ")}`);
    return badRequest(`missing fields: ${missing.join(", ")}`);
  }
  // Push tokens can technically be empty strings if ActivityKit hadn't
  // emitted one yet — fail loudly rather than silently storing junk.
  if (!body.pushToken || body.pushToken.length < 32) {
    console.warn(`register: suspicious pushToken length ${body.pushToken?.length}`);
    return badRequest("pushToken too short");
  }

  await storage.putActivity(body as RegisteredActivity);
  console.log(
    `register ok: attractionId=${body.attractionId} park=${body.parkUUID} ` +
    `name="${body.attractionName}" tokenLen=${body.pushToken.length} activityId=${body.activityId}`,
  );
  return Response.json({ ok: true });
}

async function handleUnregister(request: Request, storage: Storage): Promise<Response> {
  const body = await safeJson<{ pushToken?: string }>(request);
  if (!body?.pushToken) return badRequest("missing pushToken");
  await storage.deleteActivity(body.pushToken);
  return Response.json({ ok: true });
}

function badRequest(msg: string): Response {
  return Response.json({ ok: false, error: msg }, { status: 400 });
}

async function safeJson<T>(request: Request): Promise<T | null> {
  try { return (await request.json()) as T; } catch { return null; }
}

// --------------- Cron logic ---------------

async function runCronTick(env: Env): Promise<void> {
  const storage = new Storage(env.PUSH_KV);
  const activities = await storage.listActivities();
  console.log(`cron tick: ${activities.length} active activit${activities.length === 1 ? "y" : "ies"}`);
  if (activities.length === 0) return;

  // Group by parkUUID so each park is fetched once, no matter how many
  // active activities point at rides in that park.
  const byPark = new Map<string, RegisteredActivity[]>();
  for (const a of activities) {
    const list = byPark.get(a.parkUUID) ?? [];
    list.push(a);
    byPark.set(a.parkUUID, list);
  }

  // Fan out park fetches; one failed park shouldn't block the others.
  const parkResults = await Promise.allSettled(
    [...byPark.keys()].map(async (uuid) => ({ uuid, live: await fetchPark(uuid) })),
  );
  const liveByPark = new Map<string, LiveAttraction[]>();
  for (const r of parkResults) {
    if (r.status === "fulfilled") liveByPark.set(r.value.uuid, r.value.live);
    else console.error("park fetch failed:", r.reason);
  }

  // Push per activity. We dedupe pushes against the last sample for
  // the attraction — if nothing changed, no push (Apple recommends
  // ≤1 push/min anyway, but skipping no-ops saves battery and APNs quota).
  for (const [uuid, group] of byPark) {
    const live = liveByPark.get(uuid);
    if (!live) continue;
    for (const activity of group) {
      const match = live.find((l) => l.externalName === activity.attractionName);
      if (!match) {
        console.warn(`no live entry for "${activity.attractionName}" in park ${uuid}`);
        continue;
      }
      await pushIfChanged(env, storage, activity, match);
    }
  }
}

async function pushIfChanged(
  env: Env,
  storage: Storage,
  activity: RegisteredActivity,
  live: LiveAttraction,
): Promise<void> {
  const last = await storage.getLastWait(activity.attractionId);
  const noChange = last && last.wait === live.waitMinutes && last.status === live.status;
  // Heartbeat every 10 minutes even when nothing changed — keeps the
  // Live Activity from going stale (its staleDate is 30 min ahead).
  const heartbeatDue = !last || (Date.now() / 1000 - last.fetchedAt) > 10 * 60;
  if (noChange && !heartbeatDue) return;

  const state: ContentState = {
    attractionName: activity.attractionName,
    parkAccentHex: activity.parkAccentHex,
    currentWait: live.waitMinutes,
    startedAt: activity.startedAt,
    lastUpdatedAt: Math.floor(Date.now() / 1000),
  };

  const result = await sendLiveActivityUpdate({
    env,
    pushToken: activity.pushToken,
    contentState: state,
    event: "update",
    staleAfterSeconds: 30 * 60,
  });
  console.log(
    `push ${result.ok ? "ok" : "FAIL"} ${result.status}` +
    `${result.reason ? ` (${result.reason})` : ""} ` +
    `attractionId=${activity.attractionId} wait=${live.waitMinutes ?? "—"} status=${live.status}`,
  );

  if (!result.ok) {
    // 410 Gone = token retired (user ended the activity or it expired).
    // Drop the entry; we'll be re-registered if the user starts another.
    if (result.status === 410 || result.reason === "BadDeviceToken" || result.reason === "Unregistered") {
      console.log(`token retired (${result.reason ?? result.status}), dropping`, activity.activityId);
      await storage.deleteActivity(activity.pushToken);
      return;
    }
    console.error(`APNs error ${result.status} (${result.reason ?? "?"}) for`, activity.activityId);
    return;
  }

  await storage.putLastWait(activity.attractionId, {
    wait: live.waitMinutes,
    status: live.status,
    fetchedAt: Math.floor(Date.now() / 1000),
  });
}

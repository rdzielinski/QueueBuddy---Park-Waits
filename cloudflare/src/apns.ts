import type { ContentState } from "./types";

/**
 * APNs Live Activity push sender.
 *
 * Uses provider-token auth (JWT signed with the .p8 key from the Apple
 * Developer portal) — no certificate handling. The Web Crypto API in
 * Workers supports ES256 (P-256 ECDSA) natively, so we have no npm deps.
 *
 * Apple's required headers for Live Activity updates:
 *   apns-topic:     <bundle-id>.push-type.liveactivity
 *   apns-push-type: liveactivity
 *   apns-priority:  10 (delivers immediately; 5 is "throttled / battery-aware")
 *   authorization:  bearer <provider JWT>
 *
 * Payload shape (the `aps` dictionary):
 *   timestamp:     UNIX seconds, when this update was produced
 *   event:         "update" | "end"
 *   content-state: matches ContentState exactly
 *   stale-date:    optional UNIX seconds, when iOS should mark the
 *                  activity stale (we set this to ~30 min ahead)
 *   dismissal-date: optional UNIX seconds, only on "end"
 */

export interface ApnsEnv {
  APNS_HOST: string; // "api.push.apple.com" or "api.sandbox.push.apple.com"
  APNS_KEY: string; // contents of the .p8 file (PEM-encoded)
  APNS_KEY_ID: string;
  APNS_TEAM_ID: string;
  APNS_BUNDLE_ID: string; // app's bundle id (without the .push-type.liveactivity suffix)
}

export interface ApnsResult {
  ok: boolean;
  status: number;
  reason?: string; // APNs error reason if any (e.g. "BadDeviceToken")
}

/** Cache the signed JWT for ~50 min (Apple caps validity at 60). */
let cachedJwt: { token: string; exp: number } | null = null;

async function getProviderJwt(env: ApnsEnv): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.exp - 60 > now) return cachedJwt.token;

  const header = { alg: "ES256", kid: env.APNS_KEY_ID, typ: "JWT" };
  const claims = { iss: env.APNS_TEAM_ID, iat: now };
  const headerB64 = b64url(JSON.stringify(header));
  const claimsB64 = b64url(JSON.stringify(claims));
  const signingInput = `${headerB64}.${claimsB64}`;

  const key = await importP8(env.APNS_KEY);
  const sigBuf = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const sigB64 = b64url(new Uint8Array(sigBuf));
  const token = `${signingInput}.${sigB64}`;
  // Apple rejects JWTs older than 60 minutes; renew every 50.
  cachedJwt = { token, exp: now + 50 * 60 };
  return token;
}

/** Parse a PEM-encoded PKCS#8 ECDSA P-256 private key into a CryptoKey. */
async function importP8(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

/**
 * Send one Live Activity update. Returns the HTTP status + reason so the
 * caller can detect 410 Gone (token expired — delete it) and 400/403
 * (misconfiguration — alert in logs, don't keep retrying).
 */
export async function sendLiveActivityUpdate(opts: {
  env: ApnsEnv;
  pushToken: string;
  contentState: ContentState;
  event: "update" | "end";
  staleAfterSeconds?: number;
  dismissAfterSeconds?: number;
}): Promise<ApnsResult> {
  const now = Math.floor(Date.now() / 1000);
  const payload: {
    aps: {
      timestamp: number;
      event: "update" | "end";
      "content-state": ContentState;
      "stale-date"?: number;
      "dismissal-date"?: number;
    };
  } = {
    aps: {
      timestamp: now,
      event: opts.event,
      "content-state": opts.contentState,
    },
  };
  if (opts.staleAfterSeconds) payload.aps["stale-date"] = now + opts.staleAfterSeconds;
  if (opts.dismissAfterSeconds && opts.event === "end") {
    payload.aps["dismissal-date"] = now + opts.dismissAfterSeconds;
  }

  const jwt = await getProviderJwt(opts.env);
  const url = `https://${opts.env.APNS_HOST}/3/device/${opts.pushToken}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": `${opts.env.APNS_BUNDLE_ID}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (res.ok) return { ok: true, status: res.status };

  // APNs returns errors as JSON: { "reason": "BadDeviceToken" }
  let reason: string | undefined;
  try {
    const errBody = (await res.json()) as { reason?: string };
    reason = errBody.reason;
  } catch {
    /* non-JSON body, ignore */
  }
  return { ok: false, status: res.status, reason };
}

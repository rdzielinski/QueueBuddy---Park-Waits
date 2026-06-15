// The parks are all in Orlando, so the board reads in park-local (Eastern) time
// regardless of where the visitor is.
const PARK_TZ = "America/New_York";

const timeFmt = new Intl.DateTimeFormat("en-US", {
  timeZone: PARK_TZ,
  hour: "numeric",
  minute: "2-digit",
});

const dateFmt = new Intl.DateTimeFormat("en-US", {
  timeZone: PARK_TZ,
  weekday: "short",
  month: "short",
  day: "numeric",
});

export function formatClock(d: Date): string {
  return timeFmt.format(d);
}

export function formatBoardDate(d: Date): string {
  return dateFmt.format(d);
}

/** "Updated 2m ago" style relative time from an ISO string. */
export function relativeTime(iso: string | undefined, now: number = Date.now()): string | null {
  if (!iso) return null;
  const then = Date.parse(iso);
  if (Number.isNaN(then)) return null;
  const secs = Math.round((now - then) / 1000);
  if (secs < 30) return "just now";
  if (secs < 90) return "1m ago";
  if (secs < 3600) return `${Math.round(secs / 60)}m ago`;
  if (secs < 5400) return "1h ago";
  return `${Math.round(secs / 3600)}h ago`;
}

/**
 * Shared types between the worker and the iOS app. Whenever you change
 * one of these, the matching Swift struct in InLineActivity.swift (and
 * the widget mirror in QueueBuddyWidget/InLineLiveActivity.swift) must
 * change in lockstep — ActivityKit decodes the APNs `content-state` JSON
 * directly into the Codable struct, so any field-name drift causes the
 * Live Activity to silently fail to update.
 */

/**
 * Content state pushed to the Live Activity on each update. The shape
 * must exactly match `InLineAttributes.ContentState` on the iOS side,
 * including field names and JSON value types. Dates travel as UNIX
 * seconds (Double) — Swift's default `Date` Codable encoding is
 * reference-since-2001 which is awkward server-side.
 */
export interface ContentState {
  attractionName: string;
  parkAccentHex: number;
  currentWait: number | null;
  startedAt: number; // UNIX seconds
  lastUpdatedAt: number; // UNIX seconds
}

/** One active Live Activity that the worker should keep updated. */
export interface RegisteredActivity {
  attractionId: number;
  parkUUID: string; // ThemeParks.wiki park id, supplied by the iOS app at register
  pushToken: string;
  activityId: string;
  attractionName: string;
  parkAccentHex: number;
  startedAt: number; // UNIX seconds
}

/** Last sample we pushed; used to suppress redundant pushes. */
export interface LastWaitSample {
  wait: number | null;
  status: string;
  fetchedAt: number; // UNIX seconds
}

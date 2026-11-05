/**
 * Pure decisions for the engagement push scheduler (scheduleEngagement). The
 * Cloud Function only does IO and calls these. One send slot per user: the
 * UTC hour before their computed active hour, so no timezone is needed to
 * find the slot. Unit-tested in test/engagement_policy.test.js.
 * See docs/features/engagement-notifications-plan.md §12.
 */
import { localDayKey, isStreakAlive } from "./local_day";

export type Notif = Record<string, unknown>;

export type EngagementType =
  | "dc_streak_risk"
  | "lb_milestone"
  | "dc_today_ready"
  | "re_engage";

const DAY_MS = 86400000;
/** Whole lapsed days on which the comeback push may fire. */
export const RE_ENGAGE_LAPSE_DAYS = [2, 5, 14];
/** Comeback pushes allowed per lapse (a lapse ends when the user is active). */
export const RE_ENGAGE_MAX_PER_LAPSE = RE_ENGAGE_LAPSE_DAYS.length;
/** No server streak-saver before this local hour (device reminder covers it). */
const STREAK_EARLIEST_LOCAL_HOUR = 8;
const MILESTONES = [3, 7, 14, 30, 50, 100, 200, 365];

/** The UTC hour a user's push is sent: one hour before their active hour. */
export function sendHourUtc(activeHourUtc: number): number {
  return (((activeHourUtc - 1) % 24) + 24) % 24;
}

/** Local hour for a UTC hour at a zone offset (minutes east of UTC). */
export function localHour(utcHour: number, tzOffsetMinutes: number): number {
  const h = Math.floor((utcHour * 60 + tzOffsetMinutes) / 60) % 24;
  return h < 0 ? h + 24 : h;
}

/** ~10% stable holdout (matches the client hash intent) — measures true lift. */
export function isHoldout(uid: string): boolean {
  let h = 0;
  for (let i = 0; i < uid.length; i++) h = (h * 31 + uid.charCodeAt(i)) >>> 0;
  return h % 10 === 0;
}

export interface Slot {
  /** True when this run should evaluate the user at all. */
  evaluate: boolean;
  forced: boolean;
  /** False when the device never reported an offset. */
  tzKnown: boolean;
  /** Local calendar day (UTC day when the offset is unknown). */
  today: string;
  /** Local hour; the UTC hour when the offset is unknown. */
  localNow: number;
  scheduledHourUtc: number;
}

/**
 * Gate + clock for one user. `debugForceSend` bypasses the holdout and the
 * send-hour window (not the master switch).
 */
export function resolveSlot(uid: string, notif: Notif, nowMs: number): Slot {
  const utcHourNow = new Date(nowMs).getUTCHours();
  const tzRaw = notif.tzOffsetMinutes;
  const tzKnown = tzRaw != null && Number.isFinite(Number(tzRaw));
  const tz = tzKnown ? Number(tzRaw) : 0;
  const scheduledHourUtc = sendHourUtc(Number(notif.activeHourUtc));
  const forced = notif.debugForceSend === true;
  const eligible = notif.master !== false && (forced || !isHoldout(uid));
  const inWindow = Number.isFinite(scheduledHourUtc) && scheduledHourUtc === utcHourNow;
  return {
    evaluate: eligible && (forced || inWindow),
    forced,
    tzKnown,
    today: localDayKey(nowMs, tz),
    localNow: localHour(utcHourNow, tz),
    scheduledHourUtc,
  };
}

/** Quiet hours need a known timezone: unknown means never quiet. */
export function isQuietNow(notif: Notif, slot: Slot): boolean {
  if (!slot.tzKnown) return false;
  const qStart = Number(notif.quietStartLocal ?? 22);
  const qEnd = Number(notif.quietEndLocal ?? 8);
  if (qStart === qEnd) return false;
  return qStart < qEnd
    ? slot.localNow >= qStart && slot.localNow < qEnd
    : slot.localNow >= qStart || slot.localNow < qEnd;
}

/** Whole days since the user was last active; null when never recorded. */
export function lapsedWholeDays(lastActiveMs: number | null, nowMs: number): number | null {
  if (lastActiveMs == null) return null;
  return Math.max(0, Math.floor((nowMs - lastActiveMs) / DAY_MS));
}

/** Comeback ladder: exact lapse day, and the lapse's 3-push quota not used up. */
export function reEngageDue(lapsedDays: number | null, sentInLapse: number): boolean {
  return (
    lapsedDays != null &&
    RE_ENGAGE_LAPSE_DAYS.includes(lapsedDays) &&
    sentInLapse < RE_ENGAGE_MAX_PER_LAPSE
  );
}

/** Minimal shape of a notification_events doc for the daily-limit check. */
export interface EventLike {
  cancelled?: unknown;
  source?: unknown;
  type?: unknown;
}

/** Admin campaigns and test sends are not part of the daily engagement budget. */
function isAdminEvent(e: { source?: unknown; type?: unknown }): boolean {
  return e.source === "admin" || e.type === "admin_campaign";
}

/** Any live engagement event for the day (device or server) uses the day's push. */
export function dayLimitReached(eventsToday: EventLike[]): boolean {
  return eventsToday.some((e) => e.cancelled !== true && !isAdminEvent(e));
}

export interface ReconcileCandidate extends EventLike {
  playedAt?: unknown;
  category?: unknown;
  sentMs: number;
}

/**
 * Which event a new leaderboard entry should be credited to: the newest
 * server push already sent. Device events self-reconcile on-device, future
 * ones have not fired yet, offers and admin campaigns are not engagement
 * pushes. Input is newest first; returns the index or -1.
 */
export function pickReconcileTarget(events: ReconcileCandidate[], nowMs: number): number {
  return events.findIndex(
    (e) =>
      !e.playedAt &&
      e.cancelled !== true &&
      e.sentMs > 0 &&
      e.sentMs <= nowMs &&
      e.source !== "device" &&
      e.category !== "offer" &&
      !isAdminEvent(e)
  );
}

export type FlagMode = "on" | "admin_only" | "off";

/** Mirrors FeatureFlagService._decode (legacy bools included). */
export function decodeFlagMode(v: unknown, fallback: FlagMode = "admin_only"): FlagMode {
  if (v === "on" || v === true) return "on";
  if (v === "off" || v === false) return "off";
  if (v === "admin_only") return "admin_only";
  return fallback;
}

/** Whether a flag value lets this user in (missing = admin-only, the app default). */
export function flagAllows(v: unknown, isAdmin: boolean): boolean {
  const mode = decodeFlagMode(v);
  return mode === "on" || (mode === "admin_only" && isAdmin);
}

/** Types that are Daily Challenge pushes and need `daily_challenge` too. */
export function needsDailyChallengeFlag(type: EngagementType): boolean {
  return type !== "re_engage";
}

/** Ms of a re_engage event's sentAt, for lapse membership. */
export function sentInLapseCount(sentAtMs: (number | null)[], lastActiveMs: number | null): number {
  if (lastActiveMs == null) return 0;
  return sentAtMs.filter((t) => t != null && t >= lastActiveMs).length;
}

export interface TypeInput {
  notif: Notif;
  slot: Slot;
  quiet: boolean;
  lastDayKey: string;
  streakRaw: number;
  bestStreak: number;
  lapsedDays: number | null;
  reEngageSentInLapse: number;
}

export interface TypeDecision {
  type: EngagementType | null;
  /** Streak as the push copy should show it (a dead streak counts as 0). */
  currentStreak: number;
}

/** Priority: streak-saver > milestone > today-ready > comeback. */
export function chooseType(i: TypeInput): TypeDecision {
  const { notif, slot, quiet, lapsedDays } = i;
  const alive = isStreakAlive(i.lastDayKey, slot.today);
  const currentStreak = alive ? i.streakRaw : 0;
  const playedToday = i.lastDayKey === slot.today;
  const milestone =
    playedToday && MILESTONES.includes(currentStreak) && currentStreak === i.bestStreak;
  const pick = (type: EngagementType | null): TypeDecision => ({ type, currentStreak });

  if (slot.forced) return pick("dc_today_ready");
  // Streak-saver is exempt from quiet hours (22-23 can still save the day),
  // but not in the small hours: skip the run, no other type takes its place.
  if (notif.streak !== false && currentStreak >= 1 && !playedToday) {
    return pick(slot.tzKnown && slot.localNow < STREAK_EARLIEST_LOCAL_HOUR ? null : "dc_streak_risk");
  }
  if (quiet) return pick(null);
  if (notif.leaderboard !== false && milestone) return pick("lb_milestone");
  if (notif.leaderboard !== false && !playedToday && lapsedDays != null && lapsedDays < 2) {
    return pick("dc_today_ready");
  }
  if (notif.reengage !== false && reEngageDue(lapsedDays, i.reEngageSentInLapse)) {
    return pick("re_engage");
  }
  return pick(null);
}

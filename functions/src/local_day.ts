/**
 * Pure local-calendar-day math for the engagement scheduler. The client
 * writes leaderboard_streak.lastDayKey as the user's LOCAL yyyy-MM-dd
 * (DailyChallengeStore.dayKey), so the server must compare against the
 * user's local day, not the UTC day. Shift by the offset, then read the
 * UTC Y-M-D — no DST handling needed (the offset is the user's current one).
 * Unit-tested in test/local_day.test.js.
 */
const MIN_MS = 60 * 1000;

/** yyyy-MM-dd at `nowMs` for a zone `tzOffsetMinutes` east of UTC.
 *  Missing / non-finite offset falls back to UTC. */
export function localDayKey(nowMs: number, tzOffsetMinutes?: number | null): string {
  const off = Number.isFinite(tzOffsetMinutes) ? (tzOffsetMinutes as number) : 0;
  return new Date(nowMs + off * MIN_MS).toISOString().slice(0, 10);
}

/** The calendar day before a yyyy-MM-dd key (pure date math, UTC-based). */
export function previousDayKey(key: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(key);
  if (!m) return "";
  const t = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return new Date(t - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

/** A streak is alive only if last played today or yesterday (local days). */
export function isStreakAlive(lastDayKey: string, today: string): boolean {
  return lastDayKey !== "" && (lastDayKey === today || lastDayKey === previousDayKey(today));
}

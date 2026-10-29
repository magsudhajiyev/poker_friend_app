/**
 * Pure logic for the nightly stale-streak expiry. A leaderboard_streak row is
 * stale when its lastDayKey (the player's LOCAL day) is older than the
 * cutoff and its currentStreak is still > 0. The cutoff is UTC today - 2
 * days, so even UTC+14 / UTC-12 players cannot still be "yesterday".
 * Unit-tested in test/streak_expiry.test.js.
 */
const DAY_MS = 24 * 60 * 60 * 1000;

/** yyyy-MM-dd of (UTC today - 2 days). Rows with lastDayKey < this are stale. */
export function staleCutoffKey(nowMs: number): string {
  return new Date(nowMs - 2 * DAY_MS).toISOString().slice(0, 10);
}

export interface StreakRowLike {
  lastDayKey?: unknown;
  currentStreak?: unknown;
}

/** True when the row must be zeroed. Malformed keys are left alone. */
export function isStaleStreakRow(row: StreakRowLike, cutoff: string): boolean {
  const key = row.lastDayKey;
  const cur = row.currentStreak;
  return typeof key === "string"
    && /^\d{4}-\d{2}-\d{2}$/.test(key)
    && key < cutoff
    && typeof cur === "number"
    && cur > 0;
}

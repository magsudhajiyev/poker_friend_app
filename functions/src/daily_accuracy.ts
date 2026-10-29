/**
 * Daily Challenge day accuracy — the leaderboard score authority used by
 * validateLeaderboardEntry. Pure — unit-tested in test/daily_accuracy.test.js.
 *
 * Scoring mirrors the client's DailyScoring (lib/services/daily_scoring.dart)
 * — keep both in sync: score = day ACCURACY % (0..100, one decimal).
 *   decision c=1 / o=0.5 / else 0; hands are '|'-separated (no '|' = one
 *   hand); hand accuracy = pot-weighted mean
 *   (weights[] aligned with the letters, floored at 1, capped at
 *   DAILY_MAX_WEIGHT, missing / non-finite → 1); day = plain mean of hand
 *   accuracies. scoreKey = accuracy ×10; perfect = every letter 'c'.
 *   Shared parity cases: test/fixtures/daily_scoring_cases.json (repo root).
 */
export const DAILY_MAX_WEIGHT = 1000;

export function dailyAccuracy(verdicts: string, weights: unknown): number {
  const w: number[] = Array.isArray(weights) ?
    weights.map((x) => (typeof x === "number" ? x : 1)) :
    [];
  // No '|' = ONE hand (single-hand day or legacy RNG run).
  const hands = verdicts.length === 0 ? [] : verdicts.split("|");
  if (hands.length === 0) return 0;
  let offset = 0;
  let sumAcc = 0;
  for (const hand of hands) {
    let sum = 0;
    let total = 0;
    for (let i = 0; i < hand.length; i++) {
      const raw = offset + i < w.length ? w[offset + i] : 1;
      // A forged NaN/Infinity weight must never reach the score (it would
      // turn the day into NaN): non-finite → 1; huge finite → capped.
      const weight = Number.isFinite(raw) && raw > 1 ?
        Math.min(raw, DAILY_MAX_WEIGHT) : 1;
      const ch = hand[i];
      sum += (ch === "c" ? 1 : ch === "o" ? 0.5 : 0) * weight;
      total += weight;
    }
    sumAcc += hand.length > 0 ? sum / total : 0;
    offset += hand.length;
  }
  return Math.round((sumAcc / hands.length) * 1000) / 10;
}

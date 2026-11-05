/**
 * Pure helpers for syncSubscription (the web dashboard's login-time plan
 * check). No Firebase imports — unit-tested in test/subscription_sync.test.js.
 */
import type { SubscriptionMirror } from "./subscription_mirror";

/** Origins allowed to call syncSubscription from a browser. */
export const SYNC_ALLOWED_ORIGINS = [
  "https://finaltable.io",
  "https://www.finaltable.io",
  "http://localhost:5173",
];

/** Re-sync at most this often per user; newer saved values are returned as-is. */
export const SYNC_MIN_INTERVAL_MS = 60 * 1000;

export function allowedOrigin(origin: unknown): string | null {
  return typeof origin === "string" && SYNC_ALLOWED_ORIGINS.includes(origin) ? origin : null;
}

/** True when the saved mirror is fresh enough to skip the RevenueCat call. */
export function isFreshSync(syncedAtMs: number | null, nowMs: number): boolean {
  return syncedAtMs != null && nowMs - syncedAtMs >= 0 && nowMs - syncedAtMs < SYNC_MIN_INTERVAL_MS;
}

export interface SyncResponse {
  tier: SubscriptionMirror["tier"];
  expiresAtMs: number | null;
  inTrial: boolean;
}

export function responseFromMirror(m: SubscriptionMirror): SyncResponse {
  return { tier: m.tier, expiresAtMs: m.expiresAtMs, inTrial: m.inTrial };
}

const TIERS = ["free", "pro", "elite", "club"];

/** Rebuilds a response from the saved users/{uid} fields; null if unusable. */
export function responseFromSaved(
  tier: unknown,
  expiresAtMs: number | null,
  inTrial: unknown
): SyncResponse | null {
  if (typeof tier !== "string" || !TIERS.includes(tier)) return null;
  return { tier: tier as SyncResponse["tier"], expiresAtMs, inTrial: inTrial === true };
}

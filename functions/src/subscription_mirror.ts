/**
 * Pure mapping RevenueCat REST subscriber → the fields revenuecatWebhook
 * mirrors onto users/{uid}. No Firebase imports, so it is unit-testable
 * (test/subscription_mirror.test.js).
 *
 * Tier: highest ACTIVE entitlement (club > elite > pro), expires_date null =
 * lifetime. Trial state comes from that entitlement's product in
 * `subscriptions` (period_type "trial"); it renews unless the store reported a
 * cancellation (unsubscribe_detected_at) or it is a promotional grant (those
 * never renew).
 */
export interface SubscriptionMirror {
  tier: "free" | "pro" | "elite" | "club";
  /** Null when free. Lifetime grants map to now + 100 years. */
  expiresAtMs: number | null;
  inTrial: boolean;
  willRenew: boolean;
  productId: string | null;
}

interface RcEntitlement {
  expires_date: string | null;
  product_identifier?: string;
}

interface RcSubscription {
  period_type?: string;
  unsubscribe_detected_at?: string | null;
  store?: string;
}

const LIFETIME_MS = 100 * 365 * 24 * 3600 * 1000;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function mirrorFromSubscriber(subscriber: any, now: number): SubscriptionMirror {
  const entitlements: Record<string, RcEntitlement> = subscriber?.entitlements ?? {};
  const subscriptions: Record<string, RcSubscription> = subscriber?.subscriptions ?? {};

  const isActive = (id: string): boolean => {
    const e = entitlements[id];
    if (!e) return false;
    return e.expires_date === null || Date.parse(e.expires_date) > now;
  };
  const tier = isActive("club") ? "club"
    : isActive("elite") ? "elite"
    : isActive("pro") ? "pro"
    : "free";

  if (tier === "free") {
    return { tier, expiresAtMs: null, inTrial: false, willRenew: false, productId: null };
  }

  const ent = entitlements[tier];
  const expiresAtMs = ent.expires_date === null
    ? now + LIFETIME_MS
    : Date.parse(ent.expires_date);
  const productId = ent.product_identifier ?? null;
  const sub = productId ? subscriptions[productId] : undefined;
  const promotional = sub?.store === "promotional";
  return {
    tier,
    expiresAtMs,
    inTrial: sub?.period_type === "trial",
    willRenew: !!sub && !promotional && !sub.unsubscribe_detected_at,
    productId,
  };
}

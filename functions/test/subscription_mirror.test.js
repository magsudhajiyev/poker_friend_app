// Run: npm test  (builds, then node --test). Tests the compiled module.
const test = require("node:test");
const assert = require("node:assert/strict");
const { mirrorFromSubscriber } = require("../lib/subscription_mirror.js");

const NOW = Date.parse("2026-10-22T12:00:00Z");
const IN_7D = "2026-10-29T12:00:00Z";
const PAST = "2026-10-01T00:00:00Z";

test("no entitlements → free, nothing else set", () => {
  assert.deepEqual(mirrorFromSubscriber({}, NOW), {
    tier: "free", expiresAtMs: null, inTrial: false, willRenew: false, productId: null,
  });
  assert.equal(mirrorFromSubscriber(undefined, NOW).tier, "free");
});

test("monthly trial on elite → in trial, renews, product + end date", () => {
  const m = mirrorFromSubscriber({
    entitlements: {
      pro: { expires_date: IN_7D, product_identifier: "elite_monthly" },
      elite: { expires_date: IN_7D, product_identifier: "elite_monthly" },
    },
    subscriptions: {
      elite_monthly: { period_type: "trial", unsubscribe_detected_at: null, store: "app_store" },
    },
  }, NOW);
  assert.equal(m.tier, "elite");
  assert.equal(m.inTrial, true);
  assert.equal(m.willRenew, true);
  assert.equal(m.productId, "elite_monthly");
  assert.equal(m.expiresAtMs, Date.parse(IN_7D));
});

test("cancelled during the trial → still in trial, will not renew", () => {
  const m = mirrorFromSubscriber({
    entitlements: { pro: { expires_date: IN_7D, product_identifier: "pro_annual" } },
    subscriptions: {
      pro_annual: { period_type: "trial", unsubscribe_detected_at: "2026-10-23T09:00:00Z" },
    },
  }, NOW);
  assert.equal(m.inTrial, true);
  assert.equal(m.willRenew, false);
});

test("converted to paid → not in trial", () => {
  const m = mirrorFromSubscriber({
    entitlements: { pro: { expires_date: IN_7D, product_identifier: "pro_monthly" } },
    subscriptions: { pro_monthly: { period_type: "normal" } },
  }, NOW);
  assert.equal(m.inTrial, false);
  assert.equal(m.willRenew, true);
});

test("promotional grant (free month) never renews", () => {
  const m = mirrorFromSubscriber({
    entitlements: { pro: { expires_date: IN_7D, product_identifier: "rc_promo_pro_monthly" } },
    subscriptions: { rc_promo_pro_monthly: { period_type: "normal", store: "promotional" } },
  }, NOW);
  assert.equal(m.tier, "pro");
  assert.equal(m.willRenew, false);
  assert.equal(m.inTrial, false);
});

test("expired entitlements are ignored; highest active tier wins", () => {
  const m = mirrorFromSubscriber({
    entitlements: {
      club: { expires_date: PAST, product_identifier: "club_monthly" },
      pro: { expires_date: IN_7D, product_identifier: "pro_monthly" },
    },
    subscriptions: { pro_monthly: { period_type: "normal" } },
  }, NOW);
  assert.equal(m.tier, "pro");
  assert.equal(m.productId, "pro_monthly");
});

test("lifetime (expires_date null) → far-future expiry", () => {
  const m = mirrorFromSubscriber({
    entitlements: { pro: { expires_date: null, product_identifier: "x" } },
  }, NOW);
  assert.equal(m.tier, "pro");
  assert.ok(m.expiresAtMs > NOW + 50 * 365 * 24 * 3600 * 1000);
  assert.equal(m.willRenew, false); // no subscription record
});

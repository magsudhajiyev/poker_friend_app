const test = require("node:test");
const assert = require("node:assert/strict");
const S = require("../lib/subscription_sync.js");

test("allowedOrigin accepts only the allow-list", () => {
  assert.equal(S.allowedOrigin("https://finaltable.io"), "https://finaltable.io");
  assert.equal(S.allowedOrigin("https://www.finaltable.io"), "https://www.finaltable.io");
  assert.equal(S.allowedOrigin("http://localhost:5173"), "http://localhost:5173");
  assert.equal(S.allowedOrigin("https://evil.com"), null);
  assert.equal(S.allowedOrigin("https://finaltable.io.evil.com"), null);
  assert.equal(S.allowedOrigin(undefined), null);
});

test("isFreshSync: under 60 s is fresh, otherwise not", () => {
  const now = 1_000_000;
  assert.equal(S.isFreshSync(now - 59_999, now), true);
  assert.equal(S.isFreshSync(now - 60_000, now), false);
  assert.equal(S.isFreshSync(null, now), false);
  assert.equal(S.isFreshSync(now + 5000, now), false);
});

test("responseFromMirror returns only tier, expiry, trial", () => {
  const r = S.responseFromMirror({ tier: "pro", expiresAtMs: 5, inTrial: true, willRenew: true, productId: "x" });
  assert.deepEqual(r, { tier: "pro", expiresAtMs: 5, inTrial: true });
});

test("responseFromSaved validates the tier and coerces inTrial", () => {
  assert.deepEqual(S.responseFromSaved("elite", 9, undefined), { tier: "elite", expiresAtMs: 9, inTrial: false });
  assert.equal(S.responseFromSaved(undefined, null, false), null);
  assert.equal(S.responseFromSaved("gold", null, false), null);
});

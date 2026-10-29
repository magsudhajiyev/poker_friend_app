const test = require("node:test");
const assert = require("node:assert/strict");
const { staleCutoffKey, isStaleStreakRow } = require("../lib/streak_expiry.js");

const at = (iso) => Date.parse(iso);

test("cutoff is UTC today minus 2 days", () => {
  assert.equal(staleCutoffKey(at("2026-10-29T06:00:00Z")), "2026-10-27");
});

test("cutoff crosses month boundary", () => {
  assert.equal(staleCutoffKey(at("2026-11-01T00:00:00Z")), "2026-10-30");
});

test("row older than cutoff with streak is stale", () => {
  assert.equal(isStaleStreakRow({ lastDayKey: "2026-10-26", currentStreak: 5 }, "2026-10-27"), true);
});

test("row equal to cutoff is kept (a UTC+14 player may still be alive)", () => {
  assert.equal(isStaleStreakRow({ lastDayKey: "2026-10-27", currentStreak: 5 }, "2026-10-27"), false);
});

test("already zero is not selected", () => {
  assert.equal(isStaleStreakRow({ lastDayKey: "2026-10-01", currentStreak: 0 }, "2026-10-27"), false);
});

test("malformed or missing fields are skipped", () => {
  assert.equal(isStaleStreakRow({ lastDayKey: "", currentStreak: 3 }, "2026-10-27"), false);
  assert.equal(isStaleStreakRow({ lastDayKey: "abc", currentStreak: 3 }, "2026-10-27"), false);
  assert.equal(isStaleStreakRow({ currentStreak: 3 }, "2026-10-27"), false);
  assert.equal(isStaleStreakRow({ lastDayKey: "2026-10-01" }, "2026-10-27"), false);
});

test("selection over rows sharing one lastDayKey keeps every stale row", () => {
  const rows = Array.from({ length: 5 }, (_, i) => ({ lastDayKey: "2026-10-20", currentStreak: i }));
  const stale = rows.filter((r) => isStaleStreakRow(r, "2026-10-27"));
  assert.equal(stale.length, 4);
});

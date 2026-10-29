const test = require("node:test");
const assert = require("node:assert/strict");
const { localDayKey } = require("../lib/local_day.js");

const at = (iso) => Date.parse(iso);

test("UTC-5 at 23:30 local is still the same local day (UTC already next day)", () => {
  // 23:30 local on Oct 28 == 04:30 UTC on Oct 29
  assert.equal(localDayKey(at("2026-10-29T04:30:00Z"), -300), "2026-10-28");
});

test("UTC-5 just after local midnight rolls to the new local day", () => {
  assert.equal(localDayKey(at("2026-10-29T05:00:00Z"), -300), "2026-10-29");
});

test("UTC+14 is a day ahead of UTC late in the UTC day", () => {
  assert.equal(localDayKey(at("2026-10-28T12:00:00Z"), 840), "2026-10-29");
});

test("UTC-12 is a day behind UTC early in the UTC day", () => {
  assert.equal(localDayKey(at("2026-10-29T11:59:00Z"), -720), "2026-10-28");
});

test("offset 0 equals the UTC date", () => {
  assert.equal(localDayKey(at("2026-10-29T23:59:00Z"), 0), "2026-10-29");
});

test("missing offset falls back to UTC", () => {
  const t = at("2026-10-29T01:00:00Z");
  assert.equal(localDayKey(t, undefined), "2026-10-29");
  assert.equal(localDayKey(t, null), "2026-10-29");
  assert.equal(localDayKey(t, NaN), "2026-10-29");
});

test("month and year rollover", () => {
  assert.equal(localDayKey(at("2026-12-31T20:00:00Z"), 300), "2027-01-01");
  assert.equal(localDayKey(at("2027-03-01T01:00:00Z"), -120), "2027-02-28");
});

const { previousDayKey, isStreakAlive } = require("../lib/local_day.js");

test("previousDayKey crosses month, year and leap day", () => {
  assert.equal(previousDayKey("2026-11-01"), "2026-10-31");
  assert.equal(previousDayKey("2027-01-01"), "2026-12-31");
  assert.equal(previousDayKey("2028-03-01"), "2028-02-29");
  assert.equal(previousDayKey("garbage"), "");
});

test("isStreakAlive: today and yesterday alive, older or empty dead", () => {
  assert.equal(isStreakAlive("2026-10-29", "2026-10-29"), true);
  assert.equal(isStreakAlive("2026-10-28", "2026-10-29"), true);
  assert.equal(isStreakAlive("2026-10-27", "2026-10-29"), false);
  assert.equal(isStreakAlive("", "2026-10-29"), false);
});

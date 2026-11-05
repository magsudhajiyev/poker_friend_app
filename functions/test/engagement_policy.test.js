const test = require("node:test");
const assert = require("node:assert/strict");
const P = require("../lib/engagement_policy.js");

const at = (iso) => Date.parse(iso);
const DAY = 86400000;

// Finds a uid that is not in the 10% holdout (and one that is).
const inUid = (() => { for (let i = 0; ; i++) if (!P.isHoldout("u" + i)) return "u" + i; })();
const heldUid = (() => { for (let i = 0; ; i++) if (P.isHoldout("u" + i)) return "u" + i; })();

test("sendHourUtc is activeHour - 1, wrapping at midnight", () => {
  assert.equal(P.sendHourUtc(19), 18);
  assert.equal(P.sendHourUtc(0), 23);
});

test("resolveSlot evaluates only in the send hour", () => {
  const notif = { activeHourUtc: 19 };
  assert.equal(P.resolveSlot(inUid, notif, at("2026-11-05T18:10:00Z")).evaluate, true);
  assert.equal(P.resolveSlot(inUid, notif, at("2026-11-05T10:00:00Z")).evaluate, false);
  assert.equal(P.resolveSlot(inUid, notif, at("2026-11-05T19:00:00Z")).evaluate, false);
});

test("resolveSlot skips holdout and master-off users", () => {
  const now = at("2026-11-05T18:00:00Z");
  assert.equal(P.resolveSlot(heldUid, { activeHourUtc: 19 }, now).evaluate, false);
  assert.equal(P.resolveSlot(inUid, { activeHourUtc: 19, master: false }, now).evaluate, false);
});

test("debugForceSend bypasses holdout and window, not master", () => {
  const now = at("2026-11-05T03:00:00Z");
  const s = P.resolveSlot(heldUid, { activeHourUtc: 19, debugForceSend: true }, now);
  assert.equal(s.evaluate, true);
  assert.equal(s.forced, true);
  assert.equal(P.resolveSlot(inUid, { activeHourUtc: 19, debugForceSend: true, master: false }, now).evaluate, false);
});

test("missing timezone: tzKnown false, UTC day key, never quiet", () => {
  const now = at("2026-11-05T23:30:00Z");
  const notif = { activeHourUtc: 0, quietStartLocal: 22, quietEndLocal: 8 };
  const s = P.resolveSlot(inUid, notif, now);
  assert.equal(s.tzKnown, false);
  assert.equal(s.today, "2026-11-05");
  assert.equal(P.isQuietNow(notif, s), false);
});

test("known timezone drives day key and quiet hours", () => {
  const now = at("2026-11-05T23:30:00Z");
  const notif = { activeHourUtc: 0, tzOffsetMinutes: 120 };
  const s = P.resolveSlot(inUid, notif, now);
  assert.equal(s.tzKnown, true);
  assert.equal(s.today, "2026-11-06");
  assert.equal(s.localNow, 1);
  assert.equal(P.isQuietNow(notif, s), true);
});

test("tzOffsetMinutes 0 is a known timezone", () => {
  assert.equal(P.resolveSlot(inUid, { activeHourUtc: 5, tzOffsetMinutes: 0 }, 0).tzKnown, true);
});

test("lapsedWholeDays floors and handles missing lastActiveAt", () => {
  const now = at("2026-11-05T12:00:00Z");
  assert.equal(P.lapsedWholeDays(now - 2 * DAY - 3600000, now), 2);
  assert.equal(P.lapsedWholeDays(now - 2 * DAY + 3600000, now), 1);
  assert.equal(P.lapsedWholeDays(null, now), null);
});

test("reEngageDue: only days 2, 5, 14 and at most 3 per lapse", () => {
  for (const d of [2, 5, 14]) assert.equal(P.reEngageDue(d, 0), true);
  for (const d of [0, 1, 3, 4, 6, 13, 15, 40]) assert.equal(P.reEngageDue(d, 0), false);
  assert.equal(P.reEngageDue(null, 0), false);
  assert.equal(P.reEngageDue(15, 2), false);
  assert.equal(P.reEngageDue(14, 3), false);
});

test("sentInLapseCount counts only events after lastActiveAt", () => {
  assert.equal(P.sentInLapseCount([100, 300, null], 200), 1);
  assert.equal(P.sentInLapseCount([100], null), 0);
});

test("dayLimitReached ignores cancelled events, counts device and server", () => {
  assert.equal(P.dayLimitReached([]), false);
  assert.equal(P.dayLimitReached([{ cancelled: true }]), false);
  assert.equal(P.dayLimitReached([{ cancelled: true }, { source: "device" }]), true);
  assert.equal(P.dayLimitReached([{ source: "server" }]), true);
});

const slot = (over = {}) => ({
  evaluate: true, forced: false, tzKnown: true, today: "2026-11-05",
  localNow: 18, scheduledHourUtc: 18, ...over,
});
const input = (over = {}) => ({
  notif: {}, slot: slot(), quiet: false, lastDayKey: "", streakRaw: 0,
  bestStreak: 0, lapsedDays: 0, reEngageSentInLapse: 0, ...over,
});

test("alive streak not played today -> dc_streak_risk, even in quiet hours", () => {
  const d = P.chooseType(input({ lastDayKey: "2026-11-04", streakRaw: 4, bestStreak: 9, quiet: true }));
  assert.equal(d.type, "dc_streak_risk");
  assert.equal(d.currentStreak, 4);
});

test("streak pref off drops streak-saver, falls to today-ready", () => {
  const d = P.chooseType(input({ notif: { streak: false }, lastDayKey: "2026-11-04", streakRaw: 4 }));
  assert.equal(d.type, "dc_today_ready");
});

test("played today on a milestone streak -> lb_milestone", () => {
  const d = P.chooseType(input({ lastDayKey: "2026-11-05", streakRaw: 7, bestStreak: 7 }));
  assert.equal(d.type, "lb_milestone");
});

test("milestone suppressed in quiet hours", () => {
  const d = P.chooseType(input({ lastDayKey: "2026-11-05", streakRaw: 7, bestStreak: 7, quiet: true }));
  assert.equal(d.type, null);
});

test("dead streak counts as 0 and gives today-ready when recently active", () => {
  const d = P.chooseType(input({ lastDayKey: "2026-11-01", streakRaw: 6, lapsedDays: 1 }));
  assert.equal(d.type, "dc_today_ready");
  assert.equal(d.currentStreak, 0);
});

test("unknown lastActiveAt never sends today-ready or re_engage", () => {
  assert.equal(P.chooseType(input({ lapsedDays: null })).type, null);
});

test("lapsed exactly 2 -> re_engage; 3 -> nothing", () => {
  assert.equal(P.chooseType(input({ lapsedDays: 2 })).type, "re_engage");
  assert.equal(P.chooseType(input({ lapsedDays: 3 })).type, null);
});

test("comeback ladder: day 2, 5, 14 fire with 0, 1, 2 prior; day 15 never", () => {
  const send = (d, n) => P.chooseType(input({ lapsedDays: d, reEngageSentInLapse: n })).type;
  assert.equal(send(2, 0), "re_engage");
  assert.equal(send(5, 1), "re_engage");
  assert.equal(send(14, 2), "re_engage");
  assert.equal(send(15, 3), null);
  assert.equal(send(15, 0), null);
});

test("3 or more comeback pushes this lapse -> no more", () => {
  for (const d of [2, 5, 14]) assert.equal(P.chooseType(input({ lapsedDays: d, reEngageSentInLapse: 3 })).type, null);
  assert.equal(P.chooseType(input({ lapsedDays: 14, reEngageSentInLapse: 4 })).type, null);
});

test("re_engage respects reengage pref and quiet hours", () => {
  assert.equal(P.chooseType(input({ lapsedDays: 2, notif: { reengage: false } })).type, null);
  assert.equal(P.chooseType(input({ lapsedDays: 2, quiet: true })).type, null);
});

test("forced send always yields dc_today_ready", () => {
  const d = P.chooseType(input({ slot: slot({ forced: true }), lapsedDays: null }));
  assert.equal(d.type, "dc_today_ready");
});

test("streak-saver by local hour: 0-7 skipped with no fallback, 8 and 22-23 fire", () => {
  const at = (h, tzKnown = true) => P.chooseType(input({
    slot: slot({ localNow: h, tzKnown }), lastDayKey: "2026-11-04", streakRaw: 4, bestStreak: 4,
    quiet: h >= 22 || h < 8, lapsedDays: 1,
  })).type;
  assert.equal(at(0), null);
  assert.equal(at(7), null);
  assert.equal(at(8), "dc_streak_risk");
  assert.equal(at(22), "dc_streak_risk");
  assert.equal(at(23), "dc_streak_risk");
});

test("streak-saver with unknown timezone keeps current behaviour", () => {
  const d = P.chooseType(input({
    slot: slot({ localNow: 3, tzKnown: false }), lastDayKey: "2026-11-04", streakRaw: 4,
  }));
  assert.equal(d.type, "dc_streak_risk");
});

test("dayLimitReached ignores admin campaign and test events", () => {
  assert.equal(P.dayLimitReached([{ source: "admin" }]), false);
  assert.equal(P.dayLimitReached([{ type: "admin_campaign", source: "server" }]), false);
  assert.equal(P.dayLimitReached([{ type: "admin_campaign" }, { source: "server" }]), true);
});

const NOW = at("2026-11-05T12:00:00Z");
const ev = (over = {}) => ({ sentMs: NOW - 60000, source: "server", ...over });

test("reconcile skips future, device, offer and admin events, picks newest server push", () => {
  const events = [
    ev({ sentMs: NOW + 3600000, source: "device" }),
    ev({ sentMs: NOW + 1000 }),
    ev({ source: "device" }),
    ev({ category: "offer" }),
    ev({ type: "admin_campaign" }),
    ev({ source: "admin" }),
    ev({ playedAt: {} }),
    ev({ cancelled: true }),
    ev({ sentMs: NOW - 3 * 3600000 }),
  ];
  assert.equal(P.pickReconcileTarget(events, NOW), 8);
});

test("reconcile picks the first eligible and returns -1 when none", () => {
  assert.equal(P.pickReconcileTarget([ev(), ev()], NOW), 0);
  assert.equal(P.pickReconcileTarget([ev({ source: "device" })], NOW), -1);
  assert.equal(P.pickReconcileTarget([], NOW), -1);
});

test("flag modes: on = all, admin_only/missing = admins, off = none", () => {
  assert.equal(P.flagAllows("on", false), true);
  assert.equal(P.flagAllows(true, false), true);
  assert.equal(P.flagAllows("admin_only", false), false);
  assert.equal(P.flagAllows("admin_only", true), true);
  assert.equal(P.flagAllows(undefined, false), false);
  assert.equal(P.flagAllows(undefined, true), true);
  assert.equal(P.flagAllows("off", true), false);
  assert.equal(P.flagAllows(false, true), false);
});

test("daily_challenge flag applies to all types except re_engage", () => {
  for (const t of ["dc_streak_risk", "dc_today_ready", "lb_milestone"]) assert.equal(P.needsDailyChallengeFlag(t), true);
  assert.equal(P.needsDailyChallengeFlag("re_engage"), false);
});

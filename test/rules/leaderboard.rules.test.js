const { test, before, after, beforeEach } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc, updateDoc, deleteDoc } = require("firebase/firestore");

const PROJECT = "demo-rules-test";
const ADMIN_EMAIL = "magsud94@gmail.com";
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});
after(async () => env && env.cleanup());
beforeEach(async () => env.clearFirestore());

const iso = (offsetDays) =>
  new Date(Date.now() + offsetDays * 86400000).toISOString().slice(0, 10);
const TODAY = iso(0);
const userDb = (uid) => env.authenticatedContext(uid).firestore();
const adminDb = () =>
  env.authenticatedContext("admin1", { email: ADMIN_EMAIL, email_verified: true }).firestore();
const entry = (uid, over = {}) => ({
  uid, username: "Alice", verdicts: "ccoc|cc", score: 80, scoreKey: 800,
  perfect: false, durationMs: 60000, ...over,
});
const ref = (db, day, uid) => doc(db, `leaderboard_daily/${day}/entries/${uid}`);
const create = (uid, data, day = TODAY, as = uid) => setDoc(ref(userDb(as), day, uid), data);

test("owner creates valid entry", () => assertSucceeds(create("u1", entry("u1"))));
test("valid entry with weights", () =>
  assertSucceeds(create("u1", entry("u1", { weights: [1, 2, 3.5] }))));
test("create for another uid denied", () => assertFails(create("u2", entry("u2"), TODAY, "u1")));
test("body uid mismatch denied", () => assertFails(create("u1", entry("u2"))));
test("short username denied", () => assertFails(create("u1", entry("u1", { username: "ab" }))));

test("owner update denied", async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(ref(c.firestore(), TODAY, "u1"), entry("u1")));
  await assertFails(updateDoc(ref(userDb("u1"), TODAY, "u1"), { score: 100 }));
});
test("owner delete denied, admin delete allowed", async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(ref(c.firestore(), TODAY, "u1"), entry("u1")));
  await assertFails(deleteDoc(ref(userDb("u1"), TODAY, "u1")));
  await assertSucceeds(deleteDoc(ref(adminDb(), TODAY, "u1")));
});
test("admin with unverified email cannot delete", async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(ref(c.firestore(), TODAY, "u1"), entry("u1")));
  const db = env.authenticatedContext("a2", { email: ADMIN_EMAIL, email_verified: false }).firestore();
  await assertFails(deleteDoc(ref(db, TODAY, "u1")));
});

for (const [name, day] of [
  ["3 days past", iso(-3)], ["3 days future", iso(3)],
  ["month 13", "2026-13-45"], ["garbage", "abc"],
]) {
  test(`dayKey ${name} denied`, () => assertFails(create("u1", entry("u1"), day)));
}

for (const d of [0, 999, 86400001, 5000.5]) {
  test(`durationMs ${d} denied`, () => assertFails(create("u1", entry("u1", { durationMs: d }))));
}
test("durationMs bounds 1000 and 86400000 allowed", async () => {
  await assertSucceeds(create("u1", entry("u1", { durationMs: 1000 })));
  await assertSucceeds(create("u2", entry("u2", { durationMs: 86400000 })));
});

test("verdicts with x denied", () => assertFails(create("u1", entry("u1", { verdicts: "ccx" }))));
test("verdicts length 61 denied", () =>
  assertFails(create("u1", entry("u1", { verdicts: "c".repeat(61) }))));
test("verdicts length 60 allowed", () =>
  assertSucceeds(create("u1", entry("u1", { verdicts: "c".repeat(60) }))));
test("empty verdicts denied", () => assertFails(create("u1", entry("u1", { verdicts: "" }))));
test("weights length 51 denied", () =>
  assertFails(create("u1", entry("u1", { weights: new Array(51).fill(1) }))));
test("weights length 50 allowed", () =>
  assertSucceeds(create("u1", entry("u1", { weights: new Array(50).fill(1) }))));
test("scoreKey double denied", () => assertFails(create("u1", entry("u1", { scoreKey: 800.5 }))));
test("perfect non-bool denied", () => assertFails(create("u1", entry("u1", { perfect: "yes" }))));
test("unauthenticated create denied", () =>
  assertFails(setDoc(ref(env.unauthenticatedContext().firestore(), TODAY, "u1"), entry("u1"))));

const streak = (uid, over = {}) => ({
  uid, username: "Alice", currentStreak: 3, bestStreak: 5, perfectDays: 1,
  totalPlayed: 8, lastDayKey: TODAY, updatedAt: new Date(), ...over,
});
const sref = (db, uid) => doc(db, `leaderboard_streak/${uid}`);
const swrite = (data, uid = "u1") => setDoc(sref(userDb(uid), "u1"), data);
test("streak: owner write allowed", () => assertSucceeds(swrite(streak("u1"))));
test("streak: other uid denied", () => assertFails(swrite(streak("u1"), "u2")));
test("streak: short username denied", () => assertFails(swrite(streak("u1", { username: "ab" }))));
test("streak: currentStreak -1 denied", () =>
  assertFails(swrite(streak("u1", { currentStreak: -1 }))));
test("streak: currentStreak double denied", () =>
  assertFails(swrite(streak("u1", { currentStreak: 2.5 }))));
test("streak: bestStreak < currentStreak denied", () =>
  assertFails(swrite(streak("u1", { currentStreak: 4, bestStreak: 3 }))));
test("streak: missing bestStreak denied", () => {
  const d = streak("u1");
  delete d.bestStreak;
  return assertFails(swrite(d));
});

test("streak: future lastDayKey denied", () =>
  assertFails(swrite(streak("u1", { lastDayKey: iso(3) }))));
test("streak: malformed lastDayKey denied", () =>
  assertFails(swrite(streak("u1", { lastDayKey: "2026-1-5" }))));
test("streak: lastDayKey yesterday allowed", () =>
  assertSucceeds(swrite(streak("u1", { lastDayKey: iso(-1) }))));
test("streak: currentStreak above epoch cap denied", () =>
  assertFails(swrite(streak("u1", { currentStreak: 100000, bestStreak: 100000, totalPlayed: 100000 }))));
test("streak: totalPlayed above epoch cap denied", () =>
  assertFails(swrite(streak("u1", { totalPlayed: 100000 }))));
test("streak: perfectDays > totalPlayed denied", () =>
  assertFails(swrite(streak("u1", { perfectDays: 9, totalPlayed: 8 }))));

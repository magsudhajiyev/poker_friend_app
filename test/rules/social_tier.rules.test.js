const { test, before, after, beforeEach } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc, Timestamp } = require("firebase/firestore");

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-rules-test",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});
after(async () => env && env.cleanup());
beforeEach(async () => env.clearFirestore());

const seedUser = (uid, data) =>
  env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), `users/${uid}`), data));
const follow = () =>
  setDoc(doc(env.authenticatedContext("u1").firestore(), "follows/u1_u2"), {
    followerId: "u1",
    followedId: "u2",
  });
const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86400000);

test("paid tier with future expiry has social access", async () => {
  await seedUser("u1", { subscriptionTier: "pro", subscriptionTierExpiresAt: inDays(5) });
  await assertSucceeds(follow());
});
test("paid tier with null expiry (lifetime) has social access", async () => {
  await seedUser("u1", { subscriptionTier: "elite", subscriptionTierExpiresAt: null });
  await assertSucceeds(follow());
});
test("paid tier with missing expiry has social access", async () => {
  await seedUser("u1", { subscriptionTier: "club" });
  await assertSucceeds(follow());
});
test("paid tier with past expiry denied", async () => {
  await seedUser("u1", { subscriptionTier: "pro", subscriptionTierExpiresAt: inDays(-1) });
  await assertFails(follow());
});
test("free tier denied", async () => {
  await seedUser("u1", { subscriptionTier: "free", subscriptionTierExpiresAt: null });
  await assertFails(follow());
});
test("no tier field denied", async () => {
  await seedUser("u1", { displayName: "x" });
  await assertFails(follow());
});

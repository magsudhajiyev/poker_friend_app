const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const fs = require("node:fs");
const { dailyAccuracy } = require("../lib/daily_accuracy.js");

// Shared with the client's DailyScoring test — the CF re-grades every entry,
// so any drift between the two would rewrite honest scores.
const fixture = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, "..", "..", "test", "fixtures", "daily_scoring_cases.json"),
    "utf8"
  )
);
const parseWeights = (w) =>
  w === null ? undefined : w.map((x) => (x === "Infinity" ? Infinity : x));

for (const c of fixture.cases) {
  test(`parity: ${c.name}`, () => {
    const score = dailyAccuracy(c.verdicts, parseWeights(c.weights));
    assert.equal(score, c.score);
    assert.equal(Math.round(score * 10), c.scoreKey);
    const letters = c.verdicts.replace(/\|/g, "");
    assert.equal(letters.length > 0 && /^c+$/.test(letters), c.perfect);
  });
}

test("non-number weights are treated as 1", () => {
  assert.equal(dailyAccuracy("cm", ["x", { a: 1 }]), 50);
});

test("NaN weight is treated as 1", () => {
  assert.equal(dailyAccuracy("cm", [NaN, 1]), 50);
});

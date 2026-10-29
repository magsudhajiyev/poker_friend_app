const test = require("node:test");
const assert = require("node:assert/strict");
const { chunk } = require("../lib/chunk_refs.js");

test("empty input gives no chunks", () => assert.deepEqual(chunk([]), []));
test("splits 1201 items into 500/500/201", () => {
  const out = chunk(Array.from({ length: 1201 }, (_, i) => i));
  assert.deepEqual(out.map((c) => c.length), [500, 500, 201]);
});
test("exact multiple has no empty tail", () => {
  assert.equal(chunk([1, 2, 3, 4], 2).length, 2);
});
test("invalid size throws", () => assert.throws(() => chunk([1], 0)));

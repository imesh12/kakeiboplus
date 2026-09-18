import test from "node:test";
import assert from "node:assert/strict";
import { createPetScheduler, canAdvanceLocale } from "../src/motion-policy.mjs";

test("only one companion owns the action slot, with a long calm period between scenes", () => {
  const scheduler = createPetScheduler();
  assert.equal(scheduler.tick(9000, ["hero", "language"]), null);
  const first = scheduler.tick(10000, ["hero", "language"]);
  assert.equal(first.id, "hero");
  assert.equal(scheduler.tick(15000, ["hero", "language"]).id, "hero");
  assert.equal(scheduler.tick(18000, ["hero", "language"]), null);
  assert.equal(scheduler.tick(62000, ["language"]), null);
  assert.equal(scheduler.tick(64000, ["hero", "language"]).id, "language");
});
test("completed scenes do not constantly loop", () => {
  const scheduler = createPetScheduler();
  scheduler.tick(10000, ["hero"]);
  scheduler.tick(18000, ["hero"]);
  assert.equal(scheduler.tick(100000, ["hero"]), null);
});
test("offscreen and reduced-motion scenes release the animation slot", () => {
  const scheduler = createPetScheduler();
  scheduler.tick(10000, ["hero"]);
  assert.equal(scheduler.tick(12000, []), null);
  assert.equal(scheduler.tick(100000, ["language"], true), null);
  assert.equal(scheduler.tick(100001, ["language"]), null);
});
test("direct companion interaction defers decorative actions", () => {
  const scheduler = createPetScheduler();
  scheduler.tick(10000, ["hero"]);
  scheduler.defer(12000);
  assert.equal(scheduler.tick(15000, ["hero", "budget"]), null);
});
test("automatic locale changes respect manual pause, visibility, focus and reduced motion", () => {
  const allowed = {
    now: 9000,
    lastChange: 0,
    pausedUntil: 0,
    visible: true,
    hidden: false,
    reduced: false,
    paused: false,
    focused: false,
  };
  assert.equal(canAdvanceLocale(allowed), true);
  for (const blocked of [
    { pausedUntil: 30000 },
    { visible: false },
    { hidden: true },
    { reduced: true },
    { paused: true },
    { focused: true },
    { now: 3000 },
  ]) {
    assert.equal(canAdvanceLocale({ ...allowed, ...blocked }), false);
  }
});

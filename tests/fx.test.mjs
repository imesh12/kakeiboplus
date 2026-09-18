import test from "node:test";
import assert from "node:assert/strict";
import {
  convertAmount,
  demoFxProvider,
  illustrativeRates,
} from "../src/fx.mjs";

test("JPY, INR, and NPR examples convert consistently through the base currency", () => {
  assert.ok(
    Math.abs(convertAmount(10000, "JPY", "USD") - 66.6666666667) < 0.0001,
  );
  assert.equal(convertAmount(830, "INR", "USD"), 10);
  assert.equal(convertAmount(150, "JPY", "NPR"), 133);
});
test("zero and same-currency amounts remain valid", () => {
  assert.equal(convertAmount(0, "JPY", "USD"), 0);
  assert.equal(convertAmount(1250, "USD", "USD"), 1250);
});
test("all currencies survive a round trip within floating-point precision", () => {
  for (const from of Object.keys(illustrativeRates)) {
    for (const to of Object.keys(illustrativeRates)) {
      assert.ok(
        Math.abs(
          convertAmount(convertAmount(1000, from, to), to, from) - 1000,
        ) < 0.000001,
      );
    }
  }
});
test("invalid inputs cannot produce misleading financial results", () => {
  for (const amount of [-1, NaN, Infinity])
    assert.throws(() => convertAmount(amount, "JPY", "USD"), RangeError);
  assert.throws(() => convertAmount(10, "GBP", "USD"), RangeError);
  assert.throws(() => convertAmount(10, "USD", "GBP"), RangeError);
});
test("provider response explicitly identifies sample data", async () => {
  const quote = await demoFxProvider.quote(150, "JPY", "USD");
  assert.equal(quote.amount, 1);
  assert.equal(quote.kind, "illustrative");
  assert.match(quote.source, /not live/);
});

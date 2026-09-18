import test from "node:test";
import assert from "node:assert/strict";
import { rateDisclosure } from "../src/fx.mjs";

test("illustrative data can never be labeled live through its source string", () => {
  assert.equal(
    rateDisclosure({ kind: "illustrative", source: "Live rate" }),
    "Illustrative rate · not live",
  );
});
test("future live disclosures require provider attribution and valid timestamps", () => {
  assert.equal(rateDisclosure({ kind: "live" }), "Exchange rate unavailable");
  assert.equal(
    rateDisclosure({
      kind: "live",
      provider: "Test provider",
      updatedAt: "invalid",
    }),
    "Exchange rate unavailable",
  );
  assert.equal(
    rateDisclosure({
      kind: "live",
      provider: "Test provider",
      updatedAt: "2026-09-18T10:42:00Z",
    }),
    "Live rate · Updated 10:42 UTC · Test provider",
  );
});

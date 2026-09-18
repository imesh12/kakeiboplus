import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

for (const width of [320, 375, 390, 430, 768, 1024, 1440, 1920]) {
  test(`responsive layout at ${width}px has no horizontal overflow or console errors`, async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (message) => {
      if (message.type() === "error") errors.push(message.text());
    });
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    await expect(page.locator("h1")).toHaveText(
      "Your money.Your language.Your currency.",
    );
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    await page.screenshot({
      path: `artifacts/landing-${width}.png`,
      fullPage: true,
    });
    await page.locator('[data-language="ar"]').click();
    await expect(page.locator("#language-preview")).toHaveAttribute(
      "dir",
      "rtl",
    );
    await page.locator('[data-currency="VND"]').click();
    await page.locator("#fx-amount").fill("1000000000000");
    await expect(page.locator("#fx-result")).not.toHaveText("66.67");
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    expect(errors).toEqual([]);
  });
}

test("language previews, currencies, conversions, input validation, and swapping work", async ({
  page,
}) => {
  await page.goto("/");
  await page.locator('[data-language="ja"]').click();
  await expect(page.locator("#language-balance-label")).toHaveText("総残高");
  await page.locator('[data-language="ar"]').click();
  await expect(page.locator("#language-preview")).toHaveAttribute("lang", "ar");
  await expect(page.locator("#language-preview")).toHaveAttribute("dir", "rtl");
  await page.locator('[data-currency="NPR"]').click();
  await expect(page.locator("#wallet-amount")).toHaveText(
    new Intl.NumberFormat("ne-NP", {
      style: "currency",
      currency: "NPR",
      currencyDisplay: "narrowSymbol",
      maximumFractionDigits: 0,
    }).format(240000),
  );
  await page.locator("#fx-amount").fill("150");
  await expect(page.locator("#fx-result")).toHaveText("1.00");
  await page.locator('[data-pair="JPY,NPR"]').click();
  await expect(page.locator("#fx-result")).toHaveText("133.00");
  await page.locator("#fx-swap").click();
  await expect(page.locator("#fx-from")).toHaveValue("NPR");
  await expect(page.locator("#fx-to")).toHaveValue("JPY");
  await page.locator("#fx-amount").fill("-1");
  await expect(page.locator("#fx-result")).toHaveText("—");
  await expect(page.locator("#fx-amount")).toHaveAttribute(
    "aria-invalid",
    "true",
  );
  await page.locator("#fx-amount").fill("0");
  await expect(page.locator("#fx-result")).toHaveText("0.00");
  await expect(page.locator("#fx-disclaimer")).toContainText("not live");
});

test("companion records a temporary demo expense and rewards checking in", async ({
  page,
}) => {
  await page.goto("/");
  await page.locator('[data-pet-action="yes"]').click();
  await page.locator('[data-pet-action="add"]').click();
  await expect(page.locator("#expense-dialog")).toBeVisible();
  await page.locator("#expense-name").fill("Lunch");
  await page.locator("#expense-amount").fill("800");
  await page.getByRole("button", { name: "Record demo expense" }).click();
  await expect(page.locator("#pet-message")).toContainText(
    "Lunch — ¥800 recorded in this demo",
  );
  await expect(page.locator("#main-pet svg")).toHaveClass(/pet-celebrate/);
  await page.locator('[data-pet-action="reset"]').click();
  await page.locator('[data-pet-action="no"]').click();
  await expect(page.locator("#pet-message")).toContainText("good habit");
  await page.locator('[data-pet-state="sleeping"]').click();
  await expect(page.locator("#main-pet svg")).toHaveClass(/pet-sleeping/);
});

test("keyboard tabs, launch dialog focus, and mobile menu are accessible", async ({
  page,
}) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto("/");
  await page.getByRole("button", { name: "Open menu" }).click();
  await expect(page.locator("#mobile-nav")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.locator(".menu-toggle")).toBeFocused();
  await expect(page.locator("#mobile-nav")).toBeHidden();
  await page.locator(".hero [data-start]").click();
  await expect(page.locator("#launch-dialog")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.locator(".hero [data-start]")).toBeFocused();
  await page.getByRole("tab", { name: "Dashboard" }).focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.getByRole("tab", { name: "Transactions" })).toBeFocused();
  await expect(page.locator("#feature-panel")).toContainText(
    "Your everyday, recorded.",
  );
  await page.keyboard.press("End");
  await expect(page.locator("#feature-panel")).toContainText(
    "Less wondering. More understanding.",
  );
});

test("reduced motion disables floating, charts, and entrance animations", async ({
  page,
}) => {
  await page.goto("/");
  expect(
    await page
      .locator(".phone-float")
      .evaluate((e) => getComputedStyle(e).animationName),
  ).toBe("none");
  expect(
    await page
      .locator("html")
      .evaluate((e) => getComputedStyle(e).scrollBehavior),
  ).toBe("auto");
  expect(await page.locator(".will-reveal").count()).toBe(0);
});

test("statically rendered content is available without JavaScript", async ({
  browser,
}) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto("http://127.0.0.1:4173");
  await expect(page.locator("h1")).toBeVisible();
  await expect(page.locator("#pricing")).toContainText(
    "Planned launch pricing",
  );
  await context.close();
});

test("automated WCAG checks on desktop and mobile", async ({ page }) => {
  for (const width of [1440, 375]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
      .analyze();
    expect(
      results.violations.map((v) => ({
        id: v.id,
        nodes: v.nodes.map((n) => ({
          target: n.target,
          summary: n.failureSummary,
        })),
      })),
    ).toEqual([]);
  }
});

/* global document, innerWidth */
import { preview } from "vite";
import { chromium } from "@playwright/test";
import { mkdir, writeFile } from "node:fs/promises";

const server = await preview({
  preview: { host: "127.0.0.1", port: 4175, strictPort: true },
});
const browser = await chromium.launch({ channel: "msedge" });
await mkdir("artifacts/visual", { recursive: true });
try {
  const page = await browser.newPage({ reducedMotion: "reduce" });
  const measurements = [];
  for (const width of [320, 375, 390, 430, 768, 1024, 1440, 1920]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto("http://127.0.0.1:4175");
    await page.screenshot({ path: `artifacts/visual/hero-${width}.png` });
    for (const [name, selector] of [
      ["languages", "#languages"],
      ["fx", "#exchange"],
      ["screens", "#features"],
      ["companion", "#companion"],
      ["closing", ".final-cta"],
    ]) {
      if ([320, 390, 768, 1024, 1440].includes(width))
        await page
          .locator(selector)
          .screenshot({
            path: `artifacts/visual/${name}-${width}.png`,
            style: ".header, .skip-link { visibility: hidden !important; }",
          });
    }
    measurements.push(
      await page.evaluate(() => ({
        width: innerWidth,
        overflow: document.documentElement.scrollWidth > innerWidth,
        devices: [...document.querySelectorAll(".app-device")].map((d) => ({
          width: d.clientWidth,
          content: d.querySelector(".device-content").scrollHeight,
          available: d.querySelector(".device-content").clientHeight,
        })),
      })),
    );
  }
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("http://127.0.0.1:4175");
  await page.locator("#hero-language").selectOption("ar");
  await page.screenshot({ path: "artifacts/visual/hero-arabic.png" });
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await page.reload();
  await page.locator('html[data-enhanced="true"]').waitFor();
  await page
    .locator('[data-scene="hero"][data-action="catch"]')
    .waitFor({ timeout: 20000 });
  await page.waitForTimeout(2200);
  await page.screenshot({ path: "artifacts/visual/hero-motion.png" });
  await writeFile(
    "artifacts/visual/measurements.json",
    JSON.stringify(measurements, null, 2),
  );
  console.log(JSON.stringify(measurements));
} finally {
  await browser.close();
  await new Promise((resolve) => server.httpServer.close(resolve));
}

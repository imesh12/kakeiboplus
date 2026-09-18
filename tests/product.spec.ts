import { test, expect } from '@playwright/test';

test('hero and section manual localization update individual labels, numbers and RTL', async ({ page }) => {
  await page.goto('/');
  await page.locator('#hero-language').selectOption('ja');
  await expect(page.locator('[data-phone="hero"] [data-phone-label="balance"]')).toHaveText('総残高');
  await expect(page.locator('[data-phone="hero"] [data-phone-label="income"]')).toHaveText('収入');
  await page.locator('#hero-language').selectOption('ar');
  await expect(page.locator('[data-phone="hero"]')).toHaveAttribute('dir', 'rtl');
  await expect(page.locator('[data-phone="hero"]')).toHaveAttribute('lang', 'ar');
  await expect(page.locator('[data-phone="hero"] [data-phone-money="128450"]')).toContainText('١٢٨');
  await expect(page.locator('#language-preview')).toHaveAttribute('dir', 'rtl');
  const avatar = await page.locator('[data-phone="hero"] .app-avatar').boundingBox();
  const greeting = await page.locator('[data-phone="hero"] .app-greeting strong').boundingBox();
  expect(avatar!.x).toBeLessThan(greeting!.x);
  await page.locator('[data-language="it"]').click();
  await expect(page.locator('#language-preview')).toHaveAttribute('dir', 'ltr');
  await expect(page.locator('[data-phone="language"] [data-phone-label="expense"]')).toHaveText('Uscite');
});

test('automatic hero localization pauses after manual selection and respects the motion control', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.clock.install();
  await page.goto('/');
  await expect(page.locator('.hero')).toHaveAttribute('data-inview', 'true');
  await page.clock.runFor(9000);
  await expect(page.locator('#hero-language')).toHaveValue('ja');
  await page.locator('#hero-language').selectOption('ar');
  await page.locator('#hero-language').blur();
  await expect(page.locator('.hero')).toHaveAttribute('data-auto-state', 'manual');
  await page.clock.runFor(15000);
  await expect(page.locator('#hero-language')).toHaveValue('ar');
  await page.getByRole('button', { name: 'Pause automatic motion' }).click();
  await page.clock.runFor(40000);
  await expect(page.locator('#hero-language')).toHaveValue('ar');
  await expect(page.locator('html')).toHaveAttribute('data-motion', 'paused');
  expect(await page.locator('[data-scene]:not([data-action="rest"])').count()).toBe(0);
});

test('reduced motion retains controls and never starts localization or decorative stories', async ({ page }) => {
  await page.clock.install();
  await page.goto('/');
  await page.clock.runFor(60000);
  await expect(page.locator('#hero-language')).toHaveValue('en');
  await expect(page.locator('.hero')).toHaveAttribute('data-auto-state', 'reduced');
  await page.locator('#hero-language').selectOption('ne');
  await expect(page.locator('[data-phone="hero"] [data-phone-label="income"]')).toHaveText('आम्दानी');
  expect(await page.locator('[data-scene]:not([data-action="rest"])').count()).toBe(0);
});

test('download statistics are explicitly unavailable without a real provider', async ({ page }) => {
  await page.goto('/');
  const counter = page.locator('[data-download-counter]');
  await expect(counter).toHaveAttribute('data-state', 'unavailable');
  await expect(counter).toHaveText('App launch coming soon');
  await expect(counter).not.toHaveAttribute('data-total');
});

test('all seven financial screens and all four companion concepts are usable', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  for (const name of ['Transactions', 'Budget', 'Savings', 'Savings Goals', 'Currency conversion', 'Reports', 'Dashboard']) {
    await page.getByRole('tab', { name, exact: true }).click();
    await expect(page.getByRole('tab', { name, exact: true })).toHaveAttribute('aria-selected', 'true');
    await expect(page.locator('#showcase-center .app-device')).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
  for (const kind of ['cat', 'rabbit', 'bird', 'dog']) {
    await page.locator(`[data-companion-kind="${kind}"]`).click();
    await expect(page.locator('#main-pet svg')).toHaveClass(new RegExp(`animal-${kind}`));
  }
  await page.locator('#fx-amount').fill('830');
  await page.locator('[data-pair="INR,USD"]').click();
  await expect(page.locator('#fx-result')).toHaveText('10.00');
  await expect(page.locator('#fx-disclaimer')).toHaveText('Illustrative rate · not live');
});

import { icon, pet, brand } from "./art";
import { currencies, languages, marketing } from "./config";
import { cta } from "./components/cta";
import { dashboardPhone } from "./components/phone";
import { companionScene } from "./components/companion";
import { formatMoney } from "./localization";
import {
  premiumHero,
  premiumLanguage,
  premiumFeatureShowcase,
  premiumFinal,
} from "./stories";

export { cta, storeLinks } from "./components/cta";
export function LandingHeader(): string {
  return `<header class="header"><div class="container header-inner">${brand()}<nav class="desktop-nav" aria-label="Main navigation"><a href="#features">Features</a><a href="#currencies">Currencies</a><a href="#companion">Companion</a><a href="#pricing">Pricing</a></nav><div class="header-actions">${cta("Get Started", "button-small")}<button class="menu-toggle" aria-label="Open menu" aria-expanded="false" aria-controls="mobile-nav">${icon("menu")}</button></div></div><nav class="mobile-nav" id="mobile-nav" aria-label="Mobile navigation" hidden><a href="#features">Features</a><a href="#currencies">Currencies</a><a href="#companion">Companion</a><a href="#pricing">Pricing</a></nav></header>`;
}
export function PhoneMockup(): string {
  return dashboardPhone();
}
export function HeroSection(): string {
  return premiumHero();
}
export function LanguageShowcase(): string {
  return premiumLanguage();
}
export function CurrencyShowcase(): string {
  return `<section class="section currency-section" id="currencies"><div class="container"><div class="section-heading reveal"><span class="eyebrow">02 / ONE PERSON. MORE THAN ONE CURRENCY.</span><h2>Your money doesn’t live<br>in <em>one currency.</em></h2><p>Everyday spending in yen. Savings in rupees. A balance in dollars.<br>Separate wallets. One clear picture of your personal finances.</p></div><div class="wallet-owner"><span class="app-avatar">A</span><span>Alex’s personal wallets</span><span>3 wallets / 3 currencies</span></div><div class="wallet-stage reveal"><div class="wallet-card wallet-nepal"><div class="wallet-top"><span class="flag">🇳🇵</span><span>PERSONAL GOAL</span>${icon("sprout", 20)}</div><h3>Nepal Savings</h3><strong>${formatMoney(240000, "NPR", "ne-NP")}</strong><div class="wallet-bottom"><span>For the goals you care about.</span><span>NPR</span></div></div><div class="wallet-card wallet-japan"><div class="wallet-top"><span class="flag" id="wallet-flag">🇯🇵</span><span>EVERYDAY WALLET</span>${icon("wallet", 20)}</div><h3 id="wallet-name">Japan Wallet</h3><strong id="wallet-amount">¥128,450</strong><div class="wallet-bottom"><span>For everyday spending.</span><span id="wallet-code">JPY</span></div></div><div class="wallet-card wallet-us"><div class="wallet-top"><span class="flag">🇺🇸</span><span>PERSONAL SAVINGS</span>${icon("globe", 20)}</div><h3>USD Savings</h3><strong>$1,250</strong><div class="wallet-bottom"><span>For your longer-term plans.</span><span>USD</span></div></div></div>${companionScene("currencies", "dog", "catch")}<div class="currency-options" role="group" aria-label="Explore illustrative currency wallets">${currencies.map((c) => `<button data-currency="${c.code}" aria-label="${c.name}" aria-pressed="${c.code === "JPY"}" class="${c.code === "JPY" ? "active" : ""}"><span aria-hidden="true">${c.symbol}</span>${c.code}</button>`).join("")}</div><p class="center section-note">Choose a currency to explore · Example balances, not connected accounts</p></div></section>`;
}
export function FxShowcase(): string {
  return `<section class="section fx-section" id="exchange"><div class="container split"><div class="section-copy reveal"><span class="eyebrow">03 / LESS MATH. MORE LIFE.</span><h2>Stop searching.<br><em>Start understanding.</em></h2><p>Exchange rates belong where your money is.</p><p>An amount means more when you can see it in a familiar currency. We’re bringing that clarity directly into your budget.</p><div class="fx-workflow"><span class="workflow-label">THE EXTRA STEPS</span><ol><li>Budget app</li><li>Leave app</li><li>Search exchange rate</li><li>Calculate</li><li>Return to budget</li></ol></div><div class="inline-note">${icon("exchange", 18)}WITH KAKEIBOPLUS: one in-app conversion.</div></div><div class="fx-card reveal"><div class="fx-card-heading"><span class="mini-icon">${icon("exchange", 21)}</span><strong>All inside your financial picture</strong><span class="demo-pill">DEMO</span></div><div class="fx-pairs" role="group" aria-label="Example conversion pair"><button class="active" data-pair="JPY,USD" aria-pressed="true">JPY → USD</button><button data-pair="INR,USD" aria-pressed="false">INR → USD</button><button data-pair="JPY,NPR" aria-pressed="false">JPY → NPR</button></div><label class="conversion-label" for="fx-amount">You have</label><div class="conversion-input"><input id="fx-amount" type="number" value="10000" min="0" max="1000000000000" step="any" inputmode="decimal" aria-describedby="fx-disclaimer fx-error"/><select id="fx-from" aria-label="Source currency">${currencies.map((c) => `<option value="${c.code}">${c.flag} ${c.code}</option>`).join("")}</select></div><div class="fx-connector"><span></span><button id="fx-swap" aria-label="Swap source and destination currencies">${icon("exchange", 19)}</button><span></span></div><label class="conversion-label" for="fx-to">In your other currency</label><div class="conversion-output"><output id="fx-result" for="fx-amount fx-from fx-to" aria-live="polite">66.67</output><select id="fx-to" aria-label="Destination currency">${currencies.map((c) => `<option value="${c.code}" ${c.code === "USD" ? "selected" : ""}>${c.flag} ${c.code}</option>`).join("")}</select></div><p id="fx-error" class="input-error" aria-live="polite"></p><p id="fx-disclaimer" class="fx-disclaimer">${icon("shield", 14)}Illustrative rate · not live</p><small class="fx-footnote">Try an amount. This preview uses sample rates; a live rate service is planned for launch.</small></div></div></section>`;
}
export function CompanionShowcase(): string {
  return `<section class="section companion-section" id="companion"><div class="container split"><div class="companion-scene reveal"><div class="companion-orb"></div><span class="companion-spark one" aria-hidden="true">✦</span><span class="companion-spark two" aria-hidden="true">✳</span><div class="conversation"><span class="conversation-label">YOUR DAILY CHECK-IN</span><p id="pet-message" aria-live="polite">Did you buy anything today?</p><div class="pet-actions" id="pet-actions"><button data-pet-action="yes">Yes, I did ${icon("arrow", 14)}</button><button data-pet-action="no">Not today</button></div></div><div class="main-pet" id="main-pet">${pet("idle")}</div><div class="companion-picker" role="group" aria-label="Choose a companion">${["dog", "cat", "rabbit", "bird"].map((kind, i) => `<button data-companion-kind="${kind}" aria-pressed="${i === 0}">${kind[0].toUpperCase() + kind.slice(1)}</button>`).join("")}</div><span class="pet-ground-note">Your little nudge toward good habits.</span><div class="pet-states" role="group" aria-label="Preview companion states">${["idle", "happy", "celebrate", "warning", "sleeping"].map((s) => `<button data-pet-state="${s}" aria-pressed="${s === "idle"}" class="${s === "idle" ? "active" : ""}"><span class="state-dot state-${s}"></span>${s[0].toUpperCase() + s.slice(1)}</button>`).join("")}</div></div><div class="section-copy reveal"><span class="eyebrow">04 / A LITTLE ENCOURAGEMENT</span><h2>A little support for<br><em>better money habits.</em></h2><p>Building a habit feels better with a little company.</p><p>A friendly check-in. A celebration when you record an expense. A gentle reminder to make time for your goals.</p><p>No judgment. No pressure. Just a small companion cheering on your everyday progress.</p><div class="companion-values"><span>${icon("heart", 18)}Encouragement, always</span><span>${icon("sprout", 18)}Good habits over perfect numbers</span></div><small class="section-note">Original companion concepts. Final artwork may evolve.</small></div></div></section>`;
}
export function FeatureShowcase(): string {
  return premiumFeatureShowcase();
}
export function GrowthSection(): string {
  return `<section class="section growth-section"><div class="container"><div class="growth-heading reveal"><div><span class="eyebrow">SMALL STEPS, MEANINGFUL CHANGE</span><h2>Grow your money.<br><em>Grow your future.</em></h2></div><p>Small habits can grow into<br>clearer financial decisions.</p></div><div class="growth-story-art" aria-hidden="true"><span>·</span><span>${icon("sprout", 30)}</span><span>${icon("sprout", 46)}</span><span>${icon("sprout", 64)}</span></div><div class="growth-goal"><span>${icon("sprout", 22)}</span><div><strong>Emergency fund</strong><small>¥72,000 of ¥100,000 · Illustrative goal</small><div class="progress"><span style="--progress:72%"></span></div></div><b>72%</b>${companionScene("savings", "rabbit", "push")}</div><div class="growth-steps">${[
    ["01", "Track", "Give the everyday a little attention.", "plus"],
    ["02", "Understand", "Discover the patterns behind the numbers.", "chart"],
    ["03", "Save", "Make space for the things you care about.", "wallet"],
    [
      "04",
      "Grow",
      "Make your next decision with more understanding.",
      "sprout",
    ],
  ]
    .map(
      ([n, title, copy, i]) =>
        `<div class="growth-step reveal"><div class="growth-step-top"><span>${n}</span><div class="growth-icon">${icon(i, 30)}</div></div><h3>${title}</h3><p>${copy}</p></div>`,
    )
    .join("")}</div></div></section>`;
}
export function PricingSection(): string {
  const price = new Intl.NumberFormat(marketing.pricing.locale, {
    style: "currency",
    currency: marketing.pricing.currency,
    maximumFractionDigits: 0,
  }).format(marketing.pricing.monthlyAmount);
  return `<section class="section pricing-section" id="pricing"><div class="container split"><div class="section-copy reveal"><span class="eyebrow">A SMALL INVESTMENT IN YOUR EVERYDAY</span><h2>A clearer mind.<br><em>A simpler plan.</em></h2><p>Good money habits should feel within reach.</p><p>Explore KakeiboPlus with a ${marketing.pricing.trialDays}-day free trial. Find your rhythm, build your routine, and see what a little clarity can do.</p><div class="price-pet">${pet("happy")}<span>Big possibilities.<br><strong>A small monthly price.</strong></span></div></div><div class="pricing-card reveal"><div class="pricing-top"><span>${icon("sprout", 20)}KakeiboPlus</span><span class="pricing-badge">ONE SIMPLE PLAN</span></div><h3>Your space to grow.</h3><div class="price"><span>${marketing.pricing.finalized ? "" : "~"}${price}</span><span>/ month<small>${marketing.pricing.currency} · after your free trial</small></span></div><div class="trial-band">${icon("star", 17)}Start with ${marketing.pricing.trialDays} days free</div><ul>${["Multilingual experience", "Multiple wallets & currencies", "In-app exchange-rate conversion", "Budgets, savings goals & reports", "Your personal money companion"].map((f) => `<li>${icon("check", 17)}${f}</li>`).join("")}</ul>${cta("Start Free")}<p class="pricing-disclaimer">${marketing.pricing.finalized ? "See subscription terms at sign-up." : "Planned launch pricing. Final price and subscription terms will be confirmed before sign-up."}</p></div></div></section>`;
}
export function FinalCTA(): string {
  return premiumFinal();
}
export function LandingFooter(): string {
  return `<footer class="footer"><div class="container"><div class="footer-main"><div>${brand()}<p>Personal finance.<br>With a world of possibilities.</p><span class="japanese-wordmark" lang="ja">カケイボプラス</span></div><div class="footer-links"><strong>Explore</strong><a href="#features">Features</a><a href="#currencies">Currencies</a><a href="#companion">Companion</a><a href="#pricing">Pricing</a></div><div class="footer-links"><strong>Coming together</strong>${Object.entries(
    marketing.legal,
  )
    .map(([key, url]) =>
      url
        ? `<a href="${url}">${key[0].toUpperCase() + key.slice(1)}</a>`
        : `<span>${key[0].toUpperCase() + key.slice(1)} <small>At launch</small></span>`,
    )
    .join(
      "",
    )}</div><div class="footer-language"><label for="footer-language">${icon("globe", 16)}Explore a language</label><select id="footer-language">${languages.map((l) => `<option value="${l.code}">${l.name}</option>`).join("")}</select><small>Switches the interface preview above.<br>This website is currently in English.</small></div></div><div class="footer-bottom"><span>© ${new Date().getFullYear()} KakeiboPlus. A little better, every day.</span><span>*Live FX is a planned feature. All amounts shown are illustrative.</span></div></div></footer>`;
}
export function Dialogs(): string {
  return `<dialog id="launch-dialog" class="dialog" aria-labelledby="launch-title"><button class="dialog-close" aria-label="Close launch details">${icon("close")}</button><div class="dialog-art">${pet("happy")}</div><span class="eyebrow">GOOD THINGS ARE GROWING</span><h2 id="launch-title">A little patience.<br>A world of possibilities.</h2><p>KakeiboPlus is getting ready to launch. Your ${marketing.pricing.trialDays}-day free trial will be available when sign-up opens.</p><div class="launch-detail">${icon("globe", 20)}App Store & Google Play · Coming soon</div><p class="section-note">There’s no account or payment to set up yet.</p><button class="button button-primary dialog-dismiss">Explore the preview${icon("arrow", 18)}</button></dialog><dialog id="expense-dialog" class="dialog expense-dialog" aria-labelledby="expense-title"><button class="dialog-close" aria-label="Close expense preview">${icon("close")}</button><span class="eyebrow">A LITTLE HABIT IN ACTION</span><h2 id="expense-title">Record a little moment.</h2><p>Try an expense. This is a temporary preview and isn’t saved to an account.</p><form id="expense-form"><label for="expense-name">What was it?</label><input id="expense-name" name="name" placeholder="Morning coffee" required maxlength="60"/><label for="expense-amount">Amount (JPY)</label><input id="expense-amount" name="amount" type="number" inputmode="decimal" placeholder="480" min="1" max="999999999" required/><button class="button button-primary" type="submit">Record demo expense${icon("check", 18)}</button></form></dialog>`;
}

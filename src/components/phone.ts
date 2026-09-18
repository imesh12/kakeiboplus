import { icon } from "../art";
import { companion } from "./companion";
import { formatMoney, languageProfile, type PhoneLabel } from "../localization";

export function dashboardPhone(instance = "hero"): string {
  const profile = languageProfile("en");
  const text = (key: PhoneLabel, id = "") =>
    `<span data-phone-label="${key}" ${id ? `id="${id}"` : ""}>${profile.labels[key]}</span>`;
  const money = (value: number, currency = "JPY") =>
    `<bdi data-phone-money="${value}" data-money-currency="${currency}">${formatMoney(value, currency)}</bdi>`;
  return `<div class="app-device phone" data-phone="${instance}" lang="en" dir="ltr" aria-label="Illustrative KakeiboPlus dashboard">
    <div class="device-status" aria-hidden="true"><span>9:41</span><i></i><span>▮▮▮ ▰</span></div>
    <div class="device-content"><div class="app-greeting"><div><span class="app-wordmark">KakeiboPlus</span><strong>${text("greeting", instance === "language" ? "language-greeting" : "")}</strong></div><span class="app-avatar">A</span></div>
    <div class="app-balance"><div>${text("balance", instance === "language" ? "language-balance-label" : "")}<span class="app-currency">JPY ${icon("chevron", 10)}</span></div><strong>${money(128450)}</strong><span class="app-converted">≈ <bdi data-phone-money="856.33" data-money-currency="USD">$856.33</bdi> <span>USD</span></span><span class="balance-art" aria-hidden="true">${icon("sprout", 76)}</span></div>
    <div class="app-cashflow"><div><span>${icon("arrow", 14)}${text("income")}</span><strong>${money(280000)}</strong></div><div><span>${icon("arrow", 14)}${text("expense")}</span><strong>${money(68000)}</strong></div></div>
    <div class="app-budget"><div class="app-row"><strong>${text("budget", instance === "language" ? "language-budget" : "")}</strong><span>68%</span></div><div class="progress"><span style="--progress:68%"></span></div><div class="app-budget-values">${money(68000)}<span>/ ${money(100000)}</span></div></div>
    <div class="app-recent"><div class="app-row"><strong>${text("recent")}</strong>${icon("chevron", 13)}</div><div class="app-transaction"><span class="app-transaction-icon">${icon("bag", 16)}</span><span>${text("lunch")}<small>12:30</small></span><strong>−${money(1200)}</strong></div><div class="app-transaction"><span class="app-transaction-icon train">${icon("train", 16)}</span><span>${text("train")}<small>08:45</small></span><strong>−${money(580)}</strong></div></div>
    <div class="app-savings"><span class="app-transaction-icon">${icon("sprout", 20)}</span><div><strong>${text("goal")}</strong><small>${text("saved", instance === "language" ? "language-saved" : "")} · ${money(24500)}</small><div class="progress"><span style="--progress:72%"></span></div></div></div>
    <div class="app-companion"><span aria-hidden="true">${companion("dog", "happy", true)}</span>${text("nudge")}</div>
    <div class="app-navigation" aria-label="Illustrative app navigation">${(["home", "activity", "budget", "goals", "more"] as PhoneLabel[]).map((key, i) => `<span class="${i === 0 ? "selected" : ""}">${icon(["grid", "exchange", "wallet", "sprout", "menu"][i], 17)}${text(key)}</span>`).join("")}</div></div><div class="home-indicator" aria-hidden="true"></div></div>`;
}
const chart = () =>
  `<div class="mini-report"><div class="mini-donut"><svg viewBox="0 0 120 120" aria-hidden="true"><circle class="chart-arc" cx="60" cy="60" r="48" pathLength="100" style="--arc:42;--rotation:-90deg;stroke:#006b68"/><circle class="chart-arc" cx="60" cy="60" r="48" pathLength="100" style="--arc:35;--rotation:61.2deg;stroke:#20c875"/><circle class="chart-arc" cx="60" cy="60" r="48" pathLength="100" style="--arc:23;--rotation:187.2deg;stroke:#9bea45"/></svg><span>¥68,000<small>Monthly expenses</small></span></div><div class="report-legend"><span><i></i>Everyday essentials <b>42%</b></span><span><i></i>Food & drinks <b>35%</b></span><span><i></i>Getting around <b>23%</b></span></div></div>`;
export function mobileScreen(tab: string): string {
  if (tab === "Dashboard") return dashboardPhone("showcase");
  const title: Record<string, string> = {
    Transactions: "Your everyday, recorded.",
    Budget: "A plan that feels possible.",
    Savings: "A little more set aside.",
    "Savings Goals": "Give your someday a plan.",
    Reports: "Less wondering. More understanding.",
    "Currency conversion": "Your currencies, together.",
  };
  let content = "";
  if (tab === "Reports")
    content = `<div class="screen-amount"><small>Saved this month</small><strong>¥24,500</strong><span>A little perspective on your habits.</span></div>${chart()}`;
  if (tab === "Budget")
    content = `<div class="screen-amount"><small>Available in your budget</small><strong>¥32,000</strong><span>Of ¥100,000 planned this month</span></div>${[
      ["Food & drinks", "24,000", "35,000", 69],
      ["Getting around", "8,000", "15,000", 53],
      ["Essentials", "18,000", "30,000", 60],
      ["Personal", "18,000", "20,000", 90],
    ]
      .map(
        ([name, value, total, progress]) =>
          `<div class="mobile-budget"><div><strong>${name}</strong><span>${progress}%</span></div><div class="progress"><span style="--progress:${progress}%"></span></div><small>¥${value} / ¥${total}</small></div>`,
      )
      .join("")}`;
  if (tab === "Transactions")
    content = `<div class="screen-amount"><small>This month’s expenses</small><strong>¥68,000</strong><span>Every little moment in one place.</span></div><div class="mobile-date">TODAY</div>${[
      ["bag", "Lunch", "12:30", "−¥1,200"],
      ["train", "Train", "08:45", "−¥580"],
      ["coffee", "Coffee", "08:15", "−¥480"],
    ]
      .map(
        ([i, name, time, value]) =>
          `<div class="app-transaction"><span class="app-transaction-icon">${icon(i, 18)}</span><span>${name}<small>${time}</small></span><strong>${value}</strong></div>`,
      )
      .join(
        "",
      )}<div class="mobile-date">YESTERDAY</div><div class="app-transaction"><span class="app-transaction-icon">${icon("wallet", 18)}</span><span>Monthly salary<small>Income</small></span><strong class="positive">+¥280,000</strong></div>`;
  if (tab === "Savings" || tab === "Savings Goals")
    content = `<div class="screen-amount"><small>${tab === "Savings" ? "Set aside this month" : "Your emergency fund"}</small><strong>${tab === "Savings" ? "¥24,500" : "¥72,000"}</strong><span>Small habits. Something to build on.</span></div><div class="mobile-goal"><div class="goal-sprout">${icon("sprout", 54)}</div><h4>Emergency fund</h4><p>A little breathing room.</p><div class="progress"><span style="--progress:72%"></span></div><div><strong>72%</strong><span>of ¥100,000</span></div></div><div class="mobile-goal secondary-goal"><h4>Home essentials</h4><div class="progress"><span style="--progress:48%"></span></div><div><strong>48%</strong><span>of ¥50,000</span></div></div>`;
  if (tab === "Currency conversion")
    content = `<div class="mobile-date">SAMPLE CONVERSION</div><div class="mobile-fx"><small>Indian rupee · INR</small><strong>₹10,000</strong></div><div class="mobile-fx-arrow">${icon("exchange", 24)}</div><div class="mobile-fx converted"><small>US dollar · USD</small><strong>$120.48</strong></div><div class="mobile-tip">Illustrative rate · not live</div><p class="mobile-note">Know what an amount means in the currency you think in.</p>`;
  return `<div class="app-device screen-device" aria-label="Illustrative ${tab} screen"><div class="device-status" aria-hidden="true"><span>9:41</span><i></i><span>▮▮▮ ▰</span></div><div class="device-content"><div class="screen-heading"><span>KakeiboPlus / ${tab}</span><h3>${title[tab]}</h3></div>${content}<div class="screen-footer">${icon("sprout", 16)}KakeiboPlus · Product preview</div></div><div class="home-indicator" aria-hidden="true"></div></div>`;
}

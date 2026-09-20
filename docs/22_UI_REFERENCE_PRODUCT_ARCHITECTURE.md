# 22. UI Reference → Product and Page Architecture Audit

Status: **PROPOSAL — analysis/documentation only; not an approval, ADR, or implementation instruction.**

**NAVIGATION SUPERSEDED (2026-09-20):** the navigation portions of this document (sections 1, 4, 5, 6, 14, 20, 21, 22, 23, 25 where they describe or lock in "Home / Activity / center Add / Profile") are superseded by section 26, which records the approved five-destination shell HOME / ACTIVITY / + ADD / ACCOUNTS / MORE. This document's non-navigation analysis (screen anatomy, domain/accounting rules, component system, risks) remains current.

Audit date: 2026-09-20. Repository HEAD at inspection: `9265065b408aeae318b282487efecbbdea595ebc`.

Reference: user-supplied `C:/Users/lme/Downloads/UI-referance.png`, an eight-screen composite, inspected visually in the conversation. Reading order: top row left to right S1–S4; bottom row left to right S5–S8. The image is product/design evidence, not an instruction source. No reference asset was edited.

Scope authority: the user's current task fixes V1 scope and Home / Activity / center Add / Profile navigation. Repository documents supply existing decisions and implementation context. Older scope statements that conflict with this task are explicitly recorded below; they are not silently rewritten. “Blueprint V2” in older document titles is a document revision, not necessarily the V2 product release used here. This scope-authority statement describes the navigation decision in force *at the time this document was authored*; as of 2026-09-20 it is superseded by section 26's five-destination shell (see the notice above).

Evidence notation used throughout:

- **[VISIBLE] / E:** literally visible in the composite. A chevron is evidence of an affordance, not proof of its destination or implemented behavior.
- **[INFERENCE] / I:** plausible product meaning or interaction inferred from that evidence.
- **[RECOMMENDATION] / R:** proposed production behavior; not approved.
- **[EXISTING PROJECT] / X:** observed in repository files, not inferred from the mockup.
- **[FUTURE] / F:** excluded from V1 in this proposal.

V1-later means a later checkpoint **within V1**, subject to approval where it changes existing behavior. It does not mean completed. Implementation status is separately tracked in section 20.

## 1. Executive summary

The eight screens describe a money-management system, not eight peer destinations. Home summarizes; Accounts locates money and borrowing; Add captures ledger events; Recurring organizes future events; Budgets constrains spending; Credit Card specializes account detail. Assets & Liabilities and Family Wallet extend the model into future wealth and shared ownership.

**Recommended V1:** retain the approved navigation and existing feature boundaries. Evolve the existing Home, Accounts, transaction forms, Budgets, Goals, Recurring/Subscriptions, and Profile surfaces. Add only focused missing detail and protection surfaces. Keep Subscriptions inside Recurring, credit cards inside Accounts, exchange-rate information inside existing FX surfaces, and deterministic Insights as a bounded deeper destination. Avoid separate Credit Cards, Bills, Exchange Rates, and generic Settings hubs where existing surfaces suffice.

**(Superseded 2026-09-20 -- see section 26.)** "The approved navigation" above refers to the previous Home/Activity/center Add/Profile shell; the current approved navigation is the five-destination HOME/ACTIVITY/+ADD/ACCOUNTS/MORE shell in section 26. The rest of this recommendation (evolve existing surfaces, avoid new hubs, keep Subscriptions/credit cards/FX/Insights where they are) is unaffected by the navigation change.

The visual target is a clear amount hierarchy, compact icon-led summaries, calm grouped lists, selective gradients, and obvious actions. The target is not literal duplication of its sample data, tab count, card collection, or five-item navigation.

Critical safeguards:

1. Balances and estimates remain deterministic derivations; currencies remain separated. Reference conversion does not become ledger truth.
2. Debit cards access bank balances; they never create another balance. Credit cards represent liabilities, with payment reducing cash and debt without another expense.
3. Subscriptions remain active, non-deleted recurring expense rules under ADR-031. Lifecycle filters in the mockup do not justify a second engine or silent definition change.
4. Advanced loans, deposits, property, crypto, wealth valuation, Household, OCR, AI, and bank integration remain outside V1. Essential card/account support is V1 work, but requires its own accounting checkpoint.
5. Preserve local operation without cloud login. Profile identity, cloud identity, sync status, and device security are separate concerns.

The repository is already partly visually converged. It also has pre-existing uncommitted cloud/database work. Source presence is not release readiness. This audit neither validates that work nor changes it. No application tests were run: this is a static architecture audit, not a runtime certification.

## 2. Reference-screen inventory

Parents and paths below are recommendations, not literal screenshot navigation.

| Screen | Canonical page / visible title | Production title / optional subtitle | Category; parent | Entries → exits | Release | Primary goal; secondary goals |
|---|---|---|---|---|---|---|
| S1 top-left | Home / greeting “Good morning, Jane!”; no separate Home header | Home / “Your money at a glance” (use greeting instead of both) | Overview; app shell | Launch, Home tab → Accounts, Budgets, Goals, Recurring, Activity, Add, Profile | V1 | Understand current position; notice commitments, capture money, hide amounts |
| S2 top-second | Accounts / “Accounts” | Accounts / “See where your money is held” | Money; Home or Profile entry, one canonical destination | Home/Profile → account detail, card detail, add/edit account; Back to caller | V1; advanced rows V2 | Find balances and payment sources; inspect debt, manage accounts |
| S3 top-third | Transaction capture / “Add Transaction” | Add Transaction / none; transaction type shown separately | Capture; Add action or contextual account | Add type picker, account action → Save returns to caller; Cancel/Back returns without posting | V1; repeat shortcut V1-later proposal | Record expense/income/transfer; choose source/category/date/note |
| S4 top-right | Subscription view / “Subscriptions” | Recurring with Subscriptions tab / “Keep track of recurring expenses” inside tab if helpful | Commitments; Recurring | Home Upcoming or Profile → Recurring → Subscriptions → rule detail/editor; Back | V1; exact reference filters not approved | Understand recurring expense cost; inspect due items, post/skip/edit |
| S5 bottom-left | Budgets / “Budgets” | Budgets / “Plan your spending and stay on track” | Planning; Home or Profile | Summary/card or Profile → budget detail, create/edit; Back | V1; month browsing/detail V1-later | Compare spend with plan; identify category pressure, adjust plan |
| S6 bottom-second | Wealth overview / “Assets & Liabilities” | Assets & Liabilities / “See what you own and owe” | Wealth; future Profile tool | Future Profile/Accounts contextual link → assets, liabilities, net worth, valuation detail; Back | V2 | Understand wealth; maintain valuations and debt records |
| S7 bottom-third | Credit-card account detail / “Credit Card” | Card nickname, fallback “Credit Card” / none | Money detail; Accounts | Accounts card/row → activity, payment, metadata edit; Back | V1-later essential detail; statements V2 | Understand amount owed and make a payment record; inspect spending and limit |
| S8 bottom-right | Shared-wallet detail / “Family Wallet” | Family Wallet; wallet name inside hero / “Manage money together” only on future landing | Household detail; future Profile | Profile → Family Wallet → members, invite, activity, settings, money movement; Back | V2 only | Manage shared money; coordinate members and permissions |

S2/S7 are the same financial object at different levels. S4 is a projection of Recurring. S6 must not redefine cash/bank as a second asset record. S8 introduces ownership scope, not a new transaction type.

## 3. Screen-by-screen anatomy

Each table follows the visible vertical order. Importance: **P** primary, **S** secondary, **U** supporting. “Action → destination” is inferred/proposed unless explicitly described as a visible control. Domain fields are conceptual dependencies, not schema changes. Components are candidates, cross-referenced in section 16.

### S1 — Home

```text
System status bar
Greeting + sun illustration + notification bell/dot
Total Balance hero + visibility icon + month comparison
Income / Expenses two-column metrics
Budgets / Goals two-column shortcuts
Upcoming (Next 7 days) + See all
  Netflix / Electricity Bill / Amazon Prime
Reference bottom navigation + system home indicator
```

| Visible section/evidence | Information | Inferred action → proposed destination | Domain data | Component; placement; importance |
|---|---|---|---|---|
| Greeting | “Good morning,” “Jane!”, “Make today a good financial day.” Sun icon | Greeting itself need not navigate | Display name; device time for greeting | AppHeader; belongs, compact; U |
| Bell with red dot | Notification affordance; no count or content visible | Notification preferences or real reminder list only if built | Permission/scheduler state; unread count only if a real inbox exists | IconButton; optional, omit fictitious unread dot; U |
| Pastel cyan/lilac balance card | Total Balance ¥1,234,567; eye icon; green upward “+2.5% from last month”; tiny adjacent decorative glyph unclear | Eye toggles masking; card may link Accounts | Currency-scoped derived balance; comparison baseline if implemented; local visibility state | MoneyHeroCard; belongs; P |
| Income / Expenses | Green income icon ¥320,000; pink expense icon ¥185,420 | Filtered Activity for displayed period/type | Expense/income totals, period, currency | SummaryMetricCard; belongs; S |
| Budgets / Goals | Purple budget icon “On track”; cyan goals icon “2 active” | Budgets / Savings Goals | Deterministic budget status; active goal definition/count | SummaryMetricCard; belongs as links; S |
| Upcoming header | “Next 7 days”, See all | Recurring, upcoming context | Due-date window | AppSectionHeader; belongs; S |
| Three upcoming rows | Netflix ¥1,590 Sep 18, 2026 Subscription; Electricity Bill ¥6,480 Sep 20 Bill; Amazon Prime ¥5,900 Sep 22 Subscription | Rule/occurrence detail; do not imply tapping auto-pays | Recurring rules, unhandled dates, expense kind, merchant/category metadata | UpcomingRow + StatusChip; bounded list; S |
| Navigation | Home selected; Accounts, raised +, Budgets, More | Map to approved shell, section 14 | Active location | BottomNavigation; adapt, do not copy labels/count; P |

**I:** The balance-first layout answers “where am I?” before “what happens next?” Metrics and planning shortcuts keep secondary information small. Upcoming provides actionable context rather than a second transaction history. No search, month picker, full chart, account list, goal progress ring, or FX card is visible here.

**R states:** no accounts → Add Account CTA, not invented balance; no budget/goals → purposeful setup links; no upcoming → “Nothing due in this period”; load sections independently; balance failure → unavailable/retry, never zero; stale FX remains secondary and labeled; hidden amounts must also be masked in accessible labels and all Home summaries. A failed section must not block Add.

### S2 — Accounts

```text
Header: Accounts / search / blue +
Filters: All / Cash / Bank / Cards / Assets
My Cards / See all
Horizontal card carousel + three pagination dots
Accounts grouped list
  Cash Wallet / JPY Savings / Debit Card (Linked) / ABC Visa / Car Loan
Reference navigation (Accounts selected)
```

| Visible section/evidence | Information | Inferred action → proposed destination | Domain data | Component; placement; importance |
|---|---|---|---|---|
| Header controls | Search magnifier, filled circular + | Local search; Add Account/type chooser | Account names/types; instruments after approved model | AppHeader + search + action; belongs; P |
| Five pills | All selected blue, Cash/Bank/Cards/Assets unselected | Filter same collection; Assets future link/filter only when implemented | Account class versus payment instrument versus asset | FilterChip group; simplify V1; S |
| My Cards header | See all | Cards filter in Accounts, not separate hub | Card list | AppSectionHeader; optional with multiple cards; S |
| Hero carousel | ABC Bank, Visa Platinum, VISA, •••• 4586; Owed ¥82,500; Limit ¥500,000; partial neighboring cards; three dots | Card tap → Credit Card detail; horizontal swipe inferred | Issuer/network/display name/last four; liability owed/limit | AccountCard/CreditCardHero; secondary to liquid accounts in V1; S |
| Cash Wallet row | Wallet tile; ¥12,000 | Account detail | Cash ledger | AccountRow; belongs; P |
| JPY Savings row | Bank tile; ¥450,000 | Account detail | Bank ledger | AccountRow; belongs; P |
| Debit Card (Linked) | Link cue, “Linked to JPY Savings”, ¥0 | Bank-linked instrument metadata | Bank ID and masked metadata; no debit balance | AccountRow variant; nest under bank, remove ¥0; S |
| ABC Visa (Credit Card) | VISA mark; ¥82,500; Limit ¥500,000 | Same card detail as carousel | Same liability ID, not another asset | Liability row; belongs in owed group; P |
| Car Loan | Car tile; −¥1,200,000 | Future Liability detail | Principal/debt data | Liability row; defer V2; F |

**I:** Card carousel and bank list serve different retrieval tasks. The repeated Visa amount is the same object, not two balances. There is no visible aggregate account balance or archive control. **R:** avoid a carousel if it pushes the everyday bank list out of view. Use labeled amounts (“Balance”, “Owed”), not sign alone.

**R states:** no accounts → create; no cards → hide carousel; filter with no results → reset filters; loading → row placeholders; a failed balance leaves name/currency visible with “Unavailable”; orphaned debit link blocks payment-source use and offers repair after a defined data policy; archived accounts retain history. Search must not leak masked monetary values.

### S3 — Add Transaction

```text
Back / Add Transaction
Expense (selected pink) / Income / Transfer
Amount field
Category selector
Pay from selector
Date selector
Note (optional)
Repeat (Subscription) switch, off
Save Transaction
System home indicator; no bottom navigation
```

| Visible section/evidence | Information | Inferred action → proposed destination | Domain data | Component; placement; importance |
|---|---|---|---|---|
| Back + title | Focused creation context | Return to caller; dirty form confirmation when needed | Draft state | AppHeader; belongs; P |
| Three segments | Expense selected, Income, Transfer | Change capture type before saving | Transaction type | SegmentedControl; visual behavior change versus existing picker requires approval; P |
| Amount | ¥2,480, large editable-looking field | Numeric input; currency derives from selected account under current contract | Integer minor units, currency metadata | MoneyTextField; belongs; P |
| Category | Orange utensils, Food & Dining, chevron | Category picker sheet | Category ID; type compatibility | SelectorRow + CategoryIconTile; belongs for expense/income; P |
| Pay from | VISA tile; ABC Visa •••• 4586; chevron | Payment-source picker | Account ID; future instrument/liability resolution | SelectorRow; belongs; P |
| Date | Aug 28, 2026; calendar icon; small leading glyph not reliably identifiable | Date picker dialog | Occurrence date/time convention | DateField; belongs; S |
| Note | “Dinner with friends” | Edit optional free text | Stored note | TextField; belongs; U |
| Repeat | “Repeat (Subscription)” off | Proposed later explicit recurring setup; never silently post twice | Rule template and first occurrence relationship | Switch + recurring form; not a simple visual addition; S |
| Save | Wide pink rounded Save Transaction button | Validate, persist once, then return with result | Repository write; validation errors | PrimaryActionButton; belongs; P |

**I:** Only Expense content is shown. Income fields, transfer destination, keyboard, validation, attachments, and recurrence configuration are not visible. **R:** transfer shows source and destination and hides category; credit-card payment reuses this transfer-like operation. Keep current same-currency boundary. No OCR button in V1. No currency conversion promise from the ¥ symbol.

**R states:** missing source → create/select account; unavailable/deleted source → preserve draft and reselect; invalid precision/zero/overflow → inline amount error; persistence error → retain draft; saving → disable duplicate submission; cancelled picker → preserve values. Scroll above keyboard at 200% text. Recurrence failure must not report an unsaved transaction as saved or duplicate one already saved.

### S4 — Subscriptions

```text
Subscriptions / search / blue +
Monthly estimated total card + yearly total + chevron
All / Active / Upcoming / Expired
Merchant rows with logo, price/frequency, next date, source, category chip
Reference bottom navigation
```

| Visible section/evidence | Information | Inferred action → proposed destination | Domain data | Component; placement; importance |
|---|---|---|---|---|
| Header | Search, + | Search rules; existing shared recurring editor only | Rule names and editable template | AppHeader; search optional, + conflicts with ADR-031 placement; S |
| Estimate card | Calendar tile; monthly ¥8,760; yearly ¥105,120; chevron | Explain estimate basis in sheet, not another accounting dashboard | Recurrence-normalized estimates per currency | SummaryMetricCard; belongs; P |
| Four filters | All selected; Active, Upcoming, Expired | Reference lifecycle/time filtering; V1 retain existing tabs/semantics | Rule lifecycle versus occurrence timing | FilterChip group; do not copy redundant/unsupported filters; S |
| Netflix | ¥1,590/month; Next Sep 18, 2026; ABC Visa ••••4586; Entertainment | Open rule/context detail | Name, amount, recurrence, pending date, source/category | SubscriptionRow; belongs; P |
| Spotify | ¥980/month; Next Sep 21, 2026; JPY Savings; Entertainment | Same | Same | SubscriptionRow; belongs; P |
| YouTube Premium | ¥1,280/month; Next Sep 25, 2026; Visa source; Entertainment | Same | Same | SubscriptionRow; belongs; P |
| Amazon Prime | ¥5,900/year; Next Jan 10, 2027; Visa source; Shopping | Same; yearly billing must not display as monthly bill | Same, yearly frequency | SubscriptionRow; belongs; P |
| iCloud+ | ¥1,200/month; Next Sep 29, 2026; Cloud Storage chip; lower source text clipped | Same; do not infer clipped source value | Same | SubscriptionRow; belongs; P |

**I:** Merchant logos are visual identifiers, not bank integration evidence. The cropped list may continue. Estimates are not “due this month.” **R states:** distinguish no active rules from no pending items; no search results from empty collection; ended schedule from deleted rule; failed estimate from zero estimate. Keep rows usable when one metadata lookup fails. Show skipped/posted occurrence feedback and updated next unhandled date. Details in section 10.

### S5 — Budgets

```text
Budgets / +
Month selector: back / August 2026 / forward
Overview: 65% ring + total / spent / remaining
Category rows: icon + spent/limit + percent + horizontal bar
Reference navigation (Budgets selected)
```

| Visible section/evidence | Information | Inferred action → proposed destination | Domain data | Component; placement; importance |
|---|---|---|---|---|
| Title and + | Create affordance | Existing overall/category chooser, then form | Budget scope | AppHeader; belongs; P |
| Month strip | August 2026, two chevrons | Select prior/next month | BudgetMonth; selected period | MonthNavigator; proposed V1-later behavior; P |
| Summary | Ring 65%; Total Budget ¥200,000; Spent ¥130,420; Remaining ¥69,580 | Overall budget detail | Budget amount; expense-only aggregation | ProgressRing + MoneySummary; belongs, ring optional; P |
| Food & Dining | ¥28,500 / ¥40,000; 71%; utensils tile; green bar | Category budget detail → filtered transactions/edit | Exact category scope | BudgetProgressRow; belongs; P |
| Shopping | ¥35,200 / ¥50,000; 70%; bag tile | Same | Same | BudgetProgressRow; belongs; P |
| Transport | ¥12,300 / ¥20,000; 62%; bus tile | Same | Same | BudgetProgressRow; belongs; P |
| Entertainment | ¥8,420 / ¥20,000; 42%; purple tile | Same | Same | BudgetProgressRow; belongs; P |

**I:** Category limits need not sum to overall budget; unbudgeted categories may explain additional spending. All bars are green even above 70%, so the picture does not define production risk thresholds. **R states:** no plan is different from zero spending; over-budget means negative remaining and explicit “Over budget”, not a broken ring; future periods have no pace projection; loading/error never imply on-track. Preserve existing deterministic status thresholds.

### S6 — Assets & Liabilities

```text
Assets & Liabilities / +
Assets (selected) / Liabilities / Net Worth
Total Assets hero
Cash & Bank / Fixed Deposit / Property / Inventory / Crypto / Other Assets
Reference navigation (Accounts selected)
```

The “Property / Inventory” wording is one row, not two separate visible rows.

| Visible section/evidence | Information | Inferred action → future destination | Domain data | Component; placement; importance |
|---|---|---|---|---|
| Header + | Asset management entry | Add asset/liability chooser | Asset/liability classes | AppHeader; V2; P |
| Three segments | Assets selected; Liabilities and Net Worth hidden content | Switch financial lens | Valuation and liability projections | SegmentedControl; V2; P |
| Mint hero | Total Assets ¥12,350,000 | Explain aggregation/valuation basis | Derived valued assets | MoneyHeroCard; V2; P |
| Cash & Bank | ¥462,000, blue cash/bank tile | Existing Accounts with same ledger IDs | Liquid balances | FinanceListRow; references Accounts, never duplicate record; S |
| Fixed Deposit | ¥1,000,000, gold bank-like tile | Deposit detail | Principal, maturity, valuation basis | AssetRow; V2; P |
| Property / Inventory | ¥12,000,000; “Honda Vezel 2022”; house tile | Asset detail | Asset name/type/value | AssetRow; taxonomy mismatch requires correction; P |
| Crypto | ¥350,000, coin icon | Holdings detail | Units, valuation currency/time/source | AssetRow; deferred; P |
| Other Assets | ¥0, blue tile | Other asset list | Manually classified assets | AssetRow; zero state rather than fake holding; S |

**I:** Liabilities and Net Worth tabs are not shown open; their content cannot be claimed as visible. **R states (V2):** no assets, missing/stale valuation, unknown FX, partially valued portfolio, liability overpayment, failed sync, and valuation conflicts. Total must explain exclusions. See section 12 for the visible arithmetic discrepancy.

### S7 — Credit Card

```text
Back / Credit Card / faint + affordance
Blue card hero: issuer / product / network / last four
Current Owed / Available
Utilization bar / Limit / Used percentage
Menu: Recent Transactions / Payment-Transfer / Card Details / Statements / Settings
Reference navigation (Accounts selected)
```

| Visible section/evidence | Information | Inferred action → proposed destination | Domain data | Component; placement; importance |
|---|---|---|---|---|
| Header | Back; faint plus at upper right, purpose not labeled | Back to caller; omit ambiguous plus or give explicit Add expense semantics later | Card ID/context | AppHeader; belongs except unexplained +; U |
| Branded identity | ABC Bank, Visa Platinum, VISA, ••••4586 | Read-only identity | Safe metadata | CreditCardHero; belongs; S |
| Amounts | Current Owed ¥82,500; Available ¥417,500 | No automatic remote balance claim | Derived liability balance; limit minus owed | MoneySummary; belongs; P |
| Limit/utilization | Limit ¥500,000, Used 16.5%, partial progress bar | Explain manually tracked available credit | Limit; derived ratio | ProgressBar; belongs, semantic label; S |
| Recent Transactions | Icon and chevron | Account-scoped Activity | Ledger account ID | FinanceListRow; belongs; P |
| Payment / Transfer | Icon and chevron | Payment form with destination fixed | Source liquid account; debt ledger | ActionRow; rename “Record payment”; P |
| Card Details | Card icon/chevron | Metadata section/editor | Safe card fields | DetailRows; combine with edit; S |
| Statements | Document icon/chevron | Future locally modeled/imported statement view | Statement periods, balances, documents | ActionRow; defer, no dead V1 link; F |
| Settings | Gear/chevron | Edit card metadata/archive | Active state; metadata | ActionRow; merge into Edit Card, not generic Settings subtree; U |

**R states:** no purchases, no limit, zero limit, debt exceeding limit, credit balance/overpayment, archived funding source, payment save error, stale linked cloud state. A missing limit means unavailable utilization, not 0%. Card detail does not require an online bank connection. See section 9.

### S8 — Family Wallet

```text
Dark header: Back / Family Wallet / gear
Shared wallet hero: group avatar / Our Family / Shared - 4 members
  Shared Wallet / ¥28,500 / Available balance
  Add Money / Transfer
Members / Invite
  Dad (Owner), Mom, Alex, Sophie, Add
Recent Activity / See all
  Mom: Shopping (Bag), −¥4,000, Aug 28, 2026
  Alex: Lunch, −¥1,200, Aug 27, 2026
Reference navigation (More selected)
```

| Visible section/evidence | Information | Inferred action → future destination | Domain data | Component; placement; importance |
|---|---|---|---|---|
| Back / gear | Wallet-level settings | Back / wallet settings | Wallet ID; current role | AppHeader; V2; U |
| Hero identity | Our Family; shared badge, four members, group avatar | Wallet overview | Membership count; wallet name | MoneyHeroCard + StatusChip; V2; P |
| Balance | ¥28,500 available | Inspect shared ledger | Shared ownership and derived balance | MoneyText; V2; P |
| Two buttons | Blue Add Money, muted Transfer | Shared funding/movement form | Ownership-aware source/destination and authorization | Primary/secondary button; V2; P |
| Members header | Invite link/icon | Invitation flow | Identity, invitation lifecycle | SectionHeader; V2; S |
| Avatar strip | Dad Owner; Mom; Alex; Sophie; circular + Add; tiny accent dots without legend | Member detail/role actions; Add and Invite should resolve consistently | Membership/roles, optional avatar | MemberAvatar; no inferred online-presence claim; S |
| Recent Activity | See all; actor/avatar, merchant/note, signed amount, date | Shared activity → event detail | Actor attribution and audit trail | FinanceListRow; V2; S |

**I:** Owner is visible; other roles, permissions, approvals, and conflicts are not. A visible avatar initial appears inconsistent with the actor label; do not use mock initials as identity evidence. **R states (V2):** empty wallet, pending/expired invite, removed member, insufficient permission, offline unsynced write, conflicting edit, partial ledger, revoked access. Do not imply a real-time shared balance when showing a local snapshot.

## 4. Product taxonomy

Domains own behavior; navigation provides access. Neither needs one bottom tab per domain.

| Domain | Responsibility | Primary surfaces | Boundary |
|---|---|---|---|
| Overview / UNDERSTAND | Synthesis and deterministic interpretation | Home, Insights | No duplicate ledger or stored balances |
| Money / TRACK | Ledger, history, accounts and instruments | Activity, Add, Accounts, Categories | Posting belongs here |
| Planning / SAVE | Spending plans and savings progress | Budgets, Savings Goals | Goals are not extra bank balances |
| Commitments | Schedules and occurrence handling | Recurring, Subscriptions | Future commitments are not actual expenses |
| Global | Countries, locales, currencies, reference FX | International Preferences, Converter | Reference rates do not rewrite history |
| Identity/device | Profile, cloud identity, sync, privacy/security | Profile and focused settings | Local profile is not cloud identity |
| Wealth [FUTURE] | Non-liquid valuation and advanced debt | Assets & Liabilities | References liquid ledgers without copying |
| Household [FUTURE] | Shared ownership, roles, attribution | Family Wallet | Permission layer, not second money engine |

```text
Product
├── Home [VISIBLE S1] [EXISTING PROJECT]
│   ├── Accounts [VISIBLE S2] [EXISTING PROJECT]
│   │   ├── Account Detail [IMPLIED]
│   │   └── Credit Card Detail [VISIBLE S7; V1-later]
│   ├── Budgets [VISIBLE S5] [EXISTING PROJECT]
│   ├── Savings Goals → Goal Detail [IMPLIED by S1] [EXISTING PROJECT]
│   ├── Upcoming → Recurring [EXISTING PROJECT]
│   │   └── Subscriptions tab [VISIBLE S4 visual] [EXISTING PROJECT tab]
│   └── Insights [IMPLIED; V1-later]
├── Activity → Transaction Details → Edit [EXISTING PROJECT]
├── Add action → Type picker → Add Transaction [VISIBLE S3] [EXISTING PROJECT]
└── Profile [EXISTING PROJECT; reference More analogy is INFERENCE]
    ├── Money tools → same Accounts / Categories / Budgets / Goals / Recurring
    ├── International Preferences → Converter [EXISTING PROJECT]
    ├── Appearance [EXISTING PROJECT]
    ├── Notifications / Cloud Account / Sync / Security / Privacy / About [IMPLIED]
    ├── Assets & Liabilities [VISIBLE S6] [FUTURE]
    └── Family Wallet [VISIBLE S8] [FUTURE]
```

Multiple entry points resolve to one canonical surface; this is not a proposal for duplicated routes.

**(Superseded 2026-09-20 -- see section 26.3 for the current V1 tree.)** The tree above still roots every destination under the previous Home/Activity/Add/Profile shell, with Profile as the fifth branch; the approved tree now roots Accounts as its own top-level branch alongside Home/Activity/Add, and renames the Profile branch MORE.

## 5. Master page registry

This is a surface registry, not a route-creation list. Existing dialogs remain dialogs. Adaptive full-screen rendering of a form does not create another product destination. IDs are product surface identifiers, not database keys. Subtitle codes resolve to exact copy in section 6; “—” intentionally means no subtitle. All additions are proposals.

| ID | Domain | Title | Subtitle | Type | Parent | Entry | Primary action | Secondary actions | Release / reference |
|---|---|---|---|---|---|---|---|---|---|
| O01 | Overview | Home | H | Shell page | Shell | Launch/Home tab | Open money task | Hide amounts, summary links | V1; S1 |
| T01 | Money | Activity | A | Shell page | Shell | Activity; metric links | Inspect transaction | Search/filter/Add | V1; S7 implied |
| T02 | Capture | Add | — | Type sheet | Shell/context | Center + | Choose Expense/Income/Transfer | Dismiss | V1; S3 entry |
| T03 | Capture | Add Transaction | — | Form page | T02/account | Type choice | Save | Source/category/date pickers; cancel | V1; S3 |
| T04 | Money | Transaction Details | — | Detail page | T01 | Row | Review | Edit/delete confirmation | V1; implied/existing |
| T05 | Money | Edit Transaction | — | Form page | T04 | Edit | Save changes | Cancel; type fixed | V1; existing |
| M01 | Money | Accounts | AC | List page | Home/Profile | Shortcut/tool row | Open account | Add/search/filter | V1; S2 |
| M02 | Money | {Account name} | — | Detail page | M01 | Account row | View balance/activity | Add/transfer/edit | V1-later; implied |
| M03 | Money | Add Account | — | Existing dialog | M01 | + | Save account | Type/currency/cancel | V1; S2 + |
| M04 | Money | Edit Account | — | Form dialog/sheet | M02 | Edit | Save metadata | Archive/cancel | V1-later; implied |
| M05 | Money | Credit Cards | — | Filter/section, not page | M01 | Cards filter | Open card | Add through account chooser | V1-later; S2 |
| M06 | Money | {Card nickname} | — | M02 detail variant | M01 | Card row/hero | Record payment | Transactions/edit | V1-later; S7 |
| M07 | Money | Record Card Payment | — | Shared transfer form page | M06 | Record payment | Save payment record | Source/date/note/cancel | V1-later; S7 |
| M08 | Money | Edit Card | — | Form page/sheet | M06 | Edit | Save safe metadata | Archive/link source | V1-later; S7 |
| M09 | Money | Debit Card | — | Bank metadata section + editor | M02 bank | Linked instrument | Edit metadata | Deactivate instrument | V1-later; S2 |
| C01 | Money | Categories | C | Management page | Profile | Tool row | Manage category | Add/type scope | V1; S3 implied |
| C02 | Money | Add Category / Edit Category | — | Shared dialog | C01 | Add/edit | Save | Icon/type/cancel | V1; implied; edit completeness unverified |
| B01 | Planning | Budgets | B | Overview/list | Home/Profile | Summary/tool row | Inspect plan | Create; proposed month selection | V1; S5 |
| B02 | Planning | {Budget scope} | — | Detail page | B01 | Summary/category | Inspect spend/pace | Edit/scoped Activity | V1-later; implied |
| B03 | Planning | Create Budget | — | Scope chooser + existing dialog | B01 | + | Set overall/category limit | Currency/category/cancel | V1; S5 |
| B04 | Planning | Edit Budget | — | Same budget dialog | B01/B02 | Edit | Save amount | Remove plan/cancel | V1; implied |
| G01 | Planning | Savings Goals | G | List page | Home/Profile | Goal summary/tool | Open goal | Create | V1; S1 implied |
| G02 | Planning | {Goal name} | — | Existing detail | G01 | Goal row | Add contribution | Edit/history/delete | V1; existing |
| G03 | Planning | Create Goal | — | Existing dialog | G01 | + | Save target | Currency/date/cancel | V1; implied |
| G04 | Planning | Edit Goal | — | Existing dialog | G02 | Edit | Save permitted fields | Cancel | V1; existing |
| G05 | Planning | Add Contribution | — | Existing dialog | G02 | Contribute | Record contribution | Cancel | V1; implied |
| R01 | Commitments | Recurring | R | Page, two tabs | Home/Profile | Upcoming/tool | Handle occurrence | Create/edit/reminders | V1; existing |
| R02 | Commitments | Subscriptions | S | Tab in R01 | R01 | Tab | Inspect next pending expense | Estimates/post/skip/edit | V1; S4 |
| R03 | Commitments | {Recurring item name} | — | Detail sheet | R01/R02 | Row | Post/skip selected date | Schedule/edit/delete rule | V1-later; implied; existing row actions valid |
| R04 | Commitments | Create Recurring / Edit Recurring | — | Existing rule dialog | R01/R03 | +/Edit | Save rule | Kind/source/frequency/end/reminder | V1; S3/S4 analogy |
| R05 | Commitments | Upcoming | — | Section/filter, not page | R01 | Home See all | Inspect due items | Post/skip | V1; S1 |
| R06 | Commitments | Estimate Details | — | Explanation sheet | R02 | Estimate info | Understand basis | Dismiss | V1-later optional; S4 chevron |
| I01 | Understand | Insights | I | Focused page | Home/Profile | Deeper link | Review deterministic patterns | Period/currency/scoped Activity | V1-later; inferred |
| P01 | Identity | Profile | P | Shell/tool directory | Shell | Profile tab | Open tool/preference | View local profile | V1; existing |
| P02 | Global | International Preferences | IP | Existing settings page | P01 | Preferences row | Edit preferences | Converter/reference rate | V1; not visible |
| P03 | Global | Currency Converter | FX | Existing utility | P02 | Converter row | Reference conversion | Swap/session favorites | V1; not visible |
| P04 | Global | Exchange Rates | — | Embedded Reference Rate card | P02/P03 | Existing card | View source/time/freshness | Existing refresh | V1; no dedicated page |
| P05 | Device | Appearance | AP | Existing customization page | P01 | Appearance row | Select theme | Preview | V1; S8 dark direction |
| P06 | Device | Notifications | N | Focused preference page | P01 | Preferences row | Reminder permission | OS settings/rule links | V1-later; S1 bell inferred |
| P07 | Identity | Cloud Account | CL | Identity/status page | P01 | Cloud row | Sign in/out | Identity/sync link | V1-later; roadmap |
| P08 | Identity | Sign In | — | Auth/provider flow | P07 | Sign in | Authenticate | Recovery/cancel | V1-later; not visible |
| P09 | Sync | Sync | SY | Status page | P07; P01 shortcut | Sync status | Retry/sync | Pending/error/conflict | V1-later; not visible |
| P10 | Sync | Resolve Conflict | — | Context detail/decision sheet | P09 | Action-required item | Resolve per entity policy | Inspect alternatives/cancel | V1-later; no generic overwrite |
| P11 | Protect | Security | SE | Preference page | P01 | Security row | Device access controls | Biometric/lock timing if supported | V1-later |
| P12 | Protect | Privacy & Data | PD | Preference/action page | P01 | Privacy row | Export/manage data | Delete/policy | V1-later |
| P13 | Protect | Export Data / Delete Data | — | Operation sheet + scoped confirmation | P12 | Explicit action | Export or scoped deletion | Cancel/progress/error | V1-later |
| P14 | Product | About | — | Small page | P01 | About row | Version/legal/help | Support/policy links | V1-later |
| P15 | Onboarding | Welcome | W | Existing setup flow | Launch | No local profile | Create local profile | Country/currency/language | V1; not visible |
| F01 | Wealth | Assets & Liabilities | WE | Overview with tabs | Future Profile | Wealth tool | Open asset/debt | Add/valuation update | V2; S6 |
| F02 | Wealth | {Asset name} | — | Detail page | F01 | Asset row | Review valuation | Edit/history/disposal | V2; implied |
| F03 | Wealth | Add Asset / Edit Asset | — | Type-specific form | F01/F02 | Add/edit | Save record | Valuation basis/source | V2; S6 + |
| F04 | Wealth | {Liability name} | — | Detail page | F01 | Liability row | Review obligation | Payment split/edit | V2; S2/S6 |
| F05 | Wealth | Add Liability / Edit Liability | — | Type-specific form | F01/F04 | Add/edit | Save record | Principal/interest fields | V2; implied |
| F06 | Wealth | Net Worth | — | Tab in F01 | F01 | Tab | Inspect assets minus debt | Valuation explanation | V2; S6 tab only |
| F07 | Money | Statements | — | Card child page | M06 | Future link | Review statement | Import/reconcile if approved | V2; S7 |
| F08 | Household | Family Wallet | FW | Shared-wallet landing/detail | Future Profile | Family tool | Open/create wallet | Members/activity/settings | V2; S8 |
| F09 | Household | Members / {Member name} | — | List/detail sheet | F08 | Member/avatar | Inspect role/activity | Authorized role/remove | V2; S8 |
| F10 | Household | Invite Member | — | Invite/acceptance flow | F08 | Invite/Add | Send/accept invitation | Revoke/resend | V2; S8 |
| F11 | Household | Wallet Activity | — | Scoped activity page | F08 | See all | Inspect shared event | Filter/member detail | V2; S8 |
| F12 | Household | Wallet Settings | — | Settings page | F08 | Gear | Manage permissions | Leave/archive | V2; S8 |
| F13 | Capture | Scan Receipt / Review Receipt | — | Capture/review flow | Future Add | Receipt action | Confirm before saving | Correct/cancel/delete receipt | First major V2; not visible |

M05/M09/P04/R02/R05/F06 are not standalone routes. Budget, goal, category and recurring editors reuse their existing forms. M06 specializes account detail. Separate Income, Expense, Bills, generic Settings and notification-inbox pages are not justified. No dead V1 menu items for future surfaces.

## 6. Title/subtitle registry

Section 5 contains all proposed English titles; these are the matching subtitles. Every dash in section 5 intentionally omits a subtitle.

| Code | Page | Exact proposed subtitle |
|---|---|---|
| H | Home | Your money at a glance |
| A | Activity | See your money in and out |
| AC | Accounts | See where your money is held |
| C | Categories | Organize your income and spending |
| B | Budgets | Plan your spending and stay on track |
| G | Savings Goals | Save toward what matters |
| R | Recurring | Plan for money that repeats |
| S | Subscriptions | Keep track of recurring expenses |
| I | Insights | Understand your spending patterns |
| P | Profile | Your preferences and money tools |
| IP | International Preferences | Set your countries, currencies, and formats |
| FX | Currency Converter | Check a reference conversion |
| AP | Appearance | Make the app feel like yours |
| N | Notifications | Choose your money reminders |
| CL | Cloud Account | Connect your account across devices |
| SY | Sync | Check what is saved across your devices |
| SE | Security | Control access on this device |
| PD | Privacy & Data | Manage your information and data |
| W | Welcome | Set up your money companion |
| WE | Assets & Liabilities | See what you own and owe |
| FW | Family Wallet | Manage money together |

**Superseded 2026-09-20 for codes A, AC, and CL -- see section 26.3:** the approved subtitle text is now "Your money history" (Activity), "See where your money is held and what you owe" (Accounts), and "Connect your account for cloud features" (Cloud Account). The rows above are left as historical record; do not implement the old wording for these three codes.

Home greeting can replace H; Profile identity card can replace P; Activity's selected period/filters usually replace A. Appearance's AP is optional. Show either Recurring explanation or Subscriptions explanation, not both stacked. FW belongs on a future landing page; wallet detail uses its name. Accounts, Budgets, Goals, Global preferences, protection and new Insights benefit most from purpose text. Forms/details generally need field help, not subtitles.

Detail rules: use user-assigned account/card/goal/rule name; show type/currency/date/masked digits as context. Budget detail uses Overall Budget or category name, with month/currency beneath. Transaction Details remains a stable title because merchant alone cannot identify an event. Create/Edit titles use the forms in the registry: Add for recorded items, Create for plans/rules/goals, Edit for changes. Use Record payment to avoid implying bank execution.

Localization: all titles/subtitles/actions/filters/statuses/tooltips/accessibility labels/errors/confirmations/empty states, counts and recurrence/date phrases require localized resources. Reuse existing English/Japanese ARB keys where semantics match. User names, notes, merchant names, ISO currency codes, masked digits and stored enum values are not translated. Seeded category labels use established mappings. Use placeholders/plurals, not concatenated English fragments. “Available credit” and “Available balance” must not share an ambiguous key. Explain the broad V1 meaning of Subscriptions in Japanese as well as English.

## 7. Home architecture

E: the reference uses one hero, four compact metrics/links and a bounded Upcoming list. Amount size gives immediate priority; Upcoming supplies action, not a second history feed. No full account list is visible.

X: current Home contains per-currency summaries, income/expense/daily pace, budget/goals quick-glance tiles, additional detailed budget and goal cards, Upcoming and a full account list. This duplicates planning content relative to the reference. Currency summaries prioritize living currency when present, then home and other currencies; a fallback hero must not falsely claim to be living currency.

R proposed V1 order:

1. Compact Home/greeting header. Avoid greeting plus subtitle plus motivational paragraph plus another large title.
2. Currency-labeled balance hero with visibility control and discoverable Accounts action.
3. Income/Expenses for the explicit current period/currency. Daily pace is supporting detail.
4. One Budgets summary and one Goals summary, each linking deeper.
5. Bounded Upcoming preview with urgent items first and See all → Recurring. Existing Home selects a priority item; a three-item seven-day version requires a selection-policy decision.
6. Secondary currency balances/equivalents with original values and FX freshness. Expansion may manage density but must not hide balances without a discoverable way to reveal them.
7. Optional deeper Insights link once real deterministic content exists.

Above-fold target at default text: greeting, primary balance, flow metrics, planning shortcuts and a hint of Upcoming. At 200% text this becomes a priority order, not a fixed-height promise. Keep capture/navigation accessible and let the page scroll.

| Item | Treatment |
|---|---|
| Total balance | Direct currency-specific hero; no new global combined figure |
| Income/expenses | Compact metrics → scoped Activity |
| Budget | One status/remaining summary → Budgets; pace/projection deeper |
| Goals | One summary → Goals; contributions/progress details deeper |
| Upcoming | One bounded section; overdue must not disappear under a future-only heading |
| Bills/subscriptions | Same Upcoming rows; no duplicate separate blocks |
| Accounts | Explicit shortcut; full replicated list removal requires approval |
| FX | Preserve existing secondary reference treatment, no accounting consolidation |
| Quick actions | Center Add plus relevant links, no all-feature grid |
| Visibility | Device-local display state applied to every sensitive Home value/accessibility label |
| +2.5% comparison | Omit until baseline/period semantics are defined |
| Bell/dot | No fictitious unread inbox; only expose supported notification surface |
| Wealth/household/OCR/AI | Absent from V1 Home |

Before credit rollout, approve the hero's balance inclusion policy. Current Home sums active account balances per currency. Recommended future liquid summary is explicitly “Cash & bank balance”, with card owed separate. That changes meaning and requires approval; it is not merely a title edit. Until decided, retain current calculations and do not insert liabilities into a misleading available-money hero.

## 8. Accounts architecture

X: current Accounts has type, currency, opening balance, active state and timestamps. UI offers cash/bank/card/wallet; FinanceEngine applies the same balance rules to these rows. No dedicated liability/credit-limit/instrument model was observed. A `card` label does not establish credit-card support. Rows currently do not navigate; creation is a dialog.

| Concept | Balance ownership | Recommended list treatment | Capture meaning |
|---|---|---|---|
| Cash | One liquid ledger | Cash/wallet group | Expense down, income up |
| Bank/savings | One liquid ledger | Bank group | Same liquid semantics |
| Existing wallet | Preserve current liquid semantics pending exact product definition | Cash/wallet group | Do not silently reinterpret existing records |
| Debit card | No balance; references bank | Nested instrument/metadata | Resolve to bank once |
| Credit card | Liability ledger plus safe instrument metadata | Credit cards / Owed group | Purchase raises debt; payment reduces debt and funding balance |
| Loan | Advanced liability | No V1 placeholder | V2 |
| Non-liquid asset | Valuation model | No V1 Assets tab | V2 Wealth |

Recommended hierarchy: liquid accounts first, currency explicit; credit cards owed second; debit metadata nested under bank. All / Cash & bank / Credit cards is enough when cards land. Search locally over names/safe metadata; optional currency filter later. A Cards view mixing debit and credit is viable only with unmistakable linked-bank versus owed semantics and no summation of instruments. Card carousel is optional and must not push ordinary accounts below the fold.

Account detail deserves a page for balance, scoped history, capture and editing. Credit-card detail specializes it; no separate collection page. Archived accounts retain history. Currency/type cannot be freely reinterpreted after postings. Migrating generic `card` records needs explicit classification/reconciliation, not inference from name or negative balance.

Future Wealth should be a separate overview, linked from Profile and contextually from Accounts. It reads Accounts by reference. Extensibility requires stable identities and correct boundaries, not speculative V2 tables or extra balances now.

## 9. Credit-card architecture

Minimum V1-later: issuer/nickname/network/optional last four; currency; reviewed opening-owed basis; derived owed; optional credit limit; derived available/utilization; scoped Activity; Record Payment; edit/archive. Statement/due metadata and reminders require an explicit date contract. No issuer connection, authorization feed or payment execution is implied.

| Event | Bank | Owed | Expense reporting |
|---|---|---|---|
| Start | 100,000 | 80,000 | Existing history only |
| Purchase 5,000 | 100,000 | 85,000 | +5,000 once |
| Bank payment 20,000 | 80,000 | 65,000 | No new expense |
| Card fee 1,000 | 80,000 | 66,000 | +1,000 once |

Payment is one atomic, linked transfer-like event. Edit/delete affects both sides consistently. Recurring debt repayment is transfer-like; a recurring purchase on credit is an expense. Interest/fees recorded as charges are expenses; payment principal is not.

Available = limit − owed; utilization = owed / positive limit. Reference arithmetic is consistent: 500,000 − 82,500 = 417,500; utilization 16.5%. Label manually tracked available credit, not issuer-confirmed funds. Missing/zero limit means no valid utilization, not 0%. Over-limit and overpayment need explicit text; clamp only the visual bar. Never silently erase negative availability or a credit balance.

Dependencies: liability sign convention; opening balances; canonical instrument/account relationship; currency validation; archived-source handling; atomic writes; Home/budget/Activity inclusion rules; recurring source resolution; reversible edits; legacy-card migration. FinanceEngine currently throws for unsupported refund/adjustment types. Card refunds/reversals and overpayments need an explicit release decision; don't disguise refunds as income.

Defer statements/imports/reconciliation, automatic interest/minimum-payment calculations, rewards, issuer sync, credit scoring and bank execution. Merge Card Details/Settings into safe metadata and Edit Card. No five empty subpages just to match S7.

Never request/store full PAN, CVV/CVC, PIN or banking password. Optional last four are display metadata, not authentication. A separately designed app-lock PIN belongs to Security, not card metadata.

## 10. Recurring/subscription architecture

X: ADR-023 defines schedule-only rules and explicit occurrence handling. ADR-031 implements Recurring/Subscriptions tabs, shared pending rows/post/skip/edit, currency-separated deterministic estimates and Add only on Recurring. `isSubscriptionRule` checks expense kind in an upstream active/non-deleted context; the predicate alone is not the full definition.

```text
Recurring — one page, one rules/occurrences engine
├── Recurring tab: expense / income / transfer pending items + shared create/edit
└── Subscriptions tab: active non-deleted expense-rule projection
    ├── Estimated costs per currency
    └── Most urgent pending occurrence per rule
```

All active recurring expenses, including rent/electricity, belong in V1 Subscriptions. Reference Bill/Subscription badges suggest a distinction V1 does not persist. Prefer recurring-expense/category labels where this distinction would mislead. Explicit opt-out/tag is V2 under ADR-031.

| Reference | Recommendation |
|---|---|
| All / Active | Redundant in active-only view; do not copy both |
| Upcoming | Occurrence timing lens, not lifecycle |
| Expired | Later lifecycle/history surface; cannot infer from no pending row |
| Search | Optional local rule-name filter |
| + on Subscriptions | Keep current Add on Recurring; same-editor shortcut needs explicit approval |
| Monthly/yearly | Existing frequency normalization and rounding; no invoice claim |
| Next | First relevant unhandled occurrence using schedule and handled records |
| Post/Skip | Explicit single-date handling; skip does not cancel rule |
| Edit | Shared rule editor; preserve handled history |
| Cancel | If added, stops local tracking, never merchant service |

Yearly estimates are computed independently, not rounded monthly × 12. The reference equality 8,760 × 12 = 105,120 is not a general invariant. Ended active rules may still have overdue items while excluded from forward estimates. Pending membership and estimate membership differ. No pending rows must not become “no active subscriptions”; ADR-031's addendum specifically corrected first-unhandled-future selection.

S3 Repeat needs explicit coordination: saving today's expense and creating a rule must mark/avoid a duplicate first occurrence. Immediate V1 retains the existing editor. Later offer explicit recurring setup with start-date confirmation; this is a behavior checkpoint, not styling. No subscriptions table, second scheduler or alternate accounting path.

## 11. Budget architecture

X: ADR-021 uses one budget table, nullable category for overall/category, currency + UTC year/month, exact-category matching and repository upsert uniqueness. Screen manages current month with dialogs. Domain already computes remaining, recommended daily spend, projected month-end and status. Reference month arrows and detail destinations are new behavior, not a new engine.

R: retain B01 overview and shared dialogs; proposed B02 detail adds scoped transactions/pace/edit. Month navigation is V1-later subject to approval. No rollover, weekly plans, arbitrary periods or second budget-category table.

- Overall is a whole-currency cap; category caps are independent, not additive children required to equal it. Never add overall and category limits together.
- Spent is expense-only, selected currency/month/exact category. Income/transfers do not count. Card purchase counts once; payment does not.
- Remaining = budget − spent, including negatives. Percent is derived; saturated bar retains overage text.
- Spending pace is actual spend per elapsed day; recommended daily spend is remaining allowance per remaining day. Keep existing distinct rounding rules.
- Projected month-end belongs in detail or subdued overview text, labeled estimate. Reuse multiplication-before-division arithmetic, not rounded daily display × days.
- Status sits beside overall/category summaries. Keep existing BudgetStatus thresholds; green reference bars do not define warning logic.
- Existing UTC month convention remains. Localized month labels must not change accounting boundaries. Future month has no elapsed-day projection; past-month behavior follows existing calculator.

V1 essentials: create/edit/remove, totals, progress and deterministic guidance with honest states. Month browsing/details are recommended additions, not already-approved behavior.

## 12. Assets/liabilities future architecture

E: three tabs, Total Assets hero, five asset rows. I: wealth spanning liquid and non-liquid value. R: V2 only under this task.

Visible row arithmetic is inconsistent: 462,000 + 1,000,000 + 12,000,000 + 350,000 + 0 = **13,812,000**, not **12,350,000**. Cash & Bank 462,000 does match S2 cash 12,000 + bank 450,000. Honda Vezel 2022 is a vehicle label under Property/Inventory. These are mockup inconsistencies, not balancing rules.

| V1 essential model | Future wealth model |
|---|---|
| Stable IDs, currency, opening balances, derived liquid balances | Asset type, acquisition, quantity/ownership, valuation history |
| Debit references bank with no balance | Non-liquid valuation source/time/basis |
| Essential credit liability semantics | Loans, principal/interest splits, deposits/maturity |
| Correct transfers/activity | Acquisition/disposal versus consumption |
| Currency-separated values/reference FX | Explicit valuation currency and dated conversion policy |
| Personal ownership | Shared ownership after household contract |

Future net worth = consistently valued assets − liabilities. Credit cards appear once; cash/bank read canonical ledgers. Do not persist net worth as independent truth. Property acquisition/deposit funding is asset reallocation, with fees classified separately. Loan principal reduction differs from interest expense. Goals/debit instruments must not duplicate assets.

Do not pre-create crypto/household/valuation schemas or V1 menu placeholders. Document 20's broader V1 list conflicts with this task and needs later document alignment, not implementation now.

## 13. Family Wallet future architecture

S8 implies shared ledger, wallet identity, owner, members, invites, funding/transfers and actor history. It does not prove an authorization model. Future owner/admin/member/view-only roles require an explicit permission matrix.

Dependencies in order:

1. Verified cloud identity distinct from local profile.
2. Reliable personal multi-device sync and idempotent writes before shared concurrency.
3. Wallet membership and server-enforced permissions on reads/writes.
4. Pending/accepted/expired/revoked invitations and identity-bound acceptance.
5. Conflict handling for concurrent money edits and role changes; revoked members cannot silently retain offline permission.
6. Audit events with actor/wallet/action/affected event/revision/time/correction links; notes are not an audit trail.
7. Explicit ownership semantics for member-to-wallet funding and personal/shared totals; contributions are not automatically household income.

Members/role sheets and shared Activity are justified. Add Money/Transfer reuse an ownership-aware money contract. Define currency, export/deletion/leave rights, offline pending status and revocation behavior before release. No V1 route, teaser or disabled Family Wallet CTA.

## 14. Navigation mapping

**Superseded 2026-09-20 -- see section 26.** This section's comparison and mapping tables describe and defend the previous Home/Activity/center Add/Profile shell as approved/locked. That shell has been replaced by the five-destination HOME/ACTIVITY/+ADD/ACCOUNTS/MORE shell recorded in section 26. The tables below are retained as historical record of the prior decision and its reasoning.

| Architecture | Strengths | Weaknesses |
|---|---|---|
| Reference: Home / Accounts / + / Budgets / More | One-tap access to balances and plans; highly visible capture; symmetric five-position bar | Activity is hidden; planning gets a permanent slot regardless of use; More mixes tools/settings; five labels constrain translation |
| Approved: Home / Activity / center Add / Profile | Transaction history and capture are always available; compact stable shell; existing implementation/tests | Accounts/Budgets need discoverable entry points; Profile can become a crowded tool directory |

R: preserve the approved architecture. Improve entry points, not bottom-tab membership. The current shell implements four destinations, Add at index 2 as an action. “Center Add” describes the approved emphasized action; it does not authorize adding a fifth slot for geometric symmetry.

| Reference destination/action | Approved-shell mapping |
|---|---|
| Home | Home tab |
| Accounts | Home explicit Accounts shortcut + existing Profile Accounts row |
| Add | Existing center action → type sheet → Add Transaction |
| Budgets | Home summary link + existing Profile Budgets row |
| More | Profile, keeping its existing name |
| Subscriptions | Home Upcoming → Recurring → Subscriptions tab; no new shell destination |
| Credit card | Accounts → card detail |
| Assets/Family | No V1 mapping; future Profile tools |
| Recent Transactions | Activity scoped to account/card, with filter context visible |
| Converter | Existing International Preferences entry; Home FX contextual entry only if explicitly approved |

Profile groups: Money tools (Accounts, Categories, Budgets, Goals, Recurring, later Insights); Preferences (International, Appearance, Notifications); Account & protection (Cloud Account/Sync, Security, Privacy & Data); About. These are sections, not additional nested hub pages. Keep frequent tools near the top so Profile is a directory, not a junk drawer.

X: only Home/Activity/Profile are currently inside ShellRoute at initial route inspection. Accounts/Budgets/Goals/Recurring/forms are pushed outside it. R: retain this stack pattern; do not copy persistent bottom navigation onto every detail screen just because S7 shows it. Back restores caller, filter and scroll where supported; new context links must preserve an explicit return path. Add is never a selected page after sheet dismissal.

## 15. User journeys

Existing behavior versus proposed changes is explicit. A modal is best for bounded selection/confirmation; a full page for substantial entry/history/auth. Cancel must preserve the caller and any unsaved draft where appropriate.

| Journey | Path and success destination | Sheet/page choices and accounting contract |
|---|---|---|
| Expense | Home → Add sheet → Expense form → Save → return Home; Activity tab → saved event | Current save pops caller. Requested direct Save → Activity is a proposed alternative requiring approval; recommend return-to-caller plus View in Activity action |
| Income | Home → Add sheet → Income form → Save → Home | Shared form; success updates income/balance once |
| Transfer | Proposed Account Detail → Transfer → source preset → destination picker → Save → Account Detail | Full shared form, destination sheet; same currency, distinct accounts; zero income/expense effect |
| Budget | Home → Budgets → proposed Budget Detail → Edit dialog → Save → detail | Current list edits already use dialog; detail navigation is an addition |
| Subscription | Home Upcoming/Profile → Recurring → Subscriptions → item sheet → Edit/Post/Skip | Existing row actions remain valid; post/skip confirmation is occurrence-specific; recompute next unhandled date |
| Savings | Home → Savings Goals → Goal → Contribution dialog → Save → Goal | Existing contribution is same-goal-currency progress recording; no account withdrawal or transaction is created |
| Credit card | Accounts → card detail → Record Card Payment → funding account → Save → card detail | Shared transfer-like form; destination fixed to liability; atomic bank/debt update; no second expense |
| Cloud | Profile → Cloud Account → Sign In → Cloud Account status → Sync | Auth must distinguish unavailable/failed/signed-in; sign-in is not proof all data synced; local tracking remains usable |
| FX | Profile → International Preferences → Converter → reference result | Source/time/stale states; no ledger write; favorites remain session-only |
| Future household | Profile → Family Wallet → members/activity → permitted action | Member detail/invite sheet; shared Activity page; authorization and offline status explicit |

Global failures: Save disabled while pending; error retains draft; missing/deleted referenced entity prompts re-selection; unhandled Back returns safely; auth cancellation never removes local finance data. Deletion confirmations name the object and consequences. Card/recurring edits must not silently rewrite historical postings. Goal contribution removal uses existing soft-delete/correction semantics; no new withdrawal operation is implied.

## 16. Reusable component system

X mappings below are observed classes/files, not a claim of visual parity. New candidates should compose existing primitives. Never place accounting arithmetic inside widgets.

| Candidate | Responsibility / variants | Consumers | Required semantics | Existing mapping |
|---|---|---|---|---|
| AppHeader | Title/greeting/back/search/action; root/detail/form | All | Heading, action labels, back target | Flutter AppBar; no shared custom AppHeader observed |
| MoneyHeroCard | Emphasize one scoped amount; liquid/wealth/shared variants | S1/S6/S8 | Currency, basis, loading/error/hidden state | AppCard + AppMoneyText; Home private hero exists |
| SummaryMetricCard | Small amount/status/navigation | S1/S4 | Period, currency, action versus static metric | AppCard/AppIconTile/AppMoneyText; existing Home private summaries |
| AppSectionHeader | Group title and optional action | S1/S2/S8/all lists | Semantic heading, unambiguous See all label | AppSectionHeader exists |
| FinanceListRow | Icon/name/metadata/amount/trailing action | Activity/S2/S4/S7/S8 | Full amount and row action; no invisible truncation | AppFinanceListRow exists; Accounts currently private responsive row |
| AccountCard/AccountRow | Account identity and scoped balance/owed | S2, account detail | Liquid/linked/debt distinction | AppCard + private _AccountsRow; evolve |
| CreditCardHero | Safe identity + owed/limit/availability | S2/S7 | Last-four label, owed semantics; no PAN fields | Compose AppCard/AppMoneyText/AppProgressBar; domain missing |
| ProgressRing | One ratio with textual equivalent | S5 | Used/limit/status, >100% text retained | No dedicated shared ring observed; optional, not prerequisite |
| ProgressBar | Used fraction with external amount/status | S5/S7/goals | Clamp visual only; announce real values | AppProgressBar exists |
| StatusChip | Meaningful textual state, semantic color | S1/S4/S5/S8 | Due/overdue/healthy/shared; not color-only | AppStatusChip exists |
| CategoryIconTile | Stable category identifier | S3/S5/Activity | Decorative when row already names category | AppIconTile + CategoryIcon mapping |
| SegmentedControl | Mutually exclusive views/types | S2/S3/S4/S6 | Selected state, focus, keyboard/large text | AppSegmentedControl exists; Recurring uses it |
| FilterChip | Optional query filter | S2/S4/Activity | Selection + reset/no-results behavior | AppFilterChip exists |
| UpcomingRow | Scheduled event preview | S1/R01 | Due date versus posted date; rule/occurrence identity | Existing Home upcoming + _PendingItemTile |
| SubscriptionRow | UpcomingRow with recurrence/estimate metadata | S4/R02 | Rule-derived status; source/category lookup | Existing shared _PendingItemTile; no duplicate engine |
| SelectorRow | Category/account/date choice | S3/all forms | Field label, current value, required/error state | Existing form controls; compose icon/list primitives |
| MoneyTextField | Currency-aware capture | Add/budget/goal/payment | Minor units, precision, overflow and input errors | MoneyTextField exists |
| MoneyText | Correct financial display | Every monetary surface | Full signed value/currency; hidden state handled outside | AppMoneyText hero/primary/secondary emphasis exists |
| MemberAvatar | Identity/role preview | S8 only | Name/role; no unproven presence indicator | New future component; do not build V1 |
| PrimaryActionButton | One clear action, busy/disabled variants | Save/payment/shared funding | Specific action, pending state, accessible target | Existing FilledButton/FAB; no new abstraction required solely for naming |
| Add action/FAB | Contextual add versus global capture | Shell/S2/S4/S5 | Distinguish Add Account/Rule/Budget/Transaction | Existing shell action/FloatingActionButton |
| BottomNavigation | Approved root switching + capture action | Shell | Home/Activity/Add/Profile; action is not route | AppShell exists; preserve membership/selection |
| Empty/Error/Loading | Independent truthful state | All | No-data versus unavailable; retry/setup action | AppEmptyState + AsyncValue handling; no need for one giant state widget |
| MonthNavigator | Selected monthly scope | B01 proposed | Previous/next month announcements; boundaries | New presentation over BudgetMonth, behavior approval needed |
| ReferenceRateCard | Secondary rate/source/time/staleness | Global/Home reference context | Reference-only, not execution promise | Existing reference_rate_card.dart |

Reuse semantic responsibilities, not every screenshot shape. Brand logos and decorative colors are not financial status. AppCard should remain a surface primitive; don't make it fetch balances. Keep row-specific date/account metadata in feature presentation adapters.

## 17. Visual design-language specification

No exact token values are inferred from a scaled composite. Existing AppTokens/AppTypography/AppTheme provide the implementation baseline; this is a relative target specification.

| Dimension | Visible evidence | Recommended production rule |
|---|---|---|
| Spacing | Comfortable outer gutters; tight within related labels; larger between groups | Use existing spacing scale; section gap > row-label gap. Avoid repeated nested padding shrinking content |
| Corners | Rounded phone frames, large hero corners, smaller row/icon corners, pill selections | Hero radius > grouped list radius > icon tile radius; pill only for compact controls/status |
| Card hierarchy | One strong hero; pale summaries; white grouped lists | Three levels maximum; most rows share a group surface rather than each becoming a floating card |
| Shadows | Soft card/blue-card elevation, no heavy row shadow | Reserve elevation for hero/action; borders/tonal contrast for routine groups |
| Type | Bold page titles; largest amounts; semibold names; small muted metadata | Preserve clear heading/money/body/caption roles; metadata cannot become illegible to mimic density |
| Money | Prominent ¥ values, aligned trailing rows; owed labels | Use real currency formatter; tabular digits if supported; full exact amount on relevant surface |
| Icons | Colorful rounded tiles and thin navigation glyphs; brand logos | Consistent icon weight/size by role; optional logos with fallback, never require remote logo fetch to capture money |
| Accents | Strong blue actions; pink expense/save; green income/progress; purple/cyan planning | Theme-derived action and semantic palettes; expense color does not automatically mean an error |
| Status | Small colored pills and green progress | Pair every semantic color with text/icon; decorative category color never overrides warning state |
| Gradients | Pale blue/lilac background; saturated blue card; mint assets | Restrained ambient wash and limited hero gradients, not every row |
| Selection | Blue filled pills, pale track/unselected text | Selected state needs shape/contrast and accessibility state, not color alone |
| Navigation | Muted unselected glyphs; blue active; elevated circular + | Apply this emphasis to existing four-control shell; no fifth slot |
| Lists/separators | Dense but grouped rows; hairline indented separators | Let metadata wrap/stack; preserve amount legibility; avoid double dividers/card borders |
| Whitespace | Local breathing room around summary and groups | Favor progressive disclosure over cramming additional cards |
| Light theme | White/near-white surfaces over pastel background | Test actual contrast on tinted surfaces; screenshots do not prove contrast compliance |
| Dark theme | S8 uses near-black canvas, dark teal/slate cards, bright blue actions | Extrapolation to other pages is recommendation, not visible evidence; use semantic dark tokens, lighter separators, restrained shadows |

Dark mode is a theme across the product, not a Family Wallet-only mode. The project already offers Light/Dark/Pink/Ocean/Forest; do not delete these or hardcode the reference palette. Monetary/status semantics must remain stable across themes. Decorative sun/card texture is optional and must not carry essential information. Motion should be restrained, respect reduced-motion preferences, and never imply a network payment succeeded.

## 18. Responsive/localization risks

| Risk | Fragile reference area | Recommended acceptance behavior |
|---|---|---|
| Japanese | Small subtitle lines, status badges, English month names | Test natural Japanese copy, glyph metrics and line breaks; currency/date via existing locale policy |
| Longer translations | Five Accounts filters; four subscription filters; side-by-side actions | Wrap or scroll controls with discoverable selection; use fewer V1 filters; no fixed text widths |
| 200% text | Hero metrics, two-column shortcuts, amount/label rows | Stack columns and grow height; no text-scale clamp or shrinking essential amounts |
| Narrow Android | Screenshot is iOS-shaped; pinned footer and tiny captions | Validate Android safe areas/system back/keyboard; page scroll and footer must not cover last row |
| Zero-decimal currency | Reference only shows yen | JPY/KRW no forced .00; parser follows currency metadata |
| Three-decimal currency | Compact price/frequency rows | KWD precision retained, not rounded to two decimals for fit |
| Large values | Right-aligned balances, card owed/available pair | Stack and allow full readable values; don't ellipsize digits or rely on tiny font. Extreme values may need dedicated value detail |
| Negative liability/credit | Loan minus sign versus positive owed card | Label Owed/Credit balance/Over limit; define sign presentation separate from ledger sign |
| Mixed currencies | Single hero and estimates | Separate currency groups; symbol alone insufficient; approximate FX result explicitly secondary |
| RTL future | Chevrons, date navigation, amount/icon order, masked digits | Directional padding/back controls; isolate currency codes/digits; don't reverse logos or numeric tokens |
| Screen readers | Icon-only eye/+; ring percentages; duplicate amount readouts | Meaningful labels, selected states, grouped reading order; hidden money must also be hidden from semantics |
| Date/time | Home next-seven-days versus August capture and September rows | Date labels describe actual selected scope; current UTC accounting convention remains until approved change |
| Long names/notes | Merchant + category chip + amount | Move badge below name; full name/detail available; don't truncate account identity beyond recognition |
| Keyboard/focus | Save button near lower edge | Scroll focused field into view; preserve draft on resizing; logical traversal |
| Large desktop/tablet | Stretched phone list | Constrain reading width; optional master/detail later, same routes/data rather than new architecture |

Visually attractive but fragile: fixed-aspect credit card with two money columns; dense merchant rows; five filter pills; tiny category chips; carousel above the account list; four avatars plus Add; round percentage text; overly pale secondary text. No live rendered accessibility audit was performed. Existing responsive tests are evidence of prior effort, not proof these new arrangements pass.

## 19. Screen data-requirement matrix

Classification describes authority, not just transport: **STORED** = durable source fact; **DERIVED** = reproducible calculation; **CACHED** = replaceable copy; **REMOTE** = external/server authority; **DEVICE-LOCAL** = local UI/device setting. A synced source fact remains STORED with remote replication; a cache must not become authoritative history.

| Screen/value | Class | Required sources / formula | Boundary and failure behavior |
|---|---|---|---|
| S1 greeting name | STORED | Local profile display name | User content, not translated |
| S1 greeting time | DEVICE-LOCAL → DERIVED | Device time + greeting policy | Not accounting period policy |
| S1 balance | DERIVED | Opening balances + non-deleted ledger effects, active scope, per currency | No current-balance truth column; unavailable ≠ zero |
| S1 income/expense | DERIVED | Period/currency filtered ledger | Transfers excluded |
| S1 month delta | DERIVED, not currently established | Comparable opening/prior/current period balance definitions | Omit until baseline/zero-baseline policy approved |
| S1 budget status | DERIVED | BudgetCalculator and scope | Loading must not falsely imply no plan/on track |
| S1 goal count/progress | DERIVED | Active goal records + contribution ledger | Explicit completed/active definition; no extra account asset |
| S1 upcoming | DERIVED | Rules + schedule + handled occurrences + date window | Unposted forecast, not ledger spending |
| S1 privacy eye | DEVICE-LOCAL | Proposed visibility preference | Presentation only, not encryption |
| S1 bell badge | DERIVED only with real source | Actual notification inbox if ever built | No source today; don't fabricate unread count |
| S2 account name/type/currency/opening | STORED | Accounts and currency metadata | Existing generic card type is semantically ambiguous |
| S2 account balance | DERIVED | FinanceEngine | No mixed-currency addition |
| S2 debit link | STORED, future essential model | Instrument → bank ID; safe metadata | No instrument balance; missing link is an error |
| S2/S7 card issuer/network/last four/limit | STORED, proposed | Safe manually entered metadata | No full PAN/CVV/PIN; limit optional |
| S2/S7 amount owed | DERIVED, proposed | Opening liability + charges − payments with approved reversals | Never independently editable current debt without reconciled event |
| S7 available/utilization | DERIVED | Limit − owed; owed / positive limit | Missing limit suppresses ratio; overflow/credit balance explicit |
| S7 recent transactions | STORED records, DERIVED query | Account-scoped transaction list | No second card ledger feed |
| S7 payment | STORED event | Atomic transfer-like ledger operation | Derived balances update; no expense duplication |
| S7 statements | STORED/REMOTE future | Actual imported/manual statement records | No fabricated statement from current balance |
| S3 draft fields | DEVICE-LOCAL, transient | Form state/pickers | Become STORED transaction only on successful save |
| S3 amount/currency/date/note/category/source | STORED after save | Validated transaction fields | Fixed minor units; no floating-point money |
| S3 Repeat | Proposed STORED rule + occurrence relationship | Shared recurring repository | No independent subscription event engine |
| S4 rule name/amount/frequency/start/end/source/category | STORED | Recurring rule | Source/category names are lookups, not copies of truth |
| S4 next due | DERIVED | Anchor schedule + handled occurrence state | First relevant unhandled date; not persisted next-date truth |
| S4 posted/skipped | STORED handled facts | Rule/date/status + linked posting | Idempotent handling, no duplicate expense |
| S4 estimated monthly/yearly | DERIVED | RecurringEstimate, per-rule rounding and currency grouping | Yearly independent of monthly rounded value; excludes ended forward schedules |
| S4 logo | DEVICE-LOCAL asset or optional CACHED presentation | Approved bundled icons/fallback | No remote merchant integration implied |
| S4 selected filter/search/tab | DEVICE-LOCAL transient | UI state | Must not alter rule lifecycle |
| S5 month and limit | STORED budget; DEVICE-LOCAL selected view | Currency/year/month/category key and integer amount | Month selection isn't a new budget write |
| S5 spent/remaining/percent | DERIVED | Expense-only matching; limit − spent; ratio | Overall/category scopes not additive |
| S5 pace/projection/status | DERIVED | Existing BudgetCalculator/FinanceEngine | Future month not applicable; preserve UTC and rounding |
| Goals target/name/currency/date | STORED | SavingsGoals | Stable target currency; not current FX equivalent |
| Goals contributions | STORED | Append-only progress ledger, soft deletion | Same currency; no transaction/account movement in current V1 |
| Goals saved/remaining/milestones | DERIVED | Active contributions + target | Don't store saved/progress independently |
| Global countries/currencies/formats | STORED preferences | Local profile | Display changes don't rewrite historical money |
| Reference FX | REMOTE → CACHED | Provider pair/rate/source/provider time/fetch state | Replaceable reference cache; unavailable/stale labels |
| Reference equivalent/converter result | DERIVED | Exact converter + cached/reference rate | Approximate/reference output, not ledger posting |
| Historical FX snapshot | STORED immutable fact when used | Original/converted money + execution snapshot | Current table reserved; don't use current cache to rewrite it |
| Favorite pairs | DEVICE-LOCAL session state | Existing provider | ADR-028: no durable favorites in V1 |
| Appearance/language | DEVICE-LOCAL policy; currently stored preferences | Theme/locale state | ADR-032 treats these as not required to sync in V1 |
| Notification permission/schedule IDs | DEVICE-LOCAL | OS permission + local scheduler | Not authoritative rule schedule or unread feed |
| Insights | DERIVED | Ledger/budget/goal facts, period/currency | Deterministic, evidence-linked, no stored AI truth |
| Cloud identity | REMOTE authority + STORED local link | Verified server subject distinct from profile UUID | Unavailable provider cannot imply successful sign-in |
| Sync status | STORED sync metadata + DERIVED queue/session presentation | Revision/ack/pending/conflict contract | Local save != server acknowledgment |
| Security | DEVICE-LOCAL protected state | OS biometric/device lock settings, secure credential storage | Tokens never in finance tables or logs |
| S6 asset acquisition/valuation | STORED, future | Asset identity, original cost, valuation/source/time | Manual value is a fact at a date, not guaranteed market truth |
| S6 asset totals/net worth | DERIVED, future | Non-duplicated valued assets minus liabilities | Incomplete/stale valuation cannot present exact complete wealth |
| S6 crypto market price | REMOTE/CACHED only if later approved | Explicit pricing integration | Not part of V1 or guaranteed V2 feature |
| S8 member/role/invite | REMOTE authority + STORED synced projection | Identity/membership/permission records | Server authorization; offline cache not permission grant |
| S8 shared balance | DERIVED | Ownership-scoped shared ledger | Show pending/stale status; no independent stored balance |
| S8 activity/audit | STORED + REMOTE/SYNCED | Actor/event/revision/action records | Preserve attribution/corrections; access-controlled |

Common rule: raw facts are local-first where supported, derived values recompute, reference data may be cached, device-only state stays separate. A cached aggregate may be an optimization later, never a new source of truth. No storage additions are authorized by this matrix.

## 20. Current-project gap analysis

Method: static inspection of the working tree, route registrations, feature screens/providers, finance engine, schema declarations, shared widgets and relevant ADRs. This is not a running-app test or certification. **DONE** below means the named bounded capability is present in inspected source, not that final visual convergence/release QA passed. **PARTIAL** means foundation present with stated gaps. **V1 REMAINING** means proposed/roadmap capability not complete. **V2** means deferred by this task. **NOT PLANNED** means no supported product requirement/integration should be inferred.

Working-tree caution: initial HEAD was `9265065b408aeae318b282487efecbbdea595ebc`. At first inspection, docs 14/21 and database files were already modified, with cloud identity/account files untracked. Further cloud routes/UI/localization/tests changed during this audit independently of this documentation work. Cloud findings are a moving snapshot. Initial route inventory is distinguished from later cloud additions; do not use this report to overwrite those changes.

| Reference capability / related V1 need | Status | Evidence and gap | Evolution path |
|---|---|---|---|
| Approved Home/Activity/Add/Profile shell | DONE | AppShell and initial app_router registration; Add opens sheet | Restyle existing shell only; no destination changes | **Superseded 2026-09-20 (see section 26): the approved destination set changed to HOME/ACTIVITY/+ADD/ACCOUNTS/MORE; this DONE status describes the previous shell, still the one actually implemented at HEAD.** |
| Home balance/flow metrics | DONE foundation; PARTIAL target | home_screen.dart + dashboard_providers.dart, currency-separated summaries | Keep calculations; simplify repeated blocks after approval |
| Home budget/goal summaries | DONE foundation; PARTIAL target | Existing quick-glance and full cards | One summary per planning concern, not rebuild |
| Home upcoming | DONE priority preview; PARTIAL S1 list | Existing recurring selection/provider and Home card | Preserve selection first; bounded multi-row policy later |
| Visibility eye | V1 REMAINING | No corresponding control observed in Home inspection | Local masking contract across related values/semantics |
| +2.5% prior-month comparison | V1 REMAINING if approved; optional | No approved comparison basis found | Omit until defined; not a release blocker by itself |
| Bell unread inbox | NOT PLANNED | Local reminders exist, inbox/unread model not evidenced | Do not fabricate badge |
| Accounts liquid list/create | DONE foundation; PARTIAL S2 | accounts_screen.dart, account_repository.dart; cash/bank/card/wallet chooser | Evolve list/dialog; safe metadata and detail next |
| Account detail/edit/search/type filters | V1 REMAINING proposal | Current account rows do not navigate; no initial account detail route | Add bounded page/actions, preserve history |
| True debit instruments | V1 REMAINING | No linked-bank instrument model in inspected Accounts table | Isolated accounting/model checkpoint |
| True credit liability/detail/payment | V1 REMAINING | Generic card type cannot express limit/instrument semantics; S7 absent initially | Isolated domain work then detail visual specialization |
| Transaction Add/detail/edit | DONE foundation; PARTIAL S3 visual | add_transaction_screen, transaction_detail_screen, edit_transaction_screen | Evolve shared form; don't rewrite ledger |
| Inline type segments | PARTIAL visual candidate | Existing Add type sheet; component exists | Behavior approval before replacing/adding inline switch |
| Add Repeat toggle | V1 REMAINING optional | Recurring exists separately; not observed in Add form | Define first-occurrence coordination before UI |
| Activity | DONE foundation | Activity screen/filter providers; existing details/edit routes | Keep as canonical event list; add scoped links if needed |
| Subscriptions view/estimates/post/skip | DONE foundation; PARTIAL S4 visual | recurring_screen.dart, subscription_providers.dart; ADR-031/addendum | Same tab/shared row; no independent module engine |
| Subscription All/Active/Expired states | V2 for broader lifecycle/filter model | Current active expense projection; exact reference taxonomy conflicts | Preserve current definition; no artificial status fields |
| Subscription category/logo decoration | PARTIAL | Existing shared rows; CP11 explicitly deferred category icon enrichment | Optional display-only work after data/performance review |
| Recurring local reminders | DONE foundation | notification_providers, recurring_notification_providers, ADR-024 | Global preferences page still a separate V1 UI need |
| Budgets current-month create/edit | DONE foundation | budgets_screen and repository, ADR-021 | Evolve existing page/dialogs |
| Budget remaining/pace/projection/status | DONE domain | BudgetCalculator/FinanceEngine; status healthy/caution/overBudget | Expose consistently, don't invent thresholds |
| Budget month browsing/detail/ring | V1 REMAINING proposal | Current-month-only screen; no initial detail route/shared ring | Page behavior before decorative ring; ring optional |
| Savings goals/detail/contributions | DONE foundation | Goals screens/repositories, ADR-022 | Visual evolution, same contribution semantics |
| Categories management | DONE foundation; PARTIAL complete CRUD review | categories_screen/repository and selector usage | Preserve existing page; inspect exact edit/archive behavior before later work |
| International preferences/English-Japanese | DONE foundation | international_preferences_screen, l10n ARBs and locale infrastructure | Reuse; new copy/layout requires locale QA |
| Converter/reference FX/cache | DONE frozen V1 surface | ADR-025–029, core/fx, currency_converter_screen | No new FX page/engine/history feature |
| Appearance/theme system/shared primitives | DONE foundation | AppTokens/AppTypography/AppTheme, shared widgets, theme screen | Reuse rather than second design system |
| Deterministic Insights destination | V1 REMAINING | Deterministic calculations exist, no initial Insights route | Focused evidence-linked page; no AI |
| Cloud account | PARTIAL, concurrent work | New cloud_identity/cloud_account code observed; unavailable production provider explicitly reports not configured | Evolve ongoing work; never claim fake auth is complete |
| Multi-device sync | V1 REMAINING | docs/21 and ADR-032 contract; identity files are not sync proof | Separate server/transport/conflict/retry checkpoints |
| Security/Privacy/Data/About surfaces | V1 REMAINING | Roadmap/docs specify responsibilities; not in initial route inventory | Dedicated scoped work and release checks |
| Advanced loans/deposits/property/crypto/net worth | V2 | S2/S6, document 20 future model; task deferral wins | No V1 implementation |
| Statements | V2 proposed | S7 menu only; no actual statements model evidenced | Later reviewed scope |
| Family/shared wallet | V2 | S8/document 20; no deployed shared permissions evidence | After identity/sync/authorization |
| OCR | V2 first major feature | ADR-029 explicitly defers | No V1 Add scanner affordance |
| AI coach / bank integration | V2 or later, not V1 | User explicitly defers | No implied spending analysis by AI or bank execution |
| Provider cancellation / payment execution / real-time issuer data | NOT PLANNED by this reference | Logos/buttons do not establish integrations | Exclude unless separately approved |

Source register (repository-relative links, read-only evidence):

- [Project rules](../CLAUDE_PROJECT_INSTRUCTIONS.md), [master blueprint](00_MASTER_BLUEPRINT.md), [decision log](14_DECISION_LOG.md), [scope](01_MVP_SCOPE.md), [roadmap](10_ROADMAP.md), [private beta plan](19_PRIVATE_BETA_BUILD_PLAN.md), [documentation precedence](DOCUMENTATION_INDEX.md).
- [Account/wealth/household architecture](20_ACCOUNTS_ASSETS_HOUSEHOLD_ARCHITECTURE.md), especially sections 1, 8 and 10; [cloud/sync architecture](21_CLOUD_SYNC_ARCHITECTURE.md), especially account separation, conflict policy and device-local exclusions. These files were not changed by this audit.
- [Routes](../lib/core/routing/app_routes.dart), [router](../lib/core/routing/app_router.dart), [shell](../lib/shared/widgets/app_shell.dart).
- [Home](../lib/features/dashboard/presentation/home_screen.dart), [dashboard providers](../lib/features/dashboard/presentation/dashboard_providers.dart), [Accounts](../lib/features/accounts/presentation/accounts_screen.dart), [Profile](../lib/features/settings/presentation/settings_screen.dart).
- [FinanceEngine](../lib/core/finance/finance_engine.dart), [tables](../lib/core/database/tables.dart), [Add Transaction](../lib/features/transactions/presentation/add_transaction_screen.dart), [Activity](../lib/features/transactions/presentation/activity_screen.dart).
- [Budgets](../lib/features/budgets/presentation/budgets_screen.dart), [budget calculation](../lib/features/budgets/domain/budget_calculation.dart), [budget status](../lib/features/budgets/domain/budget_status.dart).
- [Recurring](../lib/features/recurring/presentation/recurring_screen.dart), [subscription projections](../lib/features/recurring/presentation/subscription_providers.dart), [goal detail](../lib/features/goals/presentation/goal_detail_screen.dart), [contribution repository](../lib/core/database/repositories/savings_goal_contribution_repository.dart).
- [Reference rate card](../lib/features/settings/presentation/reference_rate_card.dart), [converter](../lib/features/settings/presentation/currency_converter_screen.dart), [shared widgets](../lib/shared/widgets), [theme system](../lib/shared/theme), [unavailable cloud auth provider](../lib/core/cloud_identity/unavailable_cloud_auth_provider.dart).

Existing test filenames include shell, Home, Accounts, transactions, budgets, goals, recurring/subscriptions, FX, localization and shared primitives. Their presence corroborates implementation investment; results were not rerun or claimed here. Some source comments refer to older beta stages or stale ADR numbers; implementation and the current ADR subject matter were used instead of relying on comments alone.

## 21. Proposed V1 page tree

**ONE proposal, subject to section 25 approval.** Existing approved shell remains unchanged. **Superseded 2026-09-20 -- see section 26.3 for the canonical V1 page tree under the newly approved five-destination shell.** The tree below still nests everything under the previous four-destination shell (Profile as the fourth branch) and is retained as historical record. “Later” is a V1 implementation checkpoint, not a V2 feature. No speculative routes should be registered before working pages exist. Cross-links point to the same canonical page; they do not clone it.

```text
First launch → Welcome / local onboarding

APP SHELL (unchanged)
├── HOME
│   ├── Currency balance + flow metrics
│   ├── Accounts shortcut ────────────────────→ Accounts below
│   ├── Budget / Goal summaries ──────────────→ Budgets / Savings Goals below
│   ├── Upcoming ────────────────────────────→ Recurring below
│   └── Insights link [V1-later] ─────────────→ Insights below
├── ACTIVITY
│   ├── Search / filters / period / account scope
│   └── Transaction Details
│       └── Edit Transaction (page); Delete (confirmation)
├── CENTER ADD (action, not page)
│   └── Type sheet: Expense / Income / Transfer
│       └── Add Transaction (page; shared selectors)
└── PROFILE
    ├── Local profile summary
    ├── Money tools (group, not page)
    │   ├── Accounts
    │   │   ├── Add Account (dialog/adaptive editor)
    │   │   ├── Account Detail [V1-later]
    │   │   │   ├── Account-scoped Activity (same Activity data/view)
    │   │   │   ├── Add/Transfer (same transaction form)
    │   │   │   └── Edit/Archive (form/confirmation)
    │   │   ├── Linked Debit Card metadata [V1-later]
    │   │   └── Credit Card Detail (account variant) [V1-later]
    │   │       ├── Record Card Payment (shared transfer-like form)
    │   │       └── Edit Card (safe metadata form)
    │   ├── Categories → Add/Edit (dialogs)
    │   ├── Budgets
    │   │   ├── Current overview; month navigation [V1-later proposal]
    │   │   ├── Budget Detail [V1-later] → scoped Activity
    │   │   └── Create/Edit overall/category budget (shared dialogs)
    │   ├── Savings Goals
    │   │   ├── Create Goal (dialog)
    │   │   └── Goal Detail → Contribution / Edit (dialogs)
    │   ├── Recurring
    │   │   ├── Recurring tab → shared Create/Edit rule dialog
    │   │   ├── Subscriptions tab → per-currency estimates
    │   │   └── Occurrence/rule detail sheet [V1-later]; Post/Skip confirmations
    │   └── Insights [V1-later] → scoped Activity/Budget details
    ├── Preferences (group)
    │   ├── International Preferences
    │   │   ├── Existing Reference Rate card
    │   │   └── Currency Converter + session favorites
    │   ├── Appearance
    │   └── Notifications [V1-later]
    ├── Account & protection (group)
    │   ├── Cloud Account [V1-later; ongoing work]
    │   │   ├── Sign In / supported auth recovery
    │   │   └── Sync status → contextual conflict resolution when needed
    │   ├── Security [V1-later]
    │   └── Privacy & Data [V1-later] → Export / scoped Delete confirmations
    └── About [V1-later]
```

The tree deliberately contains no Wealth, Loan, Statement, Family Wallet, Receipt OCR, AI or bank-integration page. Credit-card essentials are V1 only after domain readiness. Account/budget detail surfaces are compact additions; short editors remain modal. If constrained to a smaller release, defer optional ring/search/extra detail presentation rather than weaken accounting, sync or privacy requirements.

## 22. Proposed V2 expansion tree

Future expansion is separate from the V1 tree; inclusion here does not approve implementation or guarantee a release date. **Cross-reference 2026-09-20 -- see section 26.6**, which maps each item below onto the newly approved five-destination shell without requiring another shell redesign.

```text
V2 expansion
├── FIRST MAJOR FEATURE: Receipt OCR
│   └── Add → Scan/Import Receipt → Review extracted fields
│       ├── Correct amount/currency/category/date
│       ├── Explicit confirmation → shared transaction save
│       └── Receipt detail / attachment / deletion-retention controls
├── Profile → Family Wallet
│   ├── Shared wallet landing/create/select
│   ├── Wallet Detail: balance / Add Money / Transfer
│   ├── Members → member detail / permitted role changes
│   ├── Invite → accept / expire / revoke
│   ├── Shared Activity → audit-aware event detail
│   └── Wallet Settings → access / leave / archive / conflicts
├── Profile → Assets & Liabilities
│   ├── Assets tab
│   │   ├── Cash & Bank (reference to existing Accounts)
│   │   ├── Fixed Deposit → maturity/valuation detail
│   │   ├── Property / Vehicle / Inventory → type-correct detail
│   │   ├── Crypto (only if separately prioritized; no assumed live pricing)
│   │   └── Other Assets → manual valuation with dates/basis
│   ├── Liabilities tab
│   │   ├── Credit Cards (reference existing card liabilities)
│   │   ├── Loans → principal/interest payment split
│   │   └── Other Liabilities
│   └── Net Worth → inclusion/valuation/source explanation
├── Credit Card Detail → Statements [separately scoped]
├── Recurring → explicit subscription tag/opt-out and richer lifecycle history
└── Later, separate product decisions
    ├── AI coaching over deterministic results
    ├── Bank integrations / statement import and reconciliation
    └── Expanded FX only after reopening ADR-029 freeze
```

Do not bundle household, wealth, AI or bank integrations into the OCR checkpoint. Each requires different data/security/reconciliation work. Advanced valuation and shared ownership must reference existing money rather than create competing ledgers.

## 23. Architecture conflicts + reconciliations

| Reference suggests | Current architecture/task says | Risk | Recommended reconciliation |
|---|---|---|---|
| Five bottom positions: Home/Accounts/+/Budgets/More | Locked Home/Activity/Add/Profile | Silent navigation replacement | Keep shell; map Accounts/Budgets through summaries/Profile | **Superseded 2026-09-20 (see section 26): this conflict is resolved by the approved five-destination shell, which gives Accounts its own tab; Budgets remains a linked page, not a tab.** |
| Bottom bar persists on account/card details | Existing non-shell pushed pages | Route-stack behavior changes disguised as styling | Keep pushed pages/back; any shell expansion needs approval |
| Debit Card row has ¥0 | Debit instrument has no separate balance | Duplicate balances or false “empty card” | Show linked bank name, no debit amount |
| Card owed displayed like positive bank balance | Credit is liability; current generic card is not typed debt | Sum debt as cash or double-count instrument | Approved liability model and explicit Owed group |
| Single Total Balance | Current per-currency active-account sums; FX freeze | Mixed currencies or changing inclusion basis | Keep currency grouping; approve liquid-only hero before card launch |
| Pay/Transfer menu | Payment is record, not bank execution | Double expense or false payment execution promise | Record Card Payment, atomic transfer-like operation |
| Refund/overpayment not shown | Current engine rejects undefined refund/adjustment semantics | Incomplete real-world card lifecycle | Decide explicit supported treatment before card release |
| Separate Subscriptions page, All/Active/Expired | ADR-031 active non-deleted recurring expenses, tab | Second engine or silent lifecycle definition change | Keep tab/shared rule/occurrence model; defer richer lifecycle |
| Bill versus Subscription badges | Every active recurring expense qualifies | Invented merchant classification | Use honest recurring/category labels; tag/opt-out V2 |
| + visible on Subscriptions | Current Add only on Recurring tab | Unapproved creation-path change | Retain current entry; optional shared-editor shortcut in approval list |
| Repeat (Subscription) in Add | Separate rule creation/explicit posting | Today's expense posted twice | Define first occurrence; keep off until reviewed workflow |
| Month arrows in Budgets | Current screen current-month only | Broader editing/date scope introduced as visual change | Explicit V1-later browsing proposal, same month engine |
| Category bars all green | Pace-based healthy/caution/overBudget | Misleading status | Keep existing status rules and accessible text |
| Single subscription total / annual ×12 | Existing per-currency independently rounded estimates | False aggregation/rounding drift | Keep existing estimate implementation |
| S6 Wealth and S2 loan in account UI | User defers advanced wealth/loans | Scope creep | V2 tree only; no V1 placeholders |
| Document 20 section 8 calls loans/deposits/property/crypto V1 | This request explicitly defers them | Conflicting future implementation instructions | Flag alignment for owner approval; do not edit doc 20 here |
| Older blueprint/scope/roadmap includes receipts before cloud | ADR-029/task: OCR first major V2 | Wrong implementation priority | Follow current scope; align older docs later |
| Family Wallet visible alongside V1 pages | Household explicitly V2 | Sharing before verified auth/sync/permissions | Separate future architecture and dependencies |
| Saving goal money may look like account transfer | ADR-022 contributions create no Transactions row | Duplicate or unintended account movement | Keep progress-ledger semantics and explain in contribution UI |
| Save expense → Activity requested journey | Existing Add save pops caller | Unapproved navigation behavior change | Document both; recommend caller return + View in Activity; owner decides |
| Greeting/timezone/localized dates | Existing UTC financial period boundaries | Localization quietly changes totals | Formatting only now; timezone-accounting changes separately approved |
| +2.5% growth and unread bell | No established comparison/inbox model | Fabricated product claims | Omit until real data/policy exists |
| Assets hero total differs from visible rows | Deterministic source-derived totals | Copying inconsistent sample data | Treat values as illustrative only; never add adjustment to force match |
| Sample screens appear one journey | Dates/amounts differ across views | Assume screenshots are synchronized ledger evidence | Use each as separate UI state, not a reconciled account dataset |
| Derived values shown prominently | Financial truth from stored facts + engine | Store/edit totals independently | Recompute all balances/progress/estimates |
| Dark Family Wallet looks premium/exclusive | Themes apply across the product | New theme or locked dark-only feature | Extend existing tokens; no special dark-only architecture |

Sample-data note: S1's Sep 18–22 dates can fit a seven-day interval, so that list alone is not contradictory. The composite does not establish a single shared “today”: Add/Budgets show August, subscriptions show September/January, and Amazon Prime has different next dates in S1 and S4. Do not infer period calculations or linked ledger state from those examples.

## 24. Recommended implementation sequence

No implementation is performed here. Sequence prioritizes existing reusable surfaces and separates financial/security changes from visual work. Each checkpoint ends with a reviewable diff and relevant existing checks; do not combine a migration with a broad restyle.

| Order / checkpoint | Scope | Reference screens sharing work | Risk / acceptance gate |
|---|---|---|---|
| 0. Product decisions | Resolve section 25, especially hero meaning/card scope/Home changes | All | Documentation decisions only; don't declare proposals approved |
| 1. Shared visual refinement | AppCard, finance row, money text, icon/status use and theme consistency | S1/S2/S4 | LOW: no provider/router/schema changes; representative light/dark/JP/large-text visual checks |
| 2. Read-only list convergence | Existing Accounts + Activity + Subscriptions rows using shared primitives | S2/S4 plus Activity | LOW: grouping/typography only; same queries, actions and estimates |
| 3. Planning visual convergence | Existing Budgets + Goals + Home planning summaries | S1/S5 plus Goals | LOW only if behavior/selection retained; existing money/status outputs unchanged |
| 4. Capture visual convergence | Existing Add + Edit + Transaction Details | S3 | LOW only without new type-switch/repeat behavior; preserve validation/draft/save behavior |
| 5. Approved Home IA | Remove approved duplication, make Accounts entry clear, visibility state | S1 | MEDIUM: information/interaction change; verify all currencies and error/hidden states |
| 6. Focused account/budget navigation | Account detail/edit then budget detail/month scope in bounded slices | S2/S5 | MEDIUM: each routed behavior needs acceptance; no financial reinterpretation |
| 7. Credit/debit accounting design | Explicit contracts for instruments, liabilities, refunds, old card rows, Home inclusion | S2/S7/S3 payment sources | HIGH: isolated domain/schema/migration review; no visual checkpoint bundled |
| 8. Card/instrument migration + engine | Implement approved semantics and reconciliation | Underlies S2/S7/S3 | HIGH: isolate migration, atomic payment/edit/delete, budget/report invariants, rollback/recovery checks |
| 9. Card UI | Card detail + Accounts owed group + payment/source chooser | S2/S7/S3 | MEDIUM after domain gate; use existing forms/rows, no statements |
| 10. Auth identity | Continue current cloud work; verified provider/session/account-link behavior | Profile | HIGH isolated: real unavailable/error/signed-in states; no fake success |
| 11. Sync | Contract/schema prerequisites, then transport/idempotency/conflicts/retry in separate checkpoints | Cloud/Sync surfaces | HIGH isolated: preserve local data, duplicates/deletes/multi-device/conflict tests |
| 12. Security and privacy | Device lock, secure credentials, export/deletion scope; separate from auth and sync changes | Profile children | HIGH isolated: explicit action scope, device/server enforcement, recovery checks |
| 13. Understand + preference finish | Deterministic Insights, Notifications, About in small related UI slices | S1 deeper information | MEDIUM: no AI/inbox invention; calculations have evidence and period labels |
| 14. Final convergence/release QA | Cross-screen layout, all supported themes, JP/EN, precision, offline and release checklist | All V1 screens | Release gate: semantics/accessibility/financial correctness; no V2 feature expansion |

Cloud work may proceed on its existing roadmap in parallel organizationally; this report does not instruct another task or reorder its in-flight commits. Avoid editing shared routes/schema from overlapping checkpoints without coordination. High-risk auth/sync/security/accounting/migrations remain separately reviewable even if the same release contains them.

Safe 2–3 item bundles: Accounts/Activity/Subscriptions row visuals; Budgets/Goals/Home-summary visuals; Add/Edit/Transaction Details form visuals. Unsafe bundles: credit schema + Home restyle; auth + sync + security in one change; family permissions “while adding cloud”; assets/crypto “while adding account types”. The ring is optional polish; no calculation milestone depends on it.

## 25. Open decisions requiring product-owner approval

Nothing in this report approves a change. Existing locked navigation, deterministic money, currency-separated totals, subscription engine reuse and V2 deferrals are constraints, not votes to reopen casually. The following are concrete decisions for later checkpoints; no implementation needs to start merely because this report is accepted as an audit. **Update 2026-09-20:** navigation is no longer locked to the previous shell -- see O20 below and section 26; all other constraints in this paragraph remain in force.

| ID | Decision requiring approval | Recommended option | Why approval is needed / affected contract |
|---|---|---|---|
| O01 | Adopt this proposed page tree/title system | Adopt compact tree; keep editors modal | New details/Insights/preferences surfaces and naming are recommendations |
| O02 | Home content changes | One budget summary, one goal summary; explicit Accounts link; remove duplicated full blocks | Alters approved/current information hierarchy and entry affordances |
| O03 | Home balance meaning once cards exist | Currency-specific liquid balance with owed cards separate | Changes current all-active-account inclusion; must be decided before liability migration |
| O04 | New Accounts detail/edit/filter entry points | Account detail + specialized card detail; no separate Cards hub | Current rows are non-navigating; new interaction/route scope |
| O05 | Essential credit-card/instrument contract | Separate debit access from bank truth; liability-backed credit; explicit refunds/overpayments | Financial model/migration and existing generic card classification cannot be silently changed |
| O06 | Card due/statement-date scope | Manual essential metadata only if defined; defer statements/cycle engine | Reference implies much broader credit product than minimum V1 |
| O07 | Budget detail/month browsing | Add in V1-later using existing BudgetMonth and calculator | Current screen current-month only; read/edit policy for past/future months must be defined |
| O08 | Inline Add type selector | Preserve type sheet initially; assess inline segments in later behavior checkpoint | Changes existing capture interaction; edits must keep transaction type fixed |
| O09 | Repeat shortcut | Keep separate editor now; later explicit coordinated rule creation | Must prevent duplicate first occurrence; not a decorative switch |
| O10 | Save destination | Return to caller + optional View in Activity action | Requested direct Expense Save → Activity differs from existing pop behavior |
| O11 | Subscriptions entry enhancement | Keep tab/Add-on-Recurring; optional shared-editor shortcut only if approved | ADR-031 fixed entry placement; do not redefine active-only subscription model |
| O12 | Home Upcoming multi-row preview | Preserve current selection now; later define overdue-first capped list/window | Changes selection, amount/date scope and See all behavior |
| O13 | Visibility preference/bell | Add local masking; no unread badge/inbox until real source | New device UI state/behavior and accessibility requirements |
| O14 | Deterministic Insights scope | Bounded period/currency spending patterns linked to Activity; no AI | Page is roadmap-based, not shown; calculations and inclusion need acceptance |
| O15 | Preference/protection grouping | Profile groups plus dedicated focused pages; keep existing auth work aligned | New pages and sign-out/export/delete user flows require concrete contract |
| O16 | Broader document alignment | Later align document 20 advanced V1 list and older receipt roadmap to current scope | Would modify authoritative docs; explicitly outside this single-report checkpoint |
| O17 | Timezone accounting, if desired | Retain UTC engine convention; only localize presentation in this work | A change to accounting date boundaries is high risk, not locale polish |
| O18 | Prior-month balance comparison | Omit until period/baseline/zero-baseline policy approved | +2.5% cannot be copied or derived from current value alone |
| O19 | Future statement/lifecycle/wealth/household details | Keep in separately scoped V2 decisions | Future tree is an expansion map, not implementation approval |
| O20 | Navigation shell: HOME/ACTIVITY/+ADD/ACCOUNTS/MORE | **APPROVED 2026-09-20** -- adopt the five-destination shell in section 26 | Supersedes the O01-era assumption that navigation stayed at Home/Activity/Add/Profile; implementation (AppShell/GoRouter) has not yet changed to match |

Release-critical before card implementation: O03/O05/O06. Before new page/navigation work: O01/O02/O04/O07/O10/O12. Before optional reference affordances: O08/O09/O11/O13/O18. O16 is a documentation follow-up, not an instruction to edit existing documents during this audit.

### Checkpoint safety and verification

Only `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` is authored by this task. No production Dart, tests, database schema, navigation, existing documentation or design assets are intentionally edited by this audit. No staging or commit commands are used. A temporary tracked-file hash snapshot outside the repository supports final verification; because concurrent work is active, whole-workspace changes cannot be attributed to this report. Current HEAD and final Git observations are reported at completion. No application tests/builds are required to validate a Markdown-only architecture deliverable; no runtime pass is claimed.

Final verification observations (2026-09-20):

- All 25 numbered sections are present; all eight screen anatomies are present. Local Markdown links resolve; table column counts are consistent; code fences are paired; no Unicode replacement characters were found.
- Created repository file: `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md`. No existing repository file was written by this task.
- Temporary verification artifact created outside the repository: `C:/Users/lme/AppData/Local/Temp/ui-audit-baseline-9265065.txt` (tracked-file SHA-256 snapshot; not staged).
- HEAD remains `9265065b408aeae318b282487efecbbdea595ebc`. `git diff --cached --name-only` returned no entries. Nothing was staged or committed by this task.
- Hash comparison confirms additional concurrent changes to docs 14/21, app/router/Profile and localization files. Database files already modified at initial inspection did not differ from the later hash snapshot. This is **not** a clean-working-tree claim: there was pre-existing and concurrent Dart/schema work. The audit itself changed no Dart, tests, schema or navigation.
- A Cloud Account screen and `/cloud-account` route appeared during the audit, with Profile entry and provider foundations. Therefore the final snapshot has that additional implemented surface beyond the initial route inventory. It remains PARTIAL: the inspected production auth provider is explicitly unavailable/not configured, and a route or local identity link does not establish real authentication or multi-device sync. This report makes no claim to have reviewed all concurrent cloud changes.
- No production build, tests, migration or asset-editing operation was performed. The report is ready for product-owner review; none of its recommendations are marked approved.

## 26. Approved navigation architecture -- 2026-09-20 decision

Status: **APPROVED -- product-owner decision, 2026-09-20.** This section is authoritative for navigation. Where any earlier section in this document describes "Home / Activity / center Add / Profile" as the approved/locked shell, that description is superseded by this section and is retained above only as historical record of the prior decision, per this document's own no-silent-rewrite discipline. **This checkpoint freezes information architecture. It does not authorize implementation.** No `AppShell`, `GoRouter`, navigation widgets, production Dart, tests, database schema, or localization files are modified by this section, and none should be inferred as changed from it. **Implementation status (V1 navigation shell implementation checkpoint): IMPLEMENTATION COMPLETE in the working tree, not yet committed** -- see 26.9.

### 26.1 Final five-destination navigation

Approved primary shell (five destinations, replacing the four-destination Home/Activity/center Add/Profile shell described in sections 1, 4, 14, 20, 21 and 23 above):

| Position | Destination | Type | Semantic responsibility |
|---|---|---|---|
| 1 | HOME | Top-level tab | Financial health at a glance: balance, income/expense, budget/goal status, upcoming |
| 2 | ACTIVITY | Top-level tab | Financial history: the full transaction ledger, searchable and filterable |
| 3 | + ADD | Center action (not a page) | Capture: Expense / Income / Transfer |
| 4 | ACCOUNTS | Top-level tab | Money locations and what is owed: cash, bank, cards, credit-card liabilities |
| 5 | MORE | Top-level tab | Planning tools, recurring, preferences, identity/security, about -- everything too low-frequency for a permanent primary slot |

Explicit rules carried into this decision:

- Profile, Categories, and Budgets are **not** bottom-navigation destinations. Profile's former tab role is absorbed into MORE; Categories and Budgets remain pages reachable from HOME and/or MORE, exactly as before, never as their own tab.
- This shell does **not** copy the reference composite's own navigation row (visible in S1/S2/S6/S7/S8 as "Home / Accounts / + / Budgets / More"). That reference nav keeps Budgets as a permanent tab and omits Activity; the approved shell instead gives Activity the permanent slot and demotes Budgets to a linked page, and reorders Accounts to position 4. The reference composite's visuals remain the design target (section 17); its navigation bar does not.
- The reference image's navigation was never authoritative even under the previous Home/Activity/Add/Profile decision (section 14 said so explicitly); it remains non-authoritative under this decision too.

### 26.2 Rationale (recorded for ADR-034 in `docs/14_DECISION_LOG.md`)

- HOME answers "am I okay with money" (financial health); ACTIVITY answers "what happened" (financial history) -- distinct enough goals that both deserve permanent slots.
- + ADD is capture and stays a center action, unchanged from the previous decision.
- ACCOUNTS is a core financial object -- money locations and liabilities -- and, given the credit-card work already scoped in sections 8/9, deserves primary navigation rather than a Home shortcut plus a buried Profile row.
- MORE takes Profile's previous role (planning tools, recurring, preferences, identity/security, about) under a name that better matches its contents. Profile itself was judged too low-frequency a *destination* to keep a permanent primary slot once Accounts needed one, so its content moves under MORE rather than disappearing.
- The five-destination shell is designed so V2 growth (Assets & Liabilities, Receipt OCR, Family Wallet, richer Activity, receipt-assisted Add) fits inside existing tabs -- see 26.6 -- without requiring another shell redesign.

### 26.3 Final V1 page tree

Classification key: **TOP-LEVEL TAB** (bottom-nav destination) . **PAGE** (full navigable screen, not a tab) . **DETAIL PAGE** (page scoped to one entity) . **FORM PAGE** (full-screen create/edit) . **TAB-SEGMENT** (segmented view inside a page) . **MODAL-SHEET** (dialog/bottom sheet, not a route) . **EMBEDDED HOME SECTION** (content rendered inside the Home page, not a separate destination).

| Canonical page | Visible title | Subtitle | Classification | Parent | Entry points | Primary action | V1 status |
|---|---|---|---|---|---|---|---|
| Home | Home | Your money at a glance | TOP-LEVEL TAB | Shell | Launch / Home tab | Open a money task | DONE foundation |
| Balance/flow hero | (embedded) | -- | EMBEDDED HOME SECTION | Home | -- | View balance | DONE |
| Budget summary link | (embedded) | -- | EMBEDDED HOME SECTION | Home | -- | Open Budgets | DONE foundation |
| Goal summary link | (embedded) | -- | EMBEDDED HOME SECTION | Home | -- | Open Savings Goals | DONE foundation |
| Upcoming preview | (embedded) | -- | EMBEDDED HOME SECTION | Home | -- | Open Recurring | DONE foundation |
| Insights link | (embedded) | -- | EMBEDDED HOME SECTION | Home | -- | Open Insights | V1-later |
| Activity | Activity | Your money history | TOP-LEVEL TAB | Shell | Activity tab / Home metric links | Inspect a transaction | DONE foundation |
| Transaction Details | Transaction Details | -- | DETAIL PAGE | Activity | Row tap | Review | DONE |
| Edit Transaction | Edit Transaction | -- | FORM PAGE | Transaction Details | Edit | Save changes | DONE |
| Delete confirmation | -- | -- | MODAL-SHEET | Transaction Details | Delete | Confirm delete | DONE |
| Add type sheet | Add | -- | MODAL-SHEET | Shell (center action) | Center + | Choose Expense / Income / Transfer | DONE |
| Add Transaction | Add Transaction | -- | FORM PAGE | Add type sheet, or Account Detail | Type choice | Save | DONE foundation |
| Accounts | Accounts | See where your money is held and what you owe | TOP-LEVEL TAB | Shell | Accounts tab | Open an account | DONE foundation |
| Add Account | Add Account | -- | MODAL-SHEET | Accounts | + | Save account | DONE |
| Account Detail | {Account name} | -- | DETAIL PAGE | Accounts | Account row | View balance/activity | V1-later |
| Account-scoped Activity view | (embedded view) | -- | reuses Activity (same page/data) | Account Detail | -- | Review | V1-later |
| Edit/Archive Account | Edit Account | -- | FORM PAGE / MODAL-SHEET | Account Detail | Edit | Save metadata / archive | V1-later |
| Linked Debit Card metadata | Debit Card | -- | embedded section + FORM PAGE editor | Account Detail (bank) | Linked instrument | Edit metadata | V1-later |
| Credit Card Detail | {Card nickname} | -- | DETAIL PAGE (Account Detail variant) | Accounts | Card row/hero | Record payment | V1-later essential |
| Record Card Payment | Record Card Payment | -- | FORM PAGE (shared transfer-like) | Credit Card Detail | Record payment | Save payment record | V1-later |
| Edit Card | Edit Card | -- | FORM PAGE | Credit Card Detail | Edit | Save safe metadata | V1-later |
| More | More | Manage your money tools and preferences | TOP-LEVEL TAB | Shell | More tab | Open a tool/preference | DONE foundation (as Profile) |
| Categories | Categories | Organize your income and spending | PAGE | More -> Organization | Tool row | Manage category | DONE foundation |
| Budgets | Budgets | Plan your spending and stay on track | PAGE | More -> Planning, + Home summary link | Summary/tool row | Inspect plan | DONE foundation |
| Budget Detail | {Budget scope} | -- | DETAIL PAGE | Budgets | Summary/category | Inspect spend/pace | V1-later |
| Savings Goals | Savings Goals | Save toward what matters | PAGE | More -> Planning, + Home summary link | Goal summary/tool | Open goal | DONE |
| Goal Detail | {Goal name} | -- | DETAIL PAGE | Savings Goals | Goal row | Add contribution | DONE |
| Recurring | Recurring | Plan for money that repeats | PAGE, two tab-segments | More -> Recurring, + Home Upcoming link | Upcoming/tool | Handle occurrence | DONE |
| Recurring Transactions tab-segment | Recurring Transactions | -- | TAB-SEGMENT (inside Recurring) | Recurring | Tab (default) | Handle occurrence | DONE |
| Subscriptions tab-segment | Subscriptions | Keep track of recurring expenses | TAB-SEGMENT (inside Recurring) | Recurring | Tab | Inspect next pending expense | DONE |
| Insights | Insights | Understand your spending patterns | PAGE | More -> Money Tools, + Home link | Deeper link | Review deterministic patterns | V1-later |
| International Preferences | International Preferences | Set your countries, currencies, and formats | PAGE | More -> Personalization | Preferences row | Edit preferences | DONE |
| Currency Converter | Currency Converter | Check a reference conversion | PAGE | More -> Money Tools (existing entry point: International Preferences page) | Converter row | Reference conversion | DONE |
| Exchange Rates | Exchange Rates | View source/time/freshness | embedded section (existing Reference Rate card) | More -> Money Tools (existing entry point: International Preferences / Currency Converter) | Existing card | View source/time/freshness | DONE (no dedicated page) |
| Appearance | Appearance | Make the app feel like yours | PAGE | More -> Personalization | Appearance row | Select theme | DONE |
| Profile | Profile | Your local profile | PAGE (local profile summary) | More -> Personalization | Profile row | View/edit local profile | DONE (existing local profile) |
| Notifications | Notifications | Choose your money reminders | PAGE | More -> Personalization | Preferences row | Reminder permission | V1-later |
| Cloud Account | Cloud Account | Connect your account for cloud features | PAGE | More -> Cloud & Security | Cloud row | Sign in/out | V1-later (in progress) |
| Sync | Sync | Check what is saved across your devices | PAGE | Cloud Account | Sync status | Retry/sync | V1-later |
| Security | Security | Control access on this device | PAGE | More -> Cloud & Security | Security row | Device access controls | V1-later |
| Privacy & Data | Privacy & Data | Manage your information and data | PAGE | More -> Cloud & Security | Privacy row | Export/manage data | V1-later |
| About | About | -- | PAGE | More | About row | Version/legal/help | V1-later |
| Welcome | Welcome | Set up your money companion | PAGE (onboarding, pre-shell) | Launch | No local profile | Create local profile | DONE |

This table is the canonical V1 tree. Where it differs from the master page registry in section 5 (for example, "Profile tab" as Parent/Entry), section 5's rows should be read as referring to the same destination now named MORE -- see 26.7.

### 26.4 Final MORE hierarchy

Approved grouping inside MORE (a documentation-only recommendation for organizing the tool directory; the previous "Money tools / Preferences / Account & protection / About" grouping in section 14 is superseded by this finer breakdown). **Corrected 2026-09-20** -- an earlier version of this section misplaced Categories, Profile, International Preferences, Insights, Currency Converter, Exchange Rates, and Privacy & Data; the grouping below is the canonical one:

```text
MORE
├── Planning
│   ├── Budgets
│   └── Savings Goals
├── Recurring
│   ├── Recurring Transactions
│   └── Subscriptions
├── Money Tools
│   ├── Currency Converter
│   ├── Exchange Rates
│   └── Insights
├── Organization
│   └── Categories
├── Personalization
│   ├── Profile
│   ├── International Preferences
│   ├── Appearance
│   └── Notifications
├── Cloud & Security
│   ├── Cloud Account
│   ├── Sync
│   ├── Security
│   └── Privacy & Data
└── About
```

1. **Planning** -- Budgets, Savings Goals
2. **Recurring** -- Recurring Transactions, Subscriptions
3. **Money Tools** -- Currency Converter, Exchange Rates, Insights
4. **Organization** -- Categories
5. **Personalization** -- Profile (local profile summary), International Preferences, Appearance, Notifications
6. **Cloud & Security** -- Cloud Account, Sync, Security, Privacy & Data
7. **About** -- a final destination/group in its own right, with no further children in V1

Accounts is deliberately absent from this list: it moved out of the old Profile/Money-tools grouping into its own top-level tab (26.1), so MORE no longer needs to host it or a shortcut to it. This grouping is a documentation-only taxonomy for organizing the More tool directory; it does not by itself add, move, or rename any existing UI entry point -- see 26.3 for how existing pages (Currency Converter, International Preferences, and so on) keep their current entry points while being classified under their corrected group here.

### 26.5 Reference-screen mapping to the approved architecture

| Reference screen | Approved V1 target | Notes |
|---|---|---|
| S1 Home | HOME tab -- direct target | Unchanged from section 7's recommended Home content |
| S2 Accounts | ACCOUNTS tab -- direct target, adapted | Adopt the reference's purpose, not its exact filter set or carousel; see section 8 |
| S3 Add Transaction | Add Transaction (FORM PAGE) -- direct target | Reached from the center +Add action, unchanged from section 3/S3 and section 15 |
| S4 Subscriptions | Recurring -> Subscriptions tab-segment (under MORE -> Recurring) -- specialized view | Same engine as section 10; no new destination |
| S5 Budgets | Budgets PAGE -- reachable from both HOME (embedded summary link) and MORE (Planning group) | Dual entry point, single canonical page, consistent with the contextual-duplication rule: multiple entry points, one canonical feature |
| S6 Assets & Liabilities | Future Wealth architecture target, reachable from ACCOUNTS (contextual V2 link) | V2; see 26.6 and section 12 |
| S7 Credit Card | Credit Card Detail (DETAIL PAGE) -- essential account/liability detail target, under ACCOUNTS | Direct target once the credit-card domain work in sections 8/9 lands |
| S8 Family Wallet | Future shared-money target, reachable from MORE (V2) | V2; see 26.6 and section 13 |

### 26.6 V2 expansion mapping under the new shell

The section 22 V2 expansion tree remains valid; this maps each item onto the five-destination shell so no future shell redesign is implied:

- **Receipt OCR** (first major V2 feature) -- new entry point inside +ADD's type sheet ("Scan/Import Receipt"), landing in the same Add Transaction form after review. No new tab. Remains V2 pending the dependencies in section 21 (V2 tree) and ADR-029.
- **Family Wallet** -- new page reachable from MORE, in a group of its own once cloud identity/sync/permissions/invites/conflict handling/audit (section 13's dependency list) are satisfied. Remains V2 regardless of shell.
- **Assets & Liabilities** -- new page reachable contextually from ACCOUNTS (it is a wealth-scoped extension of "where is my money," which now lives under Accounts rather than under a demoted Profile). No new tab.
- **Richer Activity** -- additional filters/saved searches/date-range scope inside the existing ACTIVITY tab. No new tab.
- **Receipt-assisted +Add capture** -- extension of the existing +ADD action, not a new destination.

### 26.7 Remaining genuine architecture conflicts (post-decision)

- **Implementation lag (real, not a documentation conflict):** section 20's gap analysis records "Approved Home/Activity/Add/Profile shell -- DONE." That status describes the *previous* approved shell, which is what `AppShell`/`app_router.dart` still implement as of HEAD `02dd471`. The five-destination shell approved here is not yet implemented; section 20 is not rewritten by this checkpoint (documentation-only scope) and should be re-marked when a future implementation checkpoint changes `AppShell`/`GoRouter`. **Update (implementation checkpoint, working tree ahead of HEAD `507b508`):** `AppShell`/`app_router.dart` now implement the five-destination shell described in 26.1-26.4 (see 26.9). Section 20's "DONE" row still describes the *previous* shell and remains stale until a documentation-only pass re-marks it; this implementation checkpoint did not rewrite section 20, consistent with its own change-boundary scope.
- **Section 6 subtitle wording:** the title/subtitle registry's existing rows for Activity ("See your money in and out"), Accounts ("See where your money is held"), and Cloud Account ("Connect your account across devices") are superseded by this section's wording (26.3): "Your money history," "See where your money is held and what you owe," and "Connect your account for cloud features," respectively. Section 6's rows are left in place as historical record, with a superseded annotation added there pointing back to this section.
- **Section 5 registry "Profile tab" references:** every master-page-registry row whose Parent/Entry column says "Profile" or "Profile tab" (P01 and any row citing "Home/Profile") should be read as "More tab" going forward. Section 5 is not rewritten row-by-row in this checkpoint, since the registry's IDs and structure otherwise remain valid and a full rewrite risks losing the existing evidence trail. A future documentation pass may formally rename P01 to a MORE-rooted ID.
- No other genuine conflict was found: the reference composite's own navigation (Home/Accounts/+/Budgets/More) was never authoritative (section 14), so adopting a different five-destination shell does not conflict with anything the reference composite requires; it only changes which internal sections of this document described the *previous* decision as locked.

### 26.8 Scope confirmation

This section is documentation/architecture only. It freezes information architecture and does not authorize implementation. It does not modify `AppShell`, `GoRouter`, navigation widgets, production Dart, tests, database schema, or localization. Section 25's O20 row records this decision as approved; all other open decisions in section 25 (O01-O19) remain open exactly as before, unaffected by this navigation decision except where 26.7 notes an implementation-lag consequence.

### 26.9 Implementation status (V1 navigation shell implementation checkpoint)

**This subsection is additive and does not modify 26.1-26.8.** A subsequent checkpoint implemented the shell this section approved:

- `AppShell` (`lib/shared/widgets/app_shell.dart`) now renders the five destinations in 26.1 (Home, Activity, Add, Accounts, More) instead of the previous four (Home, Activity, Add, Profile).
- `app_router.dart`'s `ShellRoute` now nests Home, Activity, Accounts, and a new `MoreScreen` (`lib/features/settings/presentation/more_screen.dart`); `AppRoutes.profile` moved to a top-level (non-shell) route, reusing the existing `SettingsScreen`, reachable only from More -- matching 26.5's reference-screen mapping.
- The More screen implements the subset of 26.4's hierarchy that has a real V1 route: Planning (Budgets, Savings Goals), Recurring (one row, since `RecurringScreen`'s two tabs share one route), Money Tools (Currency Converter only), Organization (Categories), Personalization (Profile, International Preferences, Appearance), and Cloud & Security (Cloud Account only). Per this checkpoint's own no-dead-links instruction, Insights, Exchange Rates, Notifications, Sync, Security, Privacy & Data, and the About group are omitted -- none has an implemented V1 route yet.
- No conflict with 26.1-26.4 was found during implementation; the omissions above are pre-existing implementation gaps (the referenced screens/routes do not exist yet), not architecture disagreements, so ADR-034 was not touched.
- As of this update, these changes exist in the working tree only (HEAD is still `507b508`, the commit that added this section); nothing has been staged or committed.

# 20. Accounts, Assets, Liabilities, Cards, and Household Architecture

Status: Architecture specification. Documentation only — nothing in this
document is implemented yet unless a section explicitly says a V1 piece
already exists in the current schema.

This document is authoritative for the topics it covers. Where it overlaps
with an existing document, this document adds detail; it does not override
`00_MASTER_BLUEPRINT.md` Version 2.0 or `03_DATABASE_SCHEMA.md` on any point
those documents already decide. See "V2 precedence" in
`DOCUMENTATION_INDEX.md` for the general conflict-resolution order.

---

## 0. Core principle

Do not model everything as one generic "account" type with a single balance
field. That collapses several financially distinct concepts into one shape
and makes double counting and incorrect net-worth math easy to introduce
later.

Instead, separate:

- **Liquid accounts** — cash and bank balances that are directly spendable.
- **Payment instruments** — ways to spend liquid money or borrowed money
  (debit cards, credit cards). A payment instrument is not automatically a
  second balance.
- **Liabilities** — money owed (loans, credit card balances owed).
- **Assets** — things of value that are not spendable cash (property,
  vehicles, fixed deposits, crypto holdings).
- **Income sources** — the origin/category of incoming money, not a place
  money is stored.
- **Shared/household ownership** — who a balance belongs to and who may act
  on it, layered on top of the above rather than replacing it.

Every worked example in this document exists to keep this separation
concrete and to prevent an implementation from quietly re-merging these
concepts.

---

## 1. V1 personal money types

These are the account/asset/liability shapes the personal (single-user)
product is architected around. None of the card, loan, deposit, property, or
crypto types below exist in the current `accounts` table
(`03_DATABASE_SCHEMA.md`) yet — this section documents the target shape for
future schema work, not already-built functionality.

### 1.1 Cash / Wallet

A liquid, spendable balance not held at a bank. Behaves like today's
`accounts` row with `type = cash`: opening balance, running balance from
transactions, no linked instrument.

### 1.2 Bank Account

A liquid, spendable balance held at a financial institution. Behaves like
today's `accounts` row with `type = bank`. A bank account may have zero or
more debit cards linked to it (see 1.3) and may be the funding source for
credit card payments (see 1.4).

### 1.3 Debit Card

A debit card is a **payment instrument**, not a second balance. It
references a bank account and spends directly from that account's balance.

Required fields (future schema): nickname, issuer, network (Visa/Mastercard/
local scheme/etc.), masked identifier (last 4 digits — never store a full
card number), linked bank account id, currency (inherited from the linked
account), is_active, created_at/updated_at/deleted_at.

Invariant: a debit card must never carry its own balance field. Any spend on
a debit card is an expense against the linked bank account's balance,
exactly as if the bank account itself had been charged. Deleting or
deactivating a debit card must never affect the linked bank account's
balance or transaction history.

### 1.4 Credit Card

A credit card is a **liability-backed payment instrument**. Spending on a
credit card increases what is owed; it does not reduce any bank balance at
the time of purchase.

Required fields (future schema): nickname, issuer, network, masked
identifier, currency, credit limit, amount owed, available credit
(derived: `credit_limit - amount_owed`), statement date, due date, optional
linked bank account (the account normally used to pay the statement),
is_active, created_at/updated_at/deleted_at.

**Worked example — spending:**

- Credit limit: 500,000. Amount owed: 80,000. Available credit: 420,000.
- User spends 5,000 on the card.
- New amount owed: 85,000. New available credit: 415,000.
- This spend is recorded as one expense transaction against the credit
  card. It does **not** touch any bank account balance.

**Worked example — paying the card:**

- User pays 20,000 toward the card from their bank account.
- Bank account balance decreases by 20,000.
- Credit card amount owed decreases by 20,000 (to 65,000 in this
  continuation; available credit rises to 435,000).
- This payment is a **transfer** between the bank account and the credit
  card liability. It creates **no new expense** — the expense was already
  recorded at the moment of the original purchase. Recording the payment as
  a second expense would double count the same spending.

Invariant: credit card "amount owed" changes from three kinds of events
only: (a) new purchases on the card, which increase it and are recorded as
an expense; (b) interest charges, annual fees, and other card fees, which
also increase it and are also recorded as an expense (see "Card interest
and fees" below); and (c) payments toward the card, which decrease it and
are recorded as a transfer, never as an expense. It must never be edited
by an unrelated transaction type.

**Card interest and fees.** A credit card purchase is an expense plus a
liability increase, as above. Interest charged on a carried balance,
annual fees, and late fees are also expenses — they represent real cost to
the user — and each also increases the amount owed, exactly like a
purchase. Paying down the card (reducing amount owed via a transfer from a
liquid account) never itself creates an expense, and must never be
confused with the interest/fee charges that increased the balance in the
first place. In short: charges (purchases, interest, fees) are expenses
that increase the liability; payments are transfers that decrease it.

### 1.5 Loan

A **liability**: money the user owes to a lender (or, in a future extension,
money someone owes the user — see 1.5.1).

Required fields (future schema): lender name, principal, remaining
principal, currency, interest rate, start date, term/maturity date,
installment amount, next due date, notes, is_active,
created_at/updated_at/deleted_at.

A loan installment payment is not a single, indivisible transfer — it can
contain a principal component and an interest (and, later, fee) component,
and each component has different accounting treatment:

- The **principal** portion reduces the loan's remaining principal and
  reduces a liquid account. This portion behaves like a transfer (money
  moves from a liquid account to pay down the liability) — it is never
  itself recorded as a second consumption expense.
- The **interest** portion (and any applicable fee) also reduces the same
  liquid account, but it is recorded as an **interest expense** (or fee
  expense) — it is real cost, not a liability paydown, and it must never
  reduce the loan's remaining principal.

**Worked example:** a monthly payment of 50,000 splits into 42,000
principal and 8,000 interest.

- The full 50,000 leaves the bank account.
- Remaining principal decreases by 42,000 only.
- 8,000 is recorded as an interest expense; it does not reduce remaining
  principal (and does not increase it either) — it is simply cost incurred
  in the period.

Future fees (e.g. late fees) follow the same rule as interest: they are
expenses, and they never affect remaining principal.

Invariant: never treat an entire installment as a liability paydown (that
overstates how much principal was actually repaid), and never treat an
entire installment as a plain expense (that would ignore the real
liability reduction and distort net worth, per section 4).

#### 1.5.1 Future distinction: liability owed vs. receivable/asset lent

V1 only needs to represent loans the user owes (a liability). A future
version should distinguish that from money the user has lent to someone
else (a receivable — an asset, not a liability). This document flags the
distinction now so the eventual `loans` schema can add a `direction` field
(`owed` vs. `receivable`) instead of needing a second, parallel table. No
receivable/lending behavior is being implemented in V1.

### 1.6 Bank / Fixed Deposit

An **asset**, not spendable cash. Represents money locked into a fixed-term
deposit product at a bank.

Required fields (future schema): institution, principal amount, currency,
interest rate, start date, maturity date, is_active,
created_at/updated_at/deleted_at.

Invariant: a fixed deposit's principal must never be included in "spendable
balance" totals (e.g. a Home dashboard's "money available to spend" figure).
It contributes to net worth (section 4) as an asset, and only becomes
spendable again if/when a future "deposit matured / withdrawn" flow moves
its value into a liquid account — that flow is not being implemented now.

### 1.7 Property / Inventory Asset

An **asset**: a non-financial item of recorded value (vehicle, real estate,
significant personal property).

**Worked example:** Honda Vezel 2022, purchase value 12,000,000 LKR.

Required fields (future schema): name/description, category (vehicle,
real estate, other), purchase value, currency, purchase date, optional
current estimated value, notes, is_active,
created_at/updated_at/deleted_at.

Invariant: property value contributes to net worth (section 4) as an asset.
It is not spendable and must never appear in liquid-balance totals.

**Acquisition vs. consumption (dealers, resellers, small inventory
traders).** Buying a property/inventory asset — including for resale, e.g.
a vehicle dealer buying a Honda Vezel for 12,000,000 LKR to resell — is an
asset/inventory acquisition, not ordinary household consumption.
Conceptually: a liquid account (cash/bank) decreases and the
property/inventory asset increases by the same amount. This movement must
never be counted as personal spending in spending analytics — the money
did not disappear as consumption, it changed form from liquid to asset.

When such an asset is later sold, proceeds should be recorded appropriately
(the asset is disposed of and the liquid account increases), and any
gain/loss calculation is deferred to a future feature — not implemented
now. Purchase-related fees, taxes, and repairs may eventually need separate
expense-vs-capitalized-cost rules, relevant to a future business/inventory
accounting checkpoint; this document does not design that now. It only
fixes that the personal expense engine must not misclassify an
asset/inventory acquisition as spending.

### 1.8 Crypto Holding

An **asset**: a holding of a cryptocurrency or token. V1 records the
holding only — no live pricing, exchange integration, or FX conversion is
required now.

Required fields (future schema): asset symbol/name, quantity held, currency
of the recorded cost basis (if tracked), acquisition date(s), notes,
is_active, created_at/updated_at/deleted_at.

Invariant: without live pricing, a crypto holding's contribution to net
worth is either omitted or based on a manually entered/most-recently-known
value — never a fabricated or silently-assumed market price. Do not infer a
live valuation the app has not actually fetched.

### 1.9 Other Asset / Liability (fallback)

A general-purpose fallback for a personal asset or liability that does not
fit the specific types above (e.g. a personal debt between individuals
outside a formal loan product, a collectible, a business interest).

Required fields (future schema): name/description, `is_asset` or
`is_liability` flag, value, currency, notes, is_active,
created_at/updated_at/deleted_at.

This type exists so the account model does not need a new specific table
every time an edge case appears. It should stay rare in practice — a
recurring pattern that shows up often in this fallback is a signal a
first-class type (like 1.5–1.8) should be added instead.

---

## 2. Income sources are not accounts

Income sources (Salary, Grant, Lottery/Winnings, Business, Rental, Gift,
Interest, Other) are **categories describing where money came from**, not
places money is stored. Every income event must land in an actual
destination account (cash, bank, or another liquid/asset account) — income
can never exist as a balance on its own.

**Worked example:** a lottery win of 20,000 is recorded as income with
category "Lottery/Winnings" and destination account "Mother's Savings"
(a bank account). The 20,000 increases Mother's Savings' balance; the
category is metadata on the transaction describing its origin, not a
separate ledger.

Invariant: an income category must never be selectable as a transfer
source/destination, and must never accumulate its own balance. If a UI or
schema change ever makes an income category behave like an account, that is
a modeling defect to be corrected, not a new feature.

---

## 3. Expense payment source selection

When recording an expense, the user selects **which payment source** funded
it, and that selection determines the accounting effect:

| Payment source | Effect |
|---|---|
| Cash | Decreases the selected cash wallet's balance. |
| Bank Account | Decreases the selected bank account's balance. |
| Debit Card | Decreases the linked bank account's balance (the card itself holds no balance — see 1.3). |
| Credit Card | Increases the card's amount owed / decreases its available credit (see 1.4). No liquid balance changes at the moment of purchase. |

Invariant: never double count. A debit card expense must reduce exactly one
balance (its linked bank account) — never both a "card balance" and the
bank balance. A credit card expense must increase exactly one liability
(amount owed) and must not simultaneously reduce any liquid balance; the
liquid-balance reduction happens later, and separately, when the statement
is paid (1.4).

Buying an asset (property/inventory, a fixed deposit, crypto) is a distinct
transaction kind from an expense — see 1.6–1.8. It decreases a liquid
account and increases the corresponding asset record; it must never be
recorded as a spending expense against a payment source.

---

## 4. Net worth model

Net worth = **Assets − Liabilities**.

Assets include: cash, bank balances, fixed deposits, property/inventory
assets, crypto holdings, and any "Other Asset" entries.

Liabilities include: credit card amounts owed, loan remaining principal, and
any "Other Liability" entries.

This is architecture guidance for a future feature. **Do not implement a net
worth calculation, screen, or provider now.** This section exists so that
the V1 data model (section 1) is shaped in a way that makes a correct net
worth calculation possible later without a schema rework — specifically, by
keeping assets and liabilities as distinct, separately-typed records rather
than folding them into the generic `accounts` table.

---

## 5. Visual system for money types

This section documents design intent for when these types get UI. It does
not authorize building new screens now; it exists so that when V1 card/loan/
asset screens are eventually built, they share one visual language instead
of each being designed from scratch. Any design references discussed
alongside this specification are directional inspiration only, not
implementation truth — the principles below are what is authoritative.

Shared structure across every money-type detail screen:

- A polished header/hero area showing the type's primary figure (balance,
  amount owed, current value, or quantity held, as appropriate to the
  type).
- Rounded, card-based layout consistent with the rest of the app (see the
  UI/UX skill's shape guidance: ~16px card radius, ~20–24px for large
  feature cards).
- A clear typography hierarchy: hero number most prominent, supporting
  metadata (institution, dates, status) secondary — following the same
  hierarchy already used for goals and budgets.
- Icon-led identity per type, using the existing category/icon abstraction
  rather than a one-off mapping per screen.
- Consistent spacing, tab, and navigation conventions with the rest of the
  app.
- Built on semantic `ColorScheme` tokens so Light/Dark/Pink/Ocean/Forest
  themes (future work, not implemented now) work without rewriting the
  screen.

Per-type visual conventions:

- **Credit Card** — a polished virtual-card-style hero/header matching the
  app's overall theme, presenting: user-defined nickname, issuer/bank,
  network identity (Visa/Mastercard/etc.), an optional masked identifier
  (last 4 digits only), and currency. It may additionally surface amount
  owed, credit limit, available credit, a utilization percentage,
  statement date, and due date. It should read like "a card," not like a
  plain balance row, so it is visually distinct from debit-linked accounts.
- **Debit Card** — visually indicates the bank account it is linked to
  (e.g. a linked-account label or icon) and must never present its own
  balance figure — see 1.3. It should read as an access method to that
  account's balance, not as an independent instrument.
- **Cash** — wallet icon.
- **Bank Account** — building/institution icon.
- **Loan** — a liability-styled icon distinct from asset icons (e.g. a debt/
  liability glyph), so a loan is never visually confusable with an asset.
- **Fixed Deposit** — vault/lock icon, reinforcing that the money is not
  currently spendable.
- **Property / Inventory Asset** — property or vehicle icon matching the
  asset's category.
- **Crypto** — token/coin icon.
- **Shared Household Wallet** (V2, see section 6) — member avatars, an
  allowance/permission indicator, and an ownership indicator distinguishing
  it from a personal account at a glance.

**Card display and security.** This product does not require, and must
never store, a card's full PAN/card number, CVV/CVC, PIN, or online
banking password. The only card identifier this model needs is optional
masked/display metadata such as the last four digits, entered by the user
for their own reference — never validated against a real card network. Any
future feature that would need more (e.g. a real card-issuing or
bank-linking integration) is a separate, explicitly-designed security
checkpoint and is out of scope here.

Card visuals — and every other money-type visual in this section — must
adapt to Light, Dark, Pink, Ocean, and Forest themes via semantic
`ColorScheme` tokens (see section 0 and the UI/UX skill's theming
guidance). Do not hard-code a single fixed visual style — for example, a
uniformly black or "crypto-wallet" card look — that would not adapt across
themes.

Financial correctness always outranks visual preference: if a visual choice
would ever imply an incorrect balance, hide a liability, or make a transfer
look like income/expense, the visual choice must change, not the underlying
accounting.

---

## 6. V2 — Household / Family sharing

**Do not implement any part of this section in V1.** It requires cloud
sync, user identity, cross-user permissions, ownership scopes, conflict
handling, audit history beyond the current simple `audit_logs` table, an
invitation flow, and per-member access control — none of which exist in the
current architecture. This section documents the target shape so V1's
personal-money model (sections 1–4) is not built in a way that blocks it.

The existing `00_MASTER_BLUEPRINT.md` "Family Mode" stub (section 21) and
`10_ROADMAP.md`'s "family sharing" bullet under Stage 8 are the prior,
shallow mentions of this concept; this section is the detailed specification
that stub was a placeholder for.

### 6.1 Household example

A household has members with distinct roles, e.g.:

- Father — Owner/Admin
- Mother — Member
- Child 1 — Member
- Child 2 — Member

### 6.2 Shared wallets

A shared wallet is a household-owned liquid balance, separate from any
member's personal accounts.

**Worked example:** Father creates a "Family Cash Wallet" with a balance of
10,000. Mother spends 4,000 on bags from the shared wallet. Because she has
permission to spend from it, she does not need Father to manually transfer
funds to her first — she spends directly from the shared wallet. The wallet
balance becomes 6,000. All members can see the remaining balance, who spent
it, the category, and the date.

### 6.3 Private vs. shared money

Each member can hold both private (personal) accounts and shared
(household) accounts side by side. Moving money between the two is a
**transfer between ownership scopes**, not new income or a new expense at
the household level.

**Worked example:** Mother's lottery winnings of 20,000 land in her private
Savings account (an ordinary income event, per section 2). She later
transfers 10,000 from her private Savings into the Family Shared Wallet.
This transfer must **not** be recorded as household income — it is a
transfer that changes which ownership scope holds the money, exactly as a
transfer between two personal accounts changes which account holds it.

### 6.4 Allowances and spending limits

Two future modes:

- **Shared Balance Mode** — the wallet has one authoritative total balance
  that all permitted members can spend from, subject to permission checks
  (e.g. Child 1 might be view-only while Mother can spend freely).
- **Allowance Mode** — members may have per-member spending caps (daily/
  monthly), approval thresholds, allowed/blocked categories, or
  restrictions on transferring, editing, or changing permissions.

Invariant: unless an explicit sub-wallet is created for a member, an
allowance or spending cap is a **permission limiting how much of the shared
balance a member may spend** — it is not a separate balance. The shared
wallet's total remains the single authoritative figure. Do not implement
per-member "virtual sub-balances" implicitly; if per-member balances are
ever needed, they must be modeled as explicit sub-wallets, not inferred from
allowance settings.

### 6.5 Family-wide analytics (future, not implemented now)

A future household dashboard could show combined household spending by
category, per-member contribution to shared wallets, shared budget
progress, and shared goal progress. None of this is being implemented now;
it depends on sections 6.1–6.4 existing first.

### 6.6 Audit history for shared money

Every shared-wallet transaction must eventually preserve: the acting member
(actor), timestamp, wallet/account, amount, currency, category, transaction
type, the member who created it, the member who last edited it (if
different), an optional approval actor (for approval-gated actions), and
sync/version metadata. Deletion of a shared transaction should use
tombstone semantics (a recorded deletion event, not silent disappearance) —
the exact tombstone shape is left to the implementation-stage schema work,
but the requirement that shared deletions remain auditable is fixed here.

This extends, rather than duplicates, the existing simple `audit_logs` table
in `03_DATABASE_SCHEMA.md` (which currently records event_type, entity
type/id, and redacted metadata per event) — the richer fields above are
household-sharing-specific requirements layered on top of that mechanism,
not a replacement for it.

### 6.7 Ownership and permissions (future)

Future ownership scopes: Personal, Household Shared, Member-Limited, View
Only.

Future roles: Owner/Admin, Adult Member, Child/Restricted Member, Viewer.

Invariant: ownership and role must always be **explicit, stored data** —
never inferred from which device or which logged-in user happens to be
acting. A permission check must read a stored role/scope, not guess one
from context.

---

## 7. Accounting invariants (summary)

These invariants are stated individually above; they are collected here for
quick reference. Any future implementation of the types in this document
must uphold all of them:

1. A debit card references a bank account's balance; it never duplicates it
   with a second balance field.
2. Spending on a credit card creates or increases a liability (amount
   owed); it does not reduce any liquid balance at the time of purchase.
3. Paying a credit card statement is a transfer from a liquid account to
   the card liability; it is never recorded as a second expense.
4. Transfers (between accounts, between ownership scopes, or to pay down a
   liability) never count as income or expense.
5. A household contribution from a personal account to a shared wallet is a
   transfer between ownership scopes, not new household income.
6. An allowance or per-member spending limit is a permission on the shared
   balance, not a separate balance, unless an explicit sub-wallet is
   created.
7. Assets and liabilities remain separate, distinctly-typed records so net
   worth (Assets − Liabilities) can be calculated correctly later.
8. Income categories/sources are metadata describing a transaction's
   origin; they are never accounts and never hold a balance themselves.
9. Historical monetary records must preserve the currency and amount as
   recorded at the time — this document does not change the existing
   historical-FX-immutability rule already established for the money
   engine.
10. No linked instrument or account may be double counted — every liquid
    reduction, liability increase, or transfer must correspond to exactly
    one accounting effect, not two.
11. A loan installment's principal portion is a liability reduction
    (transfer-like); its interest (and any fee) portion is an expense and
    must never reduce remaining principal.
12. Credit card interest, annual fees, and late fees are expenses that
    also increase the amount owed, exactly like a purchase; only a
    payment toward the card reduces amount owed.
13. Acquiring a property, inventory, fixed deposit, or other asset moves
    money from a liquid account into an asset record — it is not spending
    and must never be classified as an expense in analytics.
14. A subscription is a specialized recurring-expense presentation; it
    must post through the same recurring-rule/occurrence and
    payment-source accounting as any other recurring expense, never a
    parallel calculation engine (see section 10).
15. This product does not require or store a card's full PAN, CVV/CVC,
    PIN, or online banking password — only optional masked/display
    metadata such as last four digits.

---

## 8. Version boundaries

### V1 (may be designed for, and eventually implemented, now or in
upcoming checkpoints — this document does not itself implement any of it)

- Cash accounts
- Bank accounts
- Debit-card payment instruments (linked to a bank account, no separate
  balance)
- Credit cards (limit, owed, available credit, statement/due dates)
- Loans (liability; owed direction only in V1)
- Fixed deposits (asset)
- Property / inventory assets
- Crypto asset holdings (no live pricing)
- Other Asset / Other Liability fallback
- Selectable expense payment source (cash / bank / debit / credit)
- Net-worth architecture groundwork (distinct asset/liability records —
  not the net-worth calculation or screen itself)
- Subscriptions UI built on the existing recurring engine (see section 10
  for the full specification and its own V1/later boundary)

### V2 (explicitly out of scope until its own checkpoint)

- Household / Family accounts
- Cloud-connected members and identity
- Shared wallets
- Cross-user permissions
- Allowance controls
- Family-wide analytics
- Shared audit history (the richer fields in section 6.6)
- Invitations / identity management
- Approval workflows
- Conflict resolution (concurrent edits to shared data)

Do not pull V2 implementation into current V1 work. A V1 checkpoint that
happens to touch the `accounts` table or add a new asset/liability type
should not also add sharing, permissions, or multi-user fields "while it's
convenient" — that decision belongs to its own explicitly-scoped checkpoint.

---

## 9. Open questions for a future implementation-stage decision

These are flagged here, not decided here:

1. Should credit card statement interest be modeled as a distinct
   transaction type, or as a plain expense category on the card? This
   document only fixes that a *payment toward* the card is a transfer, not
   how interest accrual itself should be categorized.
2. For loans, should "receivable" (money lent to someone else, section
   1.5.1) share the same `loans` table with a `direction` field, or become
   a separate table? Leaning toward a shared table per 1.5.1, but not
   decided.
3. Should fixed deposits and crypto holdings support a manually-entered
   "current value" update flow in V1 (without live pricing), or should
   current value remain purchase-value-only until a future pricing feature
   lands?
4. For the "Other Asset / Other Liability" fallback (1.9), what usage
   threshold should trigger promoting a recurring pattern into a
   first-class type?
5. For shared wallets (V2), should Allowance Mode's per-member caps live on
   the wallet record itself, or as separate permission records referencing
   the wallet? This affects how audit history (6.6) attributes a blocked
   attempt.
6. Should net worth (section 4) exclude crypto holdings entirely until live
   pricing exists, or include them at last-known/manually-entered value? A
   silently-stale value could mislead the user if not clearly labeled.

None of these need to be resolved to keep this document accurate — they are
implementation-stage decisions for whichever checkpoint first builds the
affected type.

---

## 10. Subscriptions

Subscriptions get their own user-facing screen/module, but they are a
**specialized presentation and workflow layered on the existing recurring
engine** — they must not become a second, competing transaction/scheduling
engine. The authoritative recurring-money model is the one actually
implemented per `14_DECISION_LOG.md` ADR-023 (the `recurring_rules` /
`recurring_occurrences` schema and `RecurringRuleRepository` /
`RecurringOccurrenceRepository` split) — see 10.6 for the cross-reference
and a noted inconsistency in `03_DATABASE_SCHEMA.md`.

### 10.1 Relationship to the recurring engine

A subscription is a recurring rule with subscription-flavored metadata and
a subscription-focused UI. Creating, editing, pausing, or cancelling a
subscription creates/edits/pauses/cancels the same underlying recurring
rule a manually-created recurring bill would use. Posting a subscription's
charge uses the same occurrence-posting logic as any other recurring
expense. Do not build a parallel scheduler, a parallel "next due date"
calculator, or a parallel posting path specifically for subscriptions.

Examples of user-facing subscriptions: Netflix, Spotify, YouTube Premium,
Amazon Prime, iCloud/cloud storage, Microsoft/Adobe/other software, gym
memberships, insurance recurring premiums, mobile/data plans, domains/
hosting, school/software memberships, and any other user-created recurring
subscription.

### 10.2 Conceptual fields

- name/provider
- amount
- currency
- billing frequency
- next billing/renewal date
- optional end date
- category
- payment source/instrument
- status: active / paused / cancelled / expired
- optional trial end date
- optional notes
- recurring rule reference/id (the underlying recurring rule this
  subscription's UI is built on)

### 10.3 Payment source and posting behavior

A subscription's payment source can be Cash, Bank, Debit Card, or Credit
Card. Posting a subscription charge follows exactly the same rule as any
other expense payment source (section 3) — no subscription-specific
accounting path exists:

| Payment source | Effect |
|---|---|
| Cash | Reduce cash balance. |
| Bank | Reduce bank balance. |
| Debit Card | Reduce the linked bank balance (see 1.3). |
| Credit Card | Increase the card's liability (amount owed) — see 1.4. |

Invariant: no double counting. A subscription charge posts through the
same single accounting effect as any other expense on that payment source;
it must never additionally touch a second balance or a
subscription-specific ledger.

### 10.4 UI surface (V1)

Subscription UI may show: a monthly estimated subscription total, a yearly
estimated total, upcoming renewals, charges due in the next 7/30 days,
service/category, payment source, and active/paused/cancelled/expired
state. Later (not V1): price history, duplicate-service detection, and a
deterministic "you spend X/year on subscriptions" summary.

Do not claim the app can cancel a subscription with the provider (Netflix,
Spotify, etc.) unless and until a real provider integration explicitly
supports that — "cancelled" in this product only ever means the local
recurring rule was stopped.

### 10.5 V1 vs. later

V1 / nearer-term:

- Subscriptions UI built on existing recurring rules
- Manual service creation
- Payment-source assignment
- Upcoming renewals
- Monthly/yearly estimated totals
- Active/paused/cancelled/expired state

Later (explicitly not required for V1, and not implemented now):

- Automatic merchant detection
- Automatic price-change detection
- Provider integrations
- Cancellation integrations
- Email/receipt-based detection
- Bank/card-feed detection

V1 requires no external service integration for subscriptions.

### 10.6 Cross-reference and a noted inconsistency

The authoritative recurring-money design is `14_DECISION_LOG.md`
(ADR-023), which documents the actual `recurring_rules` /
`recurring_occurrences` schema split and repository behavior. Note:
`03_DATABASE_SCHEMA.md` still shows an older single `recurring_transactions`
table shape that predates ADR-023's split. Per the existing "V2
precedence" order in `DOCUMENTATION_INDEX.md`, `14_DECISION_LOG.md` is
authoritative over `03_DATABASE_SCHEMA.md` on this point. This document
does not rewrite `03_DATABASE_SCHEMA.md` — the inconsistency is flagged
here only so subscription work is built against the actual recurring
engine, not the stale schema-doc table.

---

## 11. Cross-references

- `00_MASTER_BLUEPRINT.md`, section "21. Family Mode" — the original,
  shallow placeholder this document's section 6 expands into full detail.
- `03_DATABASE_SCHEMA.md`, `accounts` table — the current minimal schema
  this document's section 1 is a future-facing superset of.
- `03_DATABASE_SCHEMA.md`, `groups` table — an existing schema-level
  concept (local project/trip grouping) that may be a useful precursor for
  household/shared-wallet modeling in V2.
- `03_DATABASE_SCHEMA.md`, `audit_logs` table — the existing simple audit
  mechanism this document's section 6.6 extends rather than duplicates.
- `10_ROADMAP.md`, Stage 8 — Advanced — the existing "family sharing"
  roadmap bullet this document's section 6 gives full detail to.
- `DOCUMENTATION_INDEX.md` — "V2 precedence" governs how this document
  resolves against `00_MASTER_BLUEPRINT.md` Version 2.0 and the other
  ranked documents if a conflict is ever found.
- `14_DECISION_LOG.md`, ADR-023 — the authoritative recurring-money design
  (`recurring_rules`/`recurring_occurrences`) that section 10
  (Subscriptions) builds on.
- `03_DATABASE_SCHEMA.md`, `recurring_transactions` table — an older
  single-table shape that predates ADR-023's split; per "V2 precedence,"
  `14_DECISION_LOG.md` governs where the two disagree.

---

## 12. Unified `FinancialAccount` ledger model — approved design freeze

Status: Approved 2026-09-20 (documentation/architecture decision only; no
implementation in this checkpoint — no Drift schema, migration, `FinanceEngine`,
repository, provider, or screen file was changed to record this section).

This section is the outcome of a dedicated architecture audit and an adversarial
design challenge conducted against it (both records kept outside this repository).
It **refines the shape** of sections 1.2 ("Bank Account"), 1.3 ("Debit Card"), and
1.4 ("Credit Card") above with a concrete, approved schema — it does not overturn
any of those sections' worked examples or invariants, all of which remain valid and
are not restated here except where this section adds something genuinely new
(institution grouping, deposits, migration policy, sign-convention arithmetic).
Where this section and 1.2–1.4 could be read as disagreeing on a point neither
explicitly settled before, this section governs, per this document's own "adds
detail, does not override" framing in its introduction.

### 12.1 Domain model

Five conceptual entities, one balance-holding table:

- **`FinancialInstitution`** — an optional grouping/provider label (MUFG, Commercial
  Bank, Rakuten, Docomo, ...). Never carries a balance. Every product type below
  references it via a **nullable** foreign key — cash and other institution-less
  products simply leave it unset; the UI renders that as "Cash" or "Other," a
  presentation label, never a sentinel database row.
- **`FinancialAccount`** — the single authoritative ledger-balance target for
  every asset and every liability. Fields: `id`, `profileId`, `institutionId`
  (nullable), `name`/nickname, `currencyCode`, `balanceClass` (`asset` |
  `liability`), `subtype` (`cash` / `checking` / `savings` / `bank` / `wallet` /
  `creditCard` / `deposit` / `other`), `openingAmountMinorUnits` (always a
  **non-negative magnitude**, in the account's own class-native terms — see 12.3),
  plus the project's standard lifecycle/sync fields (`isActive`, `createdAt`,
  `updatedAt`, `deletedAt`, `syncVersion`, `syncStatus` — the same five-column
  convention every table from schema v2 onward already uses; see 13.1 for why
  today's `accounts` table itself is the one known exception, and why this
  design's migration folds the fix for that into the same step). Conceptually,
  this is today's `accounts` table (see 13.1/13.2 for exactly how it gets there),
  widened in *meaning*, not rebuilt from scratch.
- **`PaymentInstrument`** — a way to spend a `FinancialAccount`'s balance or
  available credit. Never itself balance-holding — no balance-shaped column
  exists on this table at all, so it cannot double-count by accident. Links to
  **exactly one** `FinancialAccount` via a single required foreign key (never a
  choice between two nullable columns — seespecialized invariant 12.5).
- **`CreditFacilityDetails`** — a one-to-one metadata table, present if and only
  if a `FinancialAccount` has `balanceClass: liability` and `subtype: creditCard`.
  Carries `creditLimitMinorUnits`, optional statement-closing-day metadata,
  optional due-day metadata, an optional minimum-payment figure (only if a
  specific product's minimum-payment rule is later modeled with defined
  semantics — no generic placeholder minimum-payment field is frozen now), and
  an optional `linkedPaymentAccountId` (the account normally used to pay the
  statement — informational only, never enforced).
- **`DepositDetails`** — a one-to-one metadata table, present if and only if a
  `FinancialAccount` has `balanceClass: asset`, `subtype: deposit`. Carries
  `depositType` (`fixed` / `shortTerm` / `recurring` / `other`), `termNumber`/
  `termUnit`, `startDate`, `maturityDate` (computed once, at creation — see
  12.7), `interestRateBasisPoints`, `interestMethod` (`simple` / `compound`),
  `compoundingFrequency` (meaningful only for `compound`), `autoRenew`/
  `renewalMode`, an optional `interestDestinationAccountId`, and — only for
  `depositType: recurring` — `installmentAmountMinorUnits`/`installmentFrequency`
  (see 12.9).

Specialized fields never live directly on `FinancialAccount` itself — a plain
cash or bank account has zero rows in either detail table, and nothing about its
own row shape hints that credit or deposit fields ever existed. This is a
deliberate rejection of one generic table with many nullable, mostly-unused
columns, matching this document's own core principle (section 0).

### 12.2 Immutability invariants

Once a `FinancialAccount` has any financial history (at least one `Transaction`
referencing it, directly or as a transfer destination):

- `balanceClass` can never change (`asset` <-> `liability` is never a valid
  transition, with or without history — an account's fundamental class is fixed
  at creation, unconditionally).
- `currencyCode` can never change (unchanged from today's existing
  `AccountRepository.updateAccount` rule and its documented rationale: reusing
  minor units under a different currency would reinterpret every historical
  amount).
- `subtype` transitions are forbidden by default; a future, explicitly-designed
  checkpoint may permit a narrow, named set of compatible transitions (e.g.
  `cash` -> `other`) if a real product need for one is identified — no such
  transition is approved now.

These guarantees must be enforced by the eventual repository/domain API design
itself, not merely validated-and-rejected at the call site: the update method's
own parameter list must simply have no way to express a `balanceClass`/`subtype`
change, the same pattern `AccountRepository.updateAccount(id, name, type)`
already uses today for currency (that method has no currency parameter at all).
A regression test asserting the update method's signature has no such parameter
is required before this is considered frozen in code, not just in this document.
`FinancialInstitution` name/nickname and every account's own display
nickname/institution-link remain freely editable at any time, before or after
history exists — only `balanceClass`/`subtype`/`currencyCode` carry this
lifetime lock.

### 12.3 Balance sign semantics

**Canonical internal representation: every stored and displayed magnitude is
non-negative, in the account's own class-native terms.** An asset account's
figure is "amount owned"; a liability account's figure is "amount owed." There
is never a negative internal balance for a liability — 3,000 owed is stored and
computed as `3000`, never `-3000`.

Direction is decided by exactly one signed-effect rule, applied uniformly by
`FinanceEngine`, never inferred ad hoc at an individual call site:

| `balanceClass` | Role | `TransactionType` | Effect |
|---|---|---|---|
| asset | source (`accountId`) | expense | `−` |
| asset | source | income | `+` |
| asset | source (transfer source) | transfer | `−` |
| asset | destination (transfer only) | transfer | `+` |
| liability | source (`accountId`) | expense (purchase / fee / interest charge) | `+` (owed increases) |
| liability | destination (transfer only) | transfer | `−` (owed decreases — a payment) |
| liability | any other role | any other type | unreachable in V1 — throws, same posture as today's unused `refund`/`adjustment` types |

Worked examples, restated in this canonical form:

- **Expense from asset**: `asset -= expense`. Unchanged from today.
- **Income to asset**: `asset += income`. Unchanged from today.
- **Expense on credit liability**: `liability += expense`. New.
- **Credit-card payment** (a transfer): `asset(source) -= payment`;
  `liability(destination) -= payment`. No expense is created — this is
  `TransactionType.transfer`, already excluded from income/expense totals today.
- **Refund to a credit card**: `liability -= refund`. **Deferred, not V1** — no
  repository path creates a refund transaction today (mirroring `refund`'s
  existing unused/`UnsupportedError` status for asset accounts); this row is
  recorded here only so a future implementation has a settled sign rule to build
  against, not as an approved V1 feature.
- **Credit-card cash advance**: treated identically to an ordinary purchase
  (`liability += amount`) for balance purposes. Real-world cash-advance fee/rate
  differences are **deferred** — V1 does not model a different accrual rate for
  a cash advance versus a purchase.
- **Interest/fees on a credit facility**: `liability += amount`, recorded as an
  ordinary expense against that liability, exactly like a purchase — never a
  separate transaction kind. (Restates 1.4's existing rule in this section's
  arithmetic terms; no change.)
- **Net worth** (still not implemented as a screen/provider — unchanged from
  section 4): `netWorth = Σ(asset magnitudes) − Σ(liability magnitudes)`.
- **Available credit**: `creditLimit − amountOwed`, always computed, never
  stored — `creditLimitMinorUnits` never participates in ledger-balance
  arithmetic.

**Required `FinanceEngine` adaptation.** Today's `FinanceEngine.accountBalance`
implements exactly the asset rows of the table above and nothing else —
`LedgerAccount` has no class concept at all yet. The approved adaptation is to
generalize that one function (not add a second, parallel one) so that an
existing asset account computes byte-for-byte the same result it does today,
while a liability account's magnitude is computed by the same function reading
its `balanceClass` and applying the liability rows above. This keeps the
asset-vs-liability branch in exactly one place in the codebase, rather than
splitting it across two independently-written functions that would each need to
agree on the transfer-destination behavior separately.

### 12.4 Transaction invariants

**`Transaction.accountId` and `Transaction.destinationAccountId` keep their
existing names and existing shape** — both remain plain foreign keys into the
one ledger-target table (which is `FinancialAccount` in domain terms; see 13.1
for why the underlying SQL/Drift identifier may stay `accounts`/`AccountRow` for
now). `accountId` remains required; `destinationAccountId` remains nullable,
set if and only if `type == transfer` — identical to today's rule, unchanged.
No new mutually-exclusive column pair is introduced on `Transactions`.
`paymentInstrumentId` is the one new column: optional, analytics/history only,
and carries zero accounting weight — no balance/owed computation ever reads it,
so removing it or leaving it unset changes no financial figure, by construction.

Worked examples:

- **Debit purchase**: `financialAccount = checking`, `paymentInstrument = Visa
  Debit`, `type = expense`.
- **Credit purchase**: `financialAccount = <the credit liability account>`,
  `paymentInstrument = Visa Credit`, `type = expense`.
- **Cash purchase**: `financialAccount = cash`, `paymentInstrument = null`,
  `type = expense`.
- **Credit-card payment**: `financialAccount (source) = checking`,
  `destinationAccountId = <the credit liability account>`, `type = transfer` —
  never `expense`.
- **Deposit funding**: `financialAccount (source) = checking`,
  `destinationAccountId = <the deposit account>`, `type = transfer` — never
  `expense`.
- **Deposit maturity**: the principal's movement (e.g. back into a checking
  account, or rolled into a renewed deposit) remains transfer-like; interest
  actually paid out is recorded as `type = income` against the receiving asset
  account. Neither is modeled as an automatic V1 feature yet (12.7/12.9) — this
  is the settled classification for whenever it is built.

### 12.5 Payment-instrument invariants

`PaymentInstrument.financialAccountId` links to **exactly one**
`FinancialAccount` in V1 — a single required foreign key, never a choice between
two nullable targets. A debit/cash-card instrument must link to an *asset*
account; a credit-card instrument must link to a *liability* account — enforced
at the repository layer when the instrument is created (mismatched class is
rejected, mirroring the currency-mismatch-rejection pattern this codebase
already uses throughout). A `PaymentInstrument` contributes **zero**
independently to total assets, total liabilities, or net worth — it has no
balance-shaped column, so this cannot regress by accident.

`Transaction.paymentInstrumentId` is optional (12.4). A historical transaction
must remain fully understandable if its instrument is later archived — archiving
never rewrites or hides the transaction's `financialAccountId`/amount/type,
only the instrument-metadata display (e.g. "Visa Debit (archived)"). An
instrument referenced by any historical transaction is **never hard-deleted** —
only ever soft-deleted, following this schema's existing tombstone convention.

Never store: full PAN, CVV/CVC, PIN, or online-banking credentials — no column
for any of these exists on `PaymentInstrument`. `last4` is optional and never
required, and is never validated against a real card network (unchanged from
section 5's existing security constraint).

### 12.6 Shared credit facility

Frozen shape: one liability `FinancialAccount` ("Rakuten Credit Facility") with
one `CreditFacilityDetails` row (the shared credit limit), and two independent
`PaymentInstrument` rows ("Rakuten Visa," "Rakuten Amex"), both pointing at the
same `financialAccountId`. A purchase on either card increases the same
facility's owed amount and reduces the same available credit — no special-case
code is needed, because the balance/available-credit computation (12.3) never
looks at which instrument was used, only which `FinancialAccount` the
transaction targets. An independent-limit card is simply its own separate
`FinancialAccount` + `CreditFacilityDetails`, with its own single
`PaymentInstrument` — the same mechanism, not a different one.

**Simple "Add Credit Card" UX, despite the internal split.** One form,
one user-visible step, internally creating — inside one repository-level
transaction/batch, never as separable calls a caller could invoke
independently — one liability `FinancialAccount`, one `CreditFacilityDetails`
row, and one `PaymentInstrument` row. The user is never shown this as three
records; "add another card to this existing facility" is offered only after a
facility already exists, as a secondary affordance, not on first creation.

### 12.7 Deposit foundation

A deposit is an **asset** `FinancialAccount` (`subtype: deposit`) plus one
`DepositDetails` row — never spendable, per section 1.6's existing invariant,
which this section does not change. Funding a deposit is an asset-to-asset
`transfer` (checking -> deposit), never an expense. Interest actually credited
is `income`; the principal returned at maturity is not — restated in 12.4's
worked examples.

**Deterministic maturity-date rules.** `maturityDate = startDate + term`,
computed once at creation and stored (not recomputed live on every read, so the
figure never drifts if calculation rules change later). For `termUnit: days`,
plain calendar-day addition. For `termUnit: months`/`years`, this document
requires **reusing** the project's existing calendar-safe, leap-year-aware,
anchor-based month/year arithmetic already implemented for recurring rules
(`lib/features/recurring/domain/recurring_schedule.dart`'s
`normalizeRecurringDate`/`_lastDayOfMonth`/anchor-based day-of-month clamping) —
not a second, independently-written calendar routine. End-of-month behavior is
therefore explicit and already-proven: a deposit starting Jan 31 with a 1-month
term matures Feb 28 (or 29 in a leap year), clamped against the target month's
actual length, exactly as that existing routine already does for a monthly
recurring rule anchored on the 31st.

### 12.8 Deposit calculation contract

No binary floating point anywhere in this calculation — every intermediate
value is an exact `Decimal` (`package:decimal`, already a direct project
dependency, already used for exchange-rate arithmetic), and the existing
project-wide ROUND HALF UP policy (`MoneyRounding.roundHalfUpToMinorUnits`,
ADR-018) is applied exactly once, at the end, to convert the final exact
interest amount into integer minor units — never at any intermediate step.

- **Annual rate representation**: `interestRateBasisPoints` (an integer, e.g.
  `550` = 5.50%), converted to an exact `Decimal` fraction (`/10000`) at
  calculation time — never a stored `double` rate.
- **Time-period representation**: the exact day count from `startDate` to
  `maturityDate` (a plain integer), or, for compound interest, a whole number of
  compounding periods derived directly from `termNumber`/`termUnit` and
  `compoundingFrequency` — always a whole number, never a fractional exponent.
- **Simple interest**: `interest = principal × rate × (termDays / basisDays)`.
  **V1 reference day-count convention: Actual/365**, chosen as a single,
  explicitly-documented default — stated in the UI itself as "estimated using a
  365-day year," never claimed to match any specific institution's own
  convention.
- **Compound interest**: `maturityValue = principal × (1 + rate/n)^(n×t)`,
  where `n` = periods/year from `compoundingFrequency` (`monthly`=12,
  `quarterly`=4, `semiannual`=2, `annual`=1, `atMaturity`=1 treated as one
  compounding period over the whole term — equivalent to simple interest for
  that case) and `n×t` is always a whole number of periods, so `Decimal`'s
  integer-exponent power is sufficient; `interest = maturityValue − principal`.
- **Rounding boundary**: the final `interest`/`maturityValue` `Decimal`,
  rounded once via `MoneyRounding.roundHalfUpToMinorUnits` into the deposit's
  own currency's minor units (never assuming 2 decimal places — the existing
  `CurrencyRegistry` minor-units metadata governs, exactly as it does for every
  other `Money` value in this codebase).

**Labeling requirement, non-negotiable:** every displayed figure from this
calculation is labeled **"Estimated interest"** / **"Estimated maturity
value"** — never presented as a guaranteed or bank-confirmed figure. This is
required because real institutions vary in day-count convention, compounding
rounding, withholding tax, and early-withdrawal penalties, none of which this
V1 calculation claims to replicate. Taxes/withholding, early-withdrawal
penalties, product-specific bank conventions, and variable rates are all
**deferred** — not modeled in V1 at all, not even as an optional field.

### 12.9 Recurring deposit

`subtype: deposit`, `depositType: recurring` is **recognized and storable in
V1** (10,000 LKR/month for 24 months, etc., via `installmentAmountMinorUnits`/
`installmentFrequency` on `DepositDetails`) — but V1 does **not** implement
scheduled, self-posting contributions or a precise maturity-value projection
that depends on exactly when each contribution starts earning interest.
Concretely, for V1:

- **Storing/tracking a recurring deposit's own declared terms**: supported.
- **Scheduled, auto-posted monthly contributions** (extending the recurring-
  rules engine to post into a `Deposits`-shaped target the way it posts into an
  asset account today): **not V1** — this would require the recurring engine's
  own `accountId`/`destinationAccountId` targets to accept a deposit account the
  same way `Transactions` does (12.4), which is a real, separate piece of work
  this section does not approve now.
- **Estimated maturity-value projection for a recurring deposit**: a coarser,
  explicitly-labeled "Estimated" approximation may be shown in V1 (e.g. treating
  contributions as landing evenly across the term for interest-averaging
  purposes), but this is **not** the same deterministic single-principal
  formula in 12.8, and must never be presented as though it were.

### 12.10 Wallet / payment-service funding taxonomy

No fifth top-level table. Every funding shape reuses the four entities above:

- **Stored value** (the wallet itself holds a balance): a `FinancialAccount`,
  `balanceClass: asset`, `subtype: wallet` — already exactly what today's
  `type: wallet` accounts are.
- **Linked-bank/debit funding** (e.g. a mobile payment service funded from a
  bank account): a `PaymentInstrument`, `instrumentType: wallet`, linked to an
  *asset* `FinancialAccount` — the identical mechanism a debit card already
  uses, only the `instrumentType` label differs.
- **Linked-credit funding**: a `PaymentInstrument`, `instrumentType: wallet`,
  linked to a *liability* `FinancialAccount` — identical mechanism to a credit
  card.
- **Postpaid** (the wallet itself is the liability): a liability
  `FinancialAccount` (with `CreditFacilityDetails` if it has a genuine limit),
  optionally paired with a `PaymentInstrument` for a consistent "how did I pay"
  record. **Whether V1 actually exposes a postpaid-wallet product in the Add
  Account flow is a UX scope decision, not an architecture one** — the schema
  supports it the moment any liability `FinancialAccount` can be created; see
  13.3 for the V1-scope classification of whether that UX ships now.

Do not implement every one of these four shapes merely because the architecture
now supports all of them without further schema change — see 13.3.

---

## 13. Migration, compatibility, and implementation sequencing for the unified model

Status: Approved 2026-09-20 (documentation/architecture decision only; no
migration, repository, provider, or screen file was changed to record this
section).

### 13.1 Conservative migration policy from today's `accounts` table

Today's `accounts.type` is free-text: `cash` / `bank` / `card` / `wallet`.
Historical transactions must never be reinterpreted destructively by this
migration, in either direction.

- **`cash` rows** -> `FinancialAccount`, `balanceClass: asset`, `subtype: cash`.
  No ambiguity, no data change beyond the new columns defaulting
  (`institutionId: null`, matching today's implicit state).
- **`bank` rows** -> `balanceClass: asset`, `subtype: bank` (or a more specific
  `checking`/`savings` legacy subtype only if a later, explicit product
  decision distinguishes them — not required by this migration itself). No
  ambiguity.
- **`wallet` rows** -> `balanceClass: asset`, `subtype: wallet`, preserved as a
  legacy stored-value wallet unless a later, explicit signal says otherwise. No
  ambiguity.
- **`card` rows — the one genuinely ambiguous case.** A `type: card` row today
  could be a debit card someone modeled as its own account (most likely, since
  the UI has never distinguished debit from credit), or, far less likely, an
  attempt to track a credit card by repurposing the opening balance as a
  running "owed" figure. **This migration must never auto-convert a `card` row
  into a liability `FinancialAccount`.** Every `card` row instead migrates into
  a conservative **legacy `card` subtype**, `balanceClass: asset` (preserving
  its existing numeric balance exactly as-is, since that is the only
  interpretation consistent with not reinterpreting history), flagged for a
  one-time, user-facing migration-review prompt: "This looks like a card
  account — is it (a) a debit card linked to one of your other accounts, (b)
  its own account you'll keep using as-is, or (c) a credit card (money you
  owe)?" Choice (a) creates a `PaymentInstrument` linked to the bank account
  the user picks and soft-deletes the old row (history preserved, never
  destroyed); choice (b) simply relabels the legacy subtype, no data change;
  choice (c) is **never automatic** — it routes to the ordinary "Add Credit
  Card" flow (12.6), because a correct liability record needs a real credit
  limit and a real current-owed figure the old flat schema never captured, and
  the old row is left as a soft-deleted historical asset record for the user to
  review, never silently reinterpreted as debt.
- **No existing `Transactions` row is ever rewritten.** Every historical
  transaction keeps its existing `accountId`, `amountMinorUnits`,
  `currencyCode`, and `occurredAt` exactly as recorded — this migration only
  ever adds new nullable columns/tables and reclassifies the *target* row's own
  metadata, never a transaction's own recorded amount or target reference.
- **Historical balances remain numerically stable.** Since `FinanceEngine`'s
  arithmetic for an asset account is unchanged (12.3), and every migrated `card`
  row starts life as an asset (never a liability) regardless of which
  disambiguation choice a user eventually makes, no existing balance
  calculation changes value as a result of this migration alone — only a
  user's later, explicit choice (option (c) above) can ever change how a
  specific account's history is interpreted going forward, and that choice
  creates new records rather than rewriting old ones.
- **Fold in the already-planned `accounts.syncVersion`/`syncStatus` gap.**
  `docs/21_CLOUD_SYNC_ARCHITECTURE.md` §11 and ADR-032 already commit to adding
  exactly those two columns to `accounts` (CP12.3), independently of this
  design. This migration adds `institutionId`/`balanceClass`/`subtype` in the
  same version bump as that already-committed pair, rather than migrating the
  same table twice.

### 13.2 Compatibility with the existing generic Account Detail/Edit (`deb51bf`)

`AccountDetailScreen`/`EditAccountScreen` (introduced at HEAD `deb51bf`) are
already type-agnostic — neither branches on `type` today, and neither reads any
field this design doesn't already provide for a plain asset account. **Both
screens continue working, unchanged, for every legacy/simple `FinancialAccount`
(cash/bank/wallet/undecided-card)** the moment this migration lands — nothing
about them needs to change to keep serving that case correctly. They are not
thrown away and not replaced by product-specific screens in this step; a
Credit Facility Detail screen and a Deposit Detail screen are new, additional
screens for the new liability/deposit subtypes (13.4, checkpoint F/H), reached
instead of the generic screen only once an account actually has that subtype —
the generic screen remains the correct destination for every account that
doesn't.

### 13.3 V1 vs. later scope freeze

| Classification | Items |
|---|---|
| **MUST — V1 foundation** | Unified asset/liability `FinancialAccount` model; `FinancialInstitution`; `PaymentInstrument`; basic credit-facility/card correctness (12.3/12.6); credit purchases; credit-card payments without double expense; asset/liability totals; net-worth-*ready* semantics (not the screen itself); basic term/fixed deposits; deterministic basic deposit estimates (12.8); the conservative migration (13.1); exact tests for every invariant in 12.2–12.5. |
| **CAN — V1, if low risk** | Statement/due-date convenience fields; deposit renewal metadata; optional `last4`/expiry; richer institution grouping/autocomplete; shared-limit facilities (12.6 — falls out of the model for free); recurring-deposit storage/estimate (12.9, storage half only). |
| **DEFER — after V1** | A loan amortization engine (sections 1.5/1.5.1 remain future work, unchanged); advanced recurring-deposit projection/auto-posting (12.9, projection half); bank-specific tax/day-count rules; early-withdrawal calculations; variable-rate deposits; investment brokerage; crypto valuation (section 1.8 unchanged); bank connectivity; postpaid-wallet UX exposure in Add Account (12.10, unless a later checkpoint explicitly scopes it in); net worth screen/provider (section 4, unchanged); refund-to-credit-card (12.3). |
| **DEFER — V2** | Shared household ownership (section 6, unchanged). Receipt OCR remains the first major V2 feature (per ADR-029, unchanged). Family Wallet remains V2 (unchanged). |

### 13.4 Implementation checkpoint order

Each checkpoint below is scoped so its own migration/behavior risk is isolated
and reviewable independently — no single checkpoint combines a schema change
with a `FinanceEngine` change with a UI change.

**A. Architecture/docs freeze** — this section. Purpose: settle the model
before any code changes. Migration risk: none. Invariants/tests: none (docs
only). Rollback boundary: revert this doc section; nothing else exists yet to
roll back.

**B. Institution + `FinancialAccount` classification foundation, safe
migration** — add `FinancialInstitutions` table; add `balanceClass`/`subtype`/
`institutionId`/`syncVersion`/`syncStatus` to `accounts` (13.1); ship the
migration-review UX for ambiguous `card` rows. No `FinanceEngine`, repository
read-path, or screen behavior change beyond what's needed to render the
migration-review prompt. Migration risk: additive-only schema change on an
existing, populated table (real, but the least risky category — no existing
column's shape or nullability changes, per 13.1's "no `Transactions` row ever
rewritten" invariant). Invariants/tests: 12.2's immutability guarantees, 13.1's
"card row never auto-converts to liability," "no historical transaction
rewritten." Rollback boundary: a single schema version; no dependent
checkpoint has started.

**C. Adapt `FinanceEngine` to asset/liability semantics** — generalize the one
balance function per 12.3's required adaptation; add the liability-side rows
of the sign table; unit-test every cell of 12.3's table (including the
unreachable-throws rows) with plain in-memory lists, matching this codebase's
existing `FinanceEngine`-testing convention. No liability accounts exist to
exercise this in production yet (checkpoint B only produces asset-classified
rows) — this checkpoint is verified entirely by unit tests against synthetic
liability data. Migration risk: none (no schema change). Invariants/tests: full
coverage of 12.3's table; a regression test proving an existing asset
account's computed balance is byte-for-byte unchanged from before this
checkpoint. Rollback boundary: this checkpoint alone; B is unaffected either way.

**D. Payment instruments** — `PaymentInstruments` table + repository (12.5).
No liability accounts exist yet to link a credit instrument to, so this
checkpoint only exercises the debit/asset-linked path in production; the
credit-linked path is unit-tested against synthetic data. Migration risk:
low (new table only). Invariants/tests: 12.5's exactly-one-target,
class-must-match-instrument-type, never-hard-delete-if-referenced.

**E. Credit facility metadata + purchase/payment behavior** —
`CreditFacilityDetails` table + repository; extend `TransactionRepository`'s
expense/transfer recording to accept a liability `FinancialAccount` target
(12.4); wire the credit-linked path of D into production. Migration risk:
moderate (new table, plus real behavior change to
`recordExpense`/`recordTransfer`'s validation, on a live, high-frequency
repository). Invariants/tests: every worked example in 12.3/12.4 (credit
purchase, credit-card payment, shared facility from 12.6); a regression test
proving an ordinary asset-to-asset expense/transfer is unaffected.

**F. Deposit metadata + deterministic calculation engine** — `DepositDetails`
table + repository; the pure, `Decimal`-based calculator from 12.8, unit-tested
independently of Drift/Flutter (matching `FinanceEngine`'s own
testing philosophy). Migration risk: low (new table only, no change to any
existing repository method). Invariants/tests: 12.8's rounding-boundary rule
(exactly one rounding, at the end); the "Estimated" labeling requirement
enforced at the UI layer built in H, not skippable.

**G. Add Account UX** — the "what would you like to add?" flow, wired to B–F's
repositories; Bank Account and Credit Card first (the acceptance cases' most
common shapes), Deposit second. Migration risk: none (UI only, on top of
already-shipped repositories). Invariants/tests: 12.6's "one step, three rows,
one transaction" creation guarantee.

**H. Accounts/Detail presentation** — Credit Facility Detail and Deposit
Detail screens (13.2 confirms the existing generic screen needs no change for
everything else); institution-grouped Accounts screen (section 19 of the prior
audit, unchanged by this freeze). Migration risk: none. Invariants/tests: the
existing generic screens' tests remain green, unmodified, throughout.

**I. Dashboard/net-worth integration** — the dashboard's existing per-currency
sum must explicitly exclude liability accounts from its asset total once
liabilities are queryable at all (today it can't accidentally include them
only because none exist yet); net worth itself remains out of scope (13.3).
Migration risk: low, but this is the checkpoint most likely to regress an
existing display if skipped or rushed — flagged explicitly as a required step,
not an optional polish pass.

**J. Full migration/regression/Android QA** — the end-to-end pass across every
prior checkpoint's tests plus a real-device run of the `card`-row migration
UX from B against representative legacy data. Migration risk: this checkpoint
exists specifically to catch what unit tests alone cannot.

Ordering may adjust if a later checkpoint discovers a real dependency this
freeze didn't anticipate (e.g. if D turns out to need a small piece of E's
validation earlier than expected) — but no checkpoint should ever combine a
schema change with a `FinanceEngine` change with a screen change in one step,
regardless of reordering.

### 13.5 Unresolved decisions that must be answered before schema migration

These are flagged, not decided, exactly as section 9's existing "open
questions" convention already establishes for this document:

1. Should `bank` legacy rows be split into `checking`/`savings` legacy
   subtypes at migration time, or left as a single `bank` subtype until a user
   explicitly edits one? This freeze does not require the split; checkpoint B
   may ship either way, but must pick one and document it in that checkpoint's
   own migration notes.
2. Exactly which statement/due-date fields `CreditFacilityDetails` ships with
   in V1 (12.1 lists them as optional, but the precise set — e.g. whether a
   minimum-payment field ships at all in checkpoint E, given 12.1's explicit
   condition that it only ships "if semantics are well-defined") is not fixed
   by this freeze.
3. Whether postpaid-wallet products (12.10) are exposed in the V1 Add Account
   UX at all, or remain schema-supported-but-not-offered until a later,
   explicitly-scoped checkpoint (13.3 currently defers the UX exposure, not
   the underlying schema capability) — a product decision, not resolved here.
4. Whether `bank` legacy rows and undecided-`card` legacy rows need a visibly
   different presentation in the interim Accounts screen (before checkpoint H's
   institution grouping ships) so a user isn't confused about why some
   accounts show a migration-review prompt and others don't.

None of these need to be resolved to keep this section accurate — they are
implementation-stage decisions for whichever checkpoint (B, E, or G) first
encounters them, exactly matching this document's own precedent in section 9.

### 13.6 Cross-references (this section)

- `docs/21_CLOUD_SYNC_ARCHITECTURE.md` §11 / `docs/14_DECISION_LOG.md` ADR-032
  — the already-committed `accounts.syncVersion`/`syncStatus` migration this
  section's checkpoint B folds its own new columns into (13.1).
- `docs/14_DECISION_LOG.md` ADR-017/ADR-018 — signed 64-bit integer minor
  units and ROUND HALF UP, both unchanged and directly reused by 12.8.
- `lib/features/recurring/domain/recurring_schedule.dart` — the existing
  calendar-safe date arithmetic 12.7 requires reusing for deposit maturity
  dates, rather than reimplementing.
- `docs/14_DECISION_LOG.md` ADR-035 — records this design-freeze decision in
  the decision log's own format; this document remains the detailed
  specification ADR-035 points to, per this document's own established
  relationship with the decision log elsewhere (e.g. ADR-023/section 10.6).

### 13.7 Implementation status (Checkpoint B — classification foundation)

**This subsection is additive and does not modify §§12-13.6 above -- it records what Checkpoint B actually built against those unchanged sections, following the same "implementation status" convention `docs/22_UI_REFERENCE_PRODUCT_ARCHITECTURE.md` §26.9/§26.10 already use.**

- Schema version 9. `lib/core/database/tables.dart`: added `FinancialInstitutions` (`id`, `profileId`, `name`, `countryCode` nullable, `createdAt`/`updatedAt`/`deletedAt`, `syncVersion`/`syncStatus`) and added `balanceClass`/`subtype`/`institutionId`/`syncVersion`/`syncStatus` to `Accounts` -- folding in the already-committed `accounts.syncVersion`/`accounts.syncStatus` gap from `docs/21_CLOUD_SYNC_ARCHITECTURE.md` §11 / ADR-032 into this same version bump, per §13.1's own instruction above.
- `balanceClass`/`subtype` are deliberately a NARROWER set than this document's own §12.1: `subtype` currently only defines `cash`/`bank`/`wallet`/`legacyCardNeedsReview`/`legacyUnknownNeedsReview` (`lib/core/finance/financial_account_subtype.dart`) -- not yet `checking`/`savings`/`creditCard`/`deposit`/`other` from §12.1's full list. This is **not a discrepancy** with the frozen model: §12.1 itself is the ceiling, and the Checkpoint B brief explicitly required not overpopulating subtype values merely because a future checkpoint will need them. `subtype` is a plain `TextColumn` (matching this schema's enum-as-text convention), so checkpoint E/F can introduce `creditCard`/`deposit` later with no schema migration.
- The conservative migration mapping from §13.1 is implemented exactly as specified: `cash`→asset/cash, `bank`→asset/bank (never guessed as checking/savings), `wallet`→asset/wallet, `card`→asset/legacyCardNeedsReview (never auto-converted to a liability), any other/unrecognized legacy `type`→asset/legacyUnknownNeedsReview (the column's own default). No `financial_institutions` row is created by this migration or by any current UI. See `lib/core/database/app_database.dart`'s schema-v9 migration step and `test/core/database/financial_account_classification_migration_test.dart`.
- `FinanceEngine`/`LedgerAccount` (§12.3's required adaptation) are explicitly **NOT** touched by this checkpoint -- that is Checkpoint C's work, per §13.4's ordering. `AccountRepository.createAccount`/`updateAccount`, `Transactions`, and every screen/provider are otherwise unchanged; see the Checkpoint B implementation report for the full file list.
- These changes exist in the working tree only (HEAD is still `a76b0d2`, the commit that froze this architecture); nothing has been staged or committed.

### 13.8 Implementation status (Checkpoint C — FinanceEngine asset/liability semantics)

**This subsection is additive and does not modify §§12-13.7 above -- it records what Checkpoint C actually built against those unchanged sections, following the same "implementation status" convention §13.7 above already established.**

- `lib/core/finance/ledger_models.dart`: `LedgerAccount` gained a required, strongly-typed `balanceClass` field (plus `isAsset`/`isLiability` convenience getters) -- there is still exactly ONE `LedgerAccount` shape; no parallel `LiabilityAccount` class was introduced, per §13.4's own framing of this checkpoint. `LedgerAccount.openingBalance` is documented as the non-negative, class-native magnitude §12.3 already specifies (owned for an asset, owed for a liability) -- the DB column (`Accounts.openingBalanceMinorUnits`) itself was not touched or reinterpreted at the storage layer; only this pure-Dart domain model's doc comment and shape changed.
- `lib/core/database/repositories/account_repository.dart`: `AccountRowX.toLedgerAccount()` now passes `balanceClassValue` (the Checkpoint B helper) into `LedgerAccount`, so every account the repository hands to `FinanceEngine` carries its real classification. This is the only change to that file this checkpoint made -- `createAccount`/`updateAccount`'s immutability-by-signature-shape invariants from Checkpoint B are untouched.
- `lib/core/finance/finance_engine.dart`: `FinanceEngine.accountBalance` is now class-aware, implementing §12.3's full sign table (the frozen asset rows are unchanged; the liability rows -- expense increases owed, transfer-destination payment decreases owed -- are new). Still ONE function, `accountBalance` -- no parallel `assetBalance()`/`liabilityBalance()`/`creditCardBalance()` was added, per §13.4's explicit instruction. `incomeExpenseTotals`/`categoryTotals`/`categoryExpenseTotal`/the pacing and projection helpers are untouched -- they operate purely on `LedgerTransaction.type`, which this checkpoint does not change.
- Two new finance-domain exceptions, colocated with `FinanceEngine` (matching this codebase's existing exception-per-domain convention, e.g. `CurrencyMismatchException` in `core/money/`): `lib/core/finance/invalid_liability_operation_exception.dart` (income targeting a liability, or a liability used as a transfer source -- the two structurally-invalid V1 liability roles) and `lib/core/finance/liability_overpayment_exception.dart` (a liability's derived balance would go negative after a payment). Neither can be thrown for an asset account. Refund-to-credit-card, cash advances, balance transfers, interest, and fees beyond an ordinary expense remain explicitly out of scope, per §13.3/§12.1's own deferral.
- Overpayment decision (the "liability overpayment / negative owed" edge case): V1 rejects rather than clamps or represents a credit balance. `FinanceEngine.accountBalance` checks the *final* folded balance for a liability account, not each individual transaction in isolation -- since every liability effect is a plain `Money` addition/subtraction, the final sum is order-independent, so this is equivalent to (and simpler than) checking at each step. A future checkpoint may design an explicit overpayment/credit-balance representation; this one does not.
- No schema change. Schema stays at version 9 (Checkpoint B's version); `Accounts.openingBalanceMinorUnits` was not migrated, renamed, or reinterpreted at the storage layer -- only the pure-Dart domain layer above it became class-aware.
- Test coverage added/extended in `test/core/finance/finance_engine_test.dart`: a new `FinanceEngine.accountBalance -- liability (Checkpoint C)` group (opening position, expense accumulation, an asset-to-liability payment's effect on both accounts, a payment correctly excluded from `incomeExpenseTotals`, both invalid-role rejections, overpayment rejection, an exact-zero payment succeeding, deleted-expense exclusion, currency-mismatch rejection on a liability, and an asset-account regression check alongside a liability account in the same ledger); two additions to the existing asset-only `FinanceEngine.accountBalance` group closing gaps the pre-Checkpoint-C suite left implicit (a currency-mismatch case and a zero-amount-transaction case, both proving inherited `Money`-level behavior at the `accountBalance` boundary, not new behavior). No existing test's expected value was changed. `test/features/transactions/presentation/transaction_providers_test.dart`'s two direct `LedgerAccount(...)` constructions were given an explicit `balanceClass: BalanceClass.asset` (the only change needed there, since `LedgerAccount.balanceClass` is now required) -- their expected balances are unchanged.
- Every other `LedgerAccount` construction site in the app goes through `AccountRowX.toLedgerAccount()` (`lib/features/accounts/presentation/account_providers.dart`, `lib/features/dashboard/presentation/dashboard_providers.dart`, and their respective repository-backed tests) and needed no direct edit -- they now automatically carry the real account's `balanceClass` (currently always `asset`, since no UI path can create a liability account yet -- §13.4 checkpoint G is what changes that).
- `dashboard_providers.dart`'s per-currency total (`_summaryForCurrency`) still sums every account's `FinanceEngine.accountBalance(...)` with a plain `+`, blind to `balanceClass` -- unchanged by this checkpoint and not a regression, since no liability account exists yet for it to receive. This is flagged here, not fixed, per §13.4 checkpoint I's own scope ("the dashboard's existing per-currency sum must explicitly exclude liability accounts from its asset total once liabilities are queryable at all") -- exactly the checkpoint that owns this fix, not C.
- These changes exist in the working tree only (HEAD is still `c8c7ee5`, the commit Checkpoint B's report was verified against); nothing has been staged or committed.

### 13.9 Implementation status (Checkpoint D — PaymentInstrument foundation)

**This subsection is additive and does not modify §§12-13.8 above -- it records what Checkpoint D actually built against those unchanged sections, following the same "implementation status" convention §13.7/§13.8 above already established.**

- Schema version 10. `lib/core/database/tables.dart`: added `PaymentInstruments` (`id`, `profileId`, `accountId` -- physically named to match `Transactions.accountId`'s own naming even though it points at the unified `FinancialAccount` model, `institutionId` nullable, `instrumentType`, `network` nullable, `nickname`, `last4` nullable, `expiryMonth`/`expiryYear` nullable, `createdAt`/`updatedAt`/`deletedAt` nullable, `syncVersion`/`syncStatus`) and added one nullable `Transactions.paymentInstrumentId` column. `AppDatabase.migration`'s `from < 10` branch: `m.createTable(paymentInstruments)` then `m.addColumn(transactions, transactions.paymentInstrumentId)` -- no other statement. No `accounts` column, no existing `transactions` row, and no other table is touched by this migration; zero `payment_instruments` rows are fabricated.
- A `PaymentInstrument` carries **zero independent accounting weight**: `FinanceEngine`/`LedgerAccount`/`LedgerTransaction` are completely untouched by this checkpoint (no import of anything Checkpoint-D-specific anywhere in `lib/core/finance/finance_engine.dart` or `ledger_models.dart`) -- `TransactionRepository._toLedger` does not read `paymentInstrumentId` at all, so it never reaches `FinanceEngine.accountBalance`, `incomeExpenseTotals`, or any other calculation. A `creditCard`-typed instrument does not itself make its linked account a liability; `PaymentInstrumentRepository.createInstrument`'s validation only ever rejects an inconsistent account/instrument-type pairing, it never writes `Accounts.balanceClass`.
- Two new domain enums, matching the `BalanceClass`/`FinancialAccountSubtype` enum-as-text convention: `lib/core/finance/payment_instrument_type.dart` (`debitCard`/`creditCard`/`cashCard`/`paymentService`/`other`) and `lib/core/finance/card_network.dart` (`visa`/`mastercard`/`jcb`/`amex`/`other`). Both `fromStorageValue` fall back to `other` rather than throwing, matching Checkpoint B's precedent.
- `lib/core/database/repositories/payment_instrument_repository.dart` (new): `createInstrument`/`watchActiveForAccount`/`watchActiveForProfile`/`requireActiveById`/`findByIdIncludingDeleted`/`updateMetadata`/`softDelete`. Account-class validation table: `debitCard`/`cashCard` require an asset account, `creditCard` requires a liability account, `paymentService`/`other` permit either. `updateMetadata` has no `accountId`/`profileId`/`instrumentType` parameter at all -- the same immutability-by-signature-shape discipline `AccountRepository.updateAccount` already established. Three new exceptions in `lib/core/database/repositories/`: `PaymentInstrumentNotFoundException`, `PaymentInstrumentValidationException` (disallowed balance class, account/profile mismatch, institution/profile mismatch), `InvalidPaymentInstrumentAttributionException` (used by `TransactionRepository`, see below). `last4`/expiry shape errors throw a plain `ArgumentError`, matching this codebase's existing convention for isolated argument-shape checks.
- Today's production Add Account UX still cannot create a liability account (Checkpoints B/C never expose that), so a real end-to-end `creditCard` instrument cannot yet be created through the app UI -- `PaymentInstrumentRepository`'s own tests seed a liability account directly through the DB fixture to exercise that validation path, exactly as this checkpoint's brief permits, rather than weakening the validation to accommodate UI that doesn't exist yet.
- `lib/core/database/repositories/transaction_repository.dart`: `recordExpense`/`recordIncome`/`recordTransfer` gained an optional `paymentInstrumentId` parameter, validated by a new private `_validatePaymentInstrumentAttribution` (queries `payment_instruments` directly rather than depending on an injected `PaymentInstrumentRepository`, so this repository's constructor -- and its roughly 50 existing call sites across the app and test suite -- did not need to change). V1 source-attribution rule: the instrument's `accountId` must equal the transaction's own `accountId` (the source account, for a transfer); a deleted or cross-profile instrument is rejected for a *new* transaction. **Deliberately not added to `updateExpense`/`updateIncome`/`updateTransfer`/`_updateExpenseOrIncome`** in this checkpoint -- their `TransactionsCompanion` writes simply never mention `paymentInstrumentId`, so Drift leaves that column untouched on every edit, meaning an existing attribution is never silently overwritten or cleared by an edit. Changing an existing transaction's attribution is left as explicit future work, not a blocker for this checkpoint (see the final report's "blockers or concerns").
- Test coverage: `test/core/finance/payment_instrument_type_test.dart` (enum round-trips), `test/core/database/repositories/payment_instrument_repository_test.dart` (21 tests: account-class validation for all four instrument types, structural single-account linkage, optional institution, account/institution-profile mismatch rejection, last4/expiry shape validation, immutable-metadata-update, soft-delete/active-selection/historical-resolution), `test/core/database/repositories/transaction_repository_test.dart`'s new `Checkpoint D -- payment instrument attribution` group (10 tests: null-attribution baseline, expense/income/transfer attribution, unrelated-account/cross-profile/deleted-instrument rejection, an archived instrument not invalidating its historical transaction, and two explicit zero-accounting-effect proofs against `FinanceEngine`), and `test/core/database/payment_instrument_migration_test.dart` (populated v9→v10, empty v9→v10, and fresh v10 `onCreate`). No existing test's expected value was changed.
- These changes exist in the working tree only (HEAD is still `a66db33`, the commit Checkpoint C's report was verified against); nothing has been staged or committed.

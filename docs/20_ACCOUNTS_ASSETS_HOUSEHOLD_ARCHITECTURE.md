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

### 13.10 Implementation status (Checkpoint E — credit facility + purchase/payment semantics)

**This subsection is additive and does not modify §§12-13.9 above -- it records what Checkpoint E actually built against those unchanged sections, following the same "implementation status" convention §13.7/§13.8/§13.9 above already established.**

- Schema version 11. `lib/core/database/tables.dart`: added `CreditFacilityDetails` (`id`, `profileId`, `accountId` -- `.unique()` + `.references(Accounts, #id)`, enforcing the one-facility-per-account rule at the database level in addition to the repository's own pre-check -- `creditLimitMinorUnits`, `statementClosingDay` nullable, `dueDay` nullable, `linkedPaymentAccountId` nullable `.references(Accounts, #id)`, `createdAt`/`updatedAt`/`deletedAt` nullable, `syncVersion`/`syncStatus`). `AppDatabase.migration`'s `from < 11` branch is exactly one statement: `m.createTable(creditFacilityDetails)`. No existing table's column, row, or shape is touched -- unlike Checkpoint D's migration (which also had to `addColumn` onto the already-populated `transactions` table), this step only creates a brand-new, empty table, so it structurally cannot fail against any historical fixture the way Checkpoint D's Task 3 regression did; the six pre-existing migration-fixture files needed zero changes for this checkpoint (verified by inspection, not by re-running each one -- a pure `CREATE TABLE` step only needs its FK targets, `accounts` and `profiles`, which every fixture already has).
- `CreditFacilityDetails` has **no `currencyCode` column** -- currency is inherited from the linked `FinancialAccount`, matching this section's own "no independently mutable facility currency" requirement; `CreditFacilityRepository.availableCredit` takes the account's currency-tagged `Money` values as input rather than the facility row reading currency from itself.
- `lib/core/database/repositories/credit_facility_repository.dart` (new): `createFacility` validates, in order: the target account exists and belongs to the calling profile (`AccountRepository.requireById`, reusing Checkpoint B/C's existing ownership check rather than a new one); the account is active (not soft-deleted); `account.isLiability`; `account.subtypeValue == FinancialAccountSubtype.creditCard`; the supplied `creditLimit`'s currency matches the account's currency (`CurrencyMismatchException`, the same exception `Money.operator-` already throws, not a new one); `creditLimit` is non-negative (`ArgumentError` -- **zero is explicitly allowed**, see decision below); `statementClosingDay`/`dueDay`, if supplied, are each independently in `1..31` (`ArgumentError`; no "both or neither" pairing rule, unlike Checkpoint D's expiry-month/year pairing, because these two fields are conceptually independent); no facility already exists for this account (`CreditFacilityValidationException`, checked in the repository ahead of the DB `.unique()` constraint for a clearer error, with the DB constraint itself as the real, race-safe guarantee); and, if `linkedPaymentAccountId` is supplied, that account exists and is profile-owned (existence/ownership only -- **never balance-class** -- `linkedPaymentAccountId` is informational metadata per §12.1, not an enforced payment source; `CreditFacilityRepository`/`TransactionRepository` never read it to decide how a payment transfer is recorded).
- `CreditFacilityRepository.availableCredit({required Money creditLimit, required Money amountOwed})` is a static, stateless helper: `creditLimit - amountOwed`, reusing `Money.operator-`'s own `_requireSameCurrency` check rather than reimplementing currency-safety. **Available credit is never persisted** -- no column exists for it anywhere in `CreditFacilityDetails`; every call site derives it at read time from the facility's `creditLimitMinorUnits` and the account's current `FinanceEngine.accountBalance` (amount owed).
- **Zero-credit-limit decision (explicit, per this checkpoint's own instruction to decide and document it):** a `creditLimit` of exactly zero is **allowed**; only a negative limit is rejected. Rationale: nothing in this V1 slice enforces the limit against an actual purchase (no "purchase would exceed available credit" check exists or was requested by this checkpoint's 20-item test list), so a zero-limit facility is a legitimate transient state -- for example, a card added before its real limit has been confirmed -- and rejecting it would add an arbitrary floor with no corresponding behavior to justify it. A future checkpoint that adds purchase-time limit enforcement can revisit this if needed.
- **`minimumPayment` is deliberately not implemented** in this checkpoint's `CreditFacilityDetails` shape, per §12.1/§13.5's own text already deferring it; only `creditLimit`, `statementClosingDay`, and `dueDay` are modeled, matching this checkpoint's "do not invent large billing-cycle functionality that belongs later" instruction.
- No `updateMetadata`/`softDelete` method exists yet on `CreditFacilityRepository` -- a deliberate V1 scope decision (no required test exercises editing or removing a facility), following the same immutability-by-signature-shape precedent `AccountRepository`/`PaymentInstrumentRepository` already established, documented here rather than left as a silent gap.
- `lib/core/finance/financial_account_subtype.dart`: added `creditCard('creditCard')` between `wallet` and `legacyCardNeedsReview`. `checking`/`savings`/`deposit` remain deliberately still undefined, per §13.7's own note that `subtype`'s value set is a floor, not the full §12.1 ceiling, populated only as each checkpoint needs it. The existing generic `FinancialAccountSubtype.values` round-trip test in `test/core/finance/legacy_account_classification_test.dart` covers the new value automatically -- no test file needed a direct edit for this enum addition.
- **`FinanceEngine` is completely unmodified by this checkpoint.** Full audit of `lib/core/finance/finance_engine.dart` confirmed every required liability purchase/payment balance effect (purchase increases owed; payment reduces both the source asset and the destination liability; income targeting a liability throws `InvalidLiabilityOperationException`; a liability used as a transfer source throws the same; overpayment below zero throws `LiabilityOverpaymentException`; an exact payoff to zero succeeds) was already fully implemented by Checkpoint C's class-aware `accountBalance`. This checkpoint reuses that single balance engine as instructed ("do not create parallel credit-card balance arithmetic," "do not expose a second balance engine") -- there is still exactly one `accountBalance` function, with no new liability-specific branch added anywhere in it.
- `lib/core/database/repositories/transaction_repository.dart`: `recordExpense`/`recordTransfer` needed **no code change at all** to accept a liability `FinancialAccount` as a target -- both were already balance-class-agnostic (Checkpoint D's own attribution check operates on account/profile identity, not `balanceClass`), so a credit-card purchase is simply an ordinary `recordExpense` call with `accountId` set to the liability account, and a credit-card payment is an ordinary `recordTransfer` call with the liability account as the destination; `FinanceEngine`, invoked later at balance-read time, is what actually applies the different liability effect table. The one genuine code change is a new, additive check inside the existing `_validatePaymentInstrumentAttribution`: when the target `account.isLiability`, the attributed instrument's `instrumentType` (decoded via `PaymentInstrumentType.fromStorageValue`, matching this file's existing decoupled-from-`PaymentInstrumentRepository` convention -- it queries `payment_instruments` directly and does not import the repository's own row extension) must be `creditCard`, or `InvalidPaymentInstrumentAttributionException` is thrown. This closes a gap Checkpoint D's own validation left open: D's account-class validation at *instrument-creation* time already makes it structurally impossible for a `debitCard`/`cashCard` instrument to ever be linked to a liability account in the first place (so item 11's debit-card-on-liability case was already blocked before this checkpoint) -- but it did **not** stop a `paymentService`/`other`-typed instrument, which D's own validation table permits to link to *either* balance class, from attributing a liability purchase. The new check closes exactly that gap and is proven by an explicit test (a `paymentService` instrument attributing the same liability account's purchase is rejected), not merely by the already-covered debit-card case.
- Test coverage: `test/core/database/repositories/credit_facility_repository_test.dart` (new, 17 tests: items 1-6 -- valid creation, asset-account rejection, wrong-liability-subtype rejection, credit-limit validation (positive/zero-allowed/negative-rejected/currency-mismatch/day-of-month range), one-facility-per-account, ownership/profile rules -- a `requireActiveForAccount`-not-found case, and item 18's four `availableCredit` sub-cases: exact, fully-paid-off, fully-drawn, currency-mismatch-throws); `test/core/database/repositories/transaction_repository_test.dart`'s new `Checkpoint E -- credit-card purchase/payment semantics` group (12 tests covering items 7-17: purchase increases debt exactly, purchase leaves an unrelated bank asset unchanged, matching credit-card-instrument attribution succeeds, wrong-account credit-card-instrument attribution fails, debit-card-instrument attribution to a liability purchase fails, the `paymentService`-on-liability gap-closing case above, a soft-deleted-instrument attribution fails, a payment reduces both asset and liability balances correctly, a payment is excluded from `incomeExpenseTotals`, exact payoff to zero succeeds, overpayment throws `LiabilityOverpaymentException`, and a cross-currency credit-card payment is rejected via `CurrencyMismatchException`); and `test/core/database/credit_facility_migration_test.dart` (new -- item 19: a populated v10-to-current upgrade with a seeded liability/creditCard account, a creditCard payment instrument, and a `payment_instrument_id`-tagged transaction, asserting zero `credit_facility_details` rows are fabricated and every pre-existing account/instrument/transaction row is numerically unchanged, followed by proving a brand-new facility can be created against the migrated account; item 20 -- an empty v10-to-current upgrade, and a fresh v11 `onCreate`, both succeed cleanly). No existing test's expected value was changed; no existing test file's assertions were weakened.
- These changes exist in the working tree only (HEAD is still `fe6b3ad`, the commit Checkpoint D's report was verified against); nothing has been staged or committed.

### 13.11 Implementation status (Checkpoint F — deposit metadata + exact calculations)

**This subsection is additive and does not modify §§12-13.10 above -- it records what Checkpoint F actually built against those unchanged sections, following the same "implementation status" convention §13.7/§13.8/§13.9/§13.10 above already established.**

- Schema version 12. `lib/core/database/tables.dart`: added `DepositDetails` (`id`, `profileId`, `accountId` -- `.unique()` + `.references(Accounts, #id)`, the identical one-to-one enforcement `CreditFacilityDetails.accountId` already established -- `depositType`, `termNumber`, `termUnit`, `startDate`, `maturityDate`, `interestRateBasisPoints`, `interestMethod`, `compoundingFrequency` nullable, `autoRenew`, `renewalMode` nullable, `interestDestinationAccountId` nullable `.references(Accounts, #id)`, `installmentAmountMinorUnits` nullable, `installmentFrequency` nullable, `createdAt`/`updatedAt`/`deletedAt` nullable, `syncVersion`/`syncStatus`). `AppDatabase.migration`'s `from < 12` branch is exactly one statement: `m.createTable(depositDetails)`. Identically to Checkpoint E's own v10→v11 step, this only CREATEs a brand-new, empty table -- it cannot fail against any historical fixture the way Checkpoint D's Task 3 regression did, and none of the (now seven) pre-existing migration-fixture files needed any change for this checkpoint.
- **`DepositDetails` has NO `principal`/balance column at all.** The frozen field list (docs/20 §12.1) has none, and this checkpoint's own architecture principle ("DepositDetails itself does NOT carry a second ledger balance") makes that explicit: a deposit's principal is simply its linked `FinancialAccount`'s own balance, read the ordinary way via `FinanceEngine.accountBalance` -- exactly like any other asset account, with zero special-casing. `DepositCalculator.calculateSimpleInterest`/`calculateCompoundInterest` both take `principal` as a `Money` PARAMETER (validated non-negative), never a stored field -- this is also where "item 7: principal validation" is exercised (in `test/core/finance/deposit_calculator_test.dart`, not the repository's own test file, since the repository has no principal input to validate).
- **Exact field-name/value deviation from this checkpoint's own generic template, deliberately in favor of the frozen docs/20 §12.1 contract** (per this checkpoint's own instruction: "check the existing architecture docs and use the frozen terminology already recorded there"): `depositType` values are `fixed`/`shortTerm`/`recurring`/`other` (not "fixedTerm"/"recurringDeposit"); the rate field is the already-frozen `interestRateBasisPoints` (an integer, e.g. `550` = 5.50%), not a decimal string; the method field is `interestMethod` (not "interestCalculationMethod"); and no `notes`/`linkedFundingAccountId` column exists -- neither appears in docs/20 §12.1's frozen field list, so neither was added, matching this checkpoint's own "do not expand scope just because a field could be useful" instruction.
- **New enums, all following the enum-as-text convention** (`BalanceClass`/`FinancialAccountSubtype`/`PaymentInstrumentType`/`CardNetwork`'s precedent): `DepositType` (`fixed`/`shortTerm`/`recurring`/`other`), `DepositInterestMethod` (`simple`/`compound`), `DepositTermUnit` (`days`/`months`/`years`), `DepositCompoundingFrequency` (`monthly`=12/`quarterly`=4/`semiannual`=2/`annual`=1/`atMaturity`=1 periods-per-year), `DepositInstallmentFrequency` (`weekly`/`monthly`/`quarterly`/`yearly` -- purely descriptive, docs/20 §12.9). **Deliberate deviation from the `FinancialAccountSubtype`/`PaymentInstrumentType` precedent:** every one of these five `fromStorageValue` methods THROWS on an unrecognized value rather than falling back to a safe default. Those two earlier enums had to tolerate real pre-existing production data written before the enum existed (legacy `accounts.type` strings); `deposit_details` is a brand-new table with zero pre-existing rows, so a corrupt value indicates a genuine bug, not legacy drift -- and several of these values directly drive `DepositCalculator`'s arithmetic or `DepositRepository`'s field-gating, where a silently-wrong fallback would silently misstate a financial calculation or bypass a validation rule.
- `lib/core/finance/financial_account_subtype.dart`: added `deposit('deposit')` between `creditCard` and `legacyCardNeedsReview`. The existing generic `FinancialAccountSubtype.values` round-trip test already covers it automatically -- no test file needed a direct edit for this enum addition, exactly as Checkpoint E's `creditCard` addition required none either.
- **`FinanceEngine` is completely unmodified by this checkpoint** -- the identical discovery Checkpoint E made for liability accounts applies here for a `deposit`-subtype asset account: `FinanceEngine.accountBalance`'s existing asset-side effect table (opening balance, income adds, expense subtracts, transfer source subtracts, transfer destination adds) already correctly implements every required deposit balance effect, since a deposit is simply an ordinary asset account. No new liability-style branch, no new balance-class value, no code change of any kind.
- **`TransactionRepository.recordExpense`/`recordIncome`/`recordTransfer` needed NO code change at all** for funding/maturity/interest -- all three were already fully balance-class- AND subtype-agnostic before this checkpoint (Checkpoint D/E's own attribution checks operate on account identity/liability-ness, never `subtype`). Funding a deposit and a maturity principal movement are both simply ordinary `recordTransfer` calls (asset→asset, exactly like any other transfer, so `TransactionType.transfer`'s existing exclusion from `incomeExpenseTotals` already keeps neither counted as income or expense with zero new code); interest actually credited is simply an ordinary `recordIncome` call (optionally targeting a different account via `interestDestinationAccountId`, which is purely informational metadata `TransactionRepository` never reads). This is proven by `test/core/database/repositories/transaction_repository_test.dart`'s new `Checkpoint F -- deposit funding/maturity/interest semantics` group, not by any production code change.
- **Calendar-safe month arithmetic is now a single shared routine, not two.** `lib/core/finance/calendar_month_math.dart` (new) extracts `RecurringSchedule`'s own private `_lastDayOfMonth`/anchor-based month-clamping algorithm (previously inlined in `RecurringSchedule._occurrenceAt`) into public `lastDayOfMonth`/`addWholeCalendarMonths` functions; `lib/features/recurring/domain/recurring_schedule.dart` is updated to call the shared function instead of its own inlined copy -- a pure extraction with **zero behavior change** (the exact same algorithm, same results; `recurring_schedule_test.dart`'s existing Jan-31/leap-year/month-end assertions are unaffected and were used directly as hand-verified fixtures for the new `calendar_month_math_test.dart`). `DepositRepository._computeMaturityDate` calls this same shared function for `termUnit: months`/`years`, satisfying docs/20 §12.7's explicit instruction to reuse the existing routine rather than write a second one.
- **`lib/core/finance/deposit_calculator.dart` (new): the exact, deterministic V1 interest engine**, fully decoupled from Drift/`FinanceEngine`/`TransactionRepository` (matching `FinanceEngine`'s own testing philosophy, per this checkpoint's explicit instruction). Two static methods, `calculateSimpleInterest`/`calculateCompoundInterest`, both returning a `DepositEstimate` (`estimatedInterest`/`estimatedMaturityValue`, both `Money`) -- **never persisted anywhere**; there is no column on `DepositDetails` for either, proven by `deposit_repository_test.dart`'s item-25 test (computing an estimate repeatedly has zero effect on the stored row).
- **Deliberate, load-bearing deviation from this checkpoint's own literal instruction to round via `MoneyRounding.roundHalfUpToMinorUnits` (a `Decimal`-typed function):** Actual/365 simple interest divides by 365 = 5 × 73, and compound interest divides the annual rate by a `periodsPerYear` of 12/4/2 -- none of 73, 12's factor of 3 are powers of 2 or 5, so `1/365` and `1/12` (etc.) have NO exact, finite base-10 (`Decimal`) representation. Forcing either through `Decimal` before the "round once, at the end" step would require truncating a repeating decimal FIRST, silently reintroducing, at an intermediate step, exactly the imprecision that rule exists to prevent. `deposit_calculator.dart` instead implements a small private `_ExactFraction` (`BigInt` numerator/denominator, explicitly sanctioned by this checkpoint's own "Use the project's existing exact Decimal / BigInt / Money patterns" instruction) and performs the identical ROUND-HALF-UP-away-from-zero policy (ADR-018) via exact `BigInt` comparison, applied exactly once, at the very end, on a value `Decimal` itself cannot hold. **This is the single area of this checkpoint most worth extra Windows/runtime scrutiny** -- see the final report's own callout.
- **Simple interest** (docs/20 §12.8): `interest = principal × (rate/10000) × (actualDays/365)`, rounded once, HALF UP; `maturityValue = principal + interest` (exact integer addition, never independently rounded -- docs/20's own formula ordering). **Date convention, explicitly decided and tested:** `[startDate, maturityDate)` -- `actualDays = maturityDate.difference(startDate).inDays`; the start date itself is not an earned day, every day up to but not including the maturity date is (a 30-day deposit earns interest for exactly 30 days). Leap years never change the 365 denominator (docs/20's explicit instruction) -- only `actualDays` (the numerator) is affected, because it comes from real calendar subtraction; proven by an explicit Jan-1→Mar-1 comparison across a leap year (2028, 60 days) and a non-leap year (2026, 59 days) in `deposit_calculator_test.dart`.
- **Compound interest** (docs/20 §12.8): `maturityValue = principal × (1 + rate/n)^(n×t)`, `n×t` always resolved to a whole integer number of periods (never a fractional exponent) by matching `termNumber`/`termUnit` against `compoundingFrequency`'s calendar-month period length (monthly=1/quarterly=3/semiannual=6/annual=12 months); `termUnit: days` is rejected for every month-based frequency (`AmbiguousCompoundPeriodException`, new), as is a term that isn't an exact whole multiple of the period length (e.g. 4 months compounded quarterly). Rounds once, HALF UP, on `maturityValue`; `interest = maturityValue − principal` (exact integer subtraction, per docs/20's formula ordering for this case).
- **`compoundingFrequency: atMaturity` -- one deliberate correction beyond a literal reading of docs/20 §12.8.** Docs/20 describes `atMaturity` as "one compounding period over the whole term -- equivalent to simple interest for that case." A first draft of this implementation read that as "always apply the flat, un-scaled annual rate once, regardless of term length" -- which is WRONG: it would silently overstate interest for any `atMaturity` term shorter than a year (e.g. a 30-day deposit would earn a full year's interest) and understate it for any term longer than one, breaking the very "equivalent to simple interest" property docs/20 asserts (real simple interest always scales by `termDays/365`). The shipped implementation instead scales `atMaturity`'s one period's rate by the term's exact fraction of a year (`totalMonths / 12`, still an exact `BigInt` fraction) -- so a 12-month `atMaturity` term is byte-for-byte identical to one year of simple interest at the same rate (proven by an explicit test), and a 6-month term earns exactly half that (also proven by an explicit test, specifically to distinguish this from the flawed flat-rate reading). This also means `atMaturity` is NOT exempt from the `termUnit: months`/`years` requirement every other `compoundingFrequency` has -- a day-based `atMaturity` term is rejected too (`AmbiguousCompoundPeriodException`), because its rate still needs an exact months-fraction to scale by.
- **`lib/core/database/repositories/deposit_repository.dart` (new): `DepositRepository`**, mirroring `CreditFacilityRepository`'s structure and discipline. `createDetails` validates, in order: account exists/profile-owned/active/`isAsset`/`subtype: deposit`; `termNumber >= 1` (`ArgumentError` -- unlike a credit limit, there is no legitimate zero-length deposit term); `interestRateBasisPoints >= 0` (zero explicitly allowed, per item 21); computes `maturityDate` deterministically from `startDate`/`termNumber`/`termUnit` (plain calendar-day addition for `days`; `calendar_month_math.dart` for `months`/`years`) and, if an `explicitMaturityDate` is also supplied, rejects it unless it exactly agrees with the computed value (item 16 -- "validate consistency rather than silently prefer one"; there is still only ONE stored `maturityDate` column, always the computed value); `interestMethod`/`compoundingFrequency` gating (required for `compound`, must be absent for `simple`); `depositType`/installment-field gating (`installmentAmountMinorUnits`/`installmentFrequency` rejected unless `depositType: recurring`; neither is REQUIRED even then); one-deposit-per-account (pre-check + the table's own `.unique()` constraint); and, if `interestDestinationAccountId` is supplied, existence + profile ownership + **currency match** (`CurrencyMismatchException`).
- **`interestDestinationAccountId` is currency-validated; `CreditFacilityDetails.linkedPaymentAccountId` deliberately is not.** This is an intentional asymmetry, not an inconsistency: interest is actually postable to `interestDestinationAccountId` in V1 via an ordinary `TransactionRepository.recordIncome` call with no FX step, so a currency mismatch would silently misstate which currency the posted interest is denominated in -- `linkedPaymentAccountId` is purely informational and never reaches a posting code path at all. A self-referencing `interestDestinationAccountId` (equal to the deposit's own `accountId`) is explicitly ALLOWED (item 24) -- reinvesting interest back into the same deposit is a legitimate real-world pattern, not a circular relationship; this V1 schema has only this one optional account-link column, so no genuinely circular (two-FK) relationship could even be constructed here regardless.
- No `updateMetadata`/`softDelete` method exists yet on `DepositRepository` -- the same deliberate V1 scope decision `CreditFacilityRepository` already made (no required test exercises editing or removing a deposit), documented here rather than left as a silent gap.
- Test coverage: `test/core/finance/calendar_month_math_test.dart` (new, 14 tests: items 13/14/15 -- Jan-31-plus-one-month, leap-day, month-end/year-transition behavior, all using values already hand-verified by `recurring_schedule_test.dart`'s own pre-existing, unmodified assertions); `test/core/finance/deposit_calculator_test.dart` (new, 23 tests: items 8/9/10/11/12/17/18/19/20/21, plus the atMaturity-scaling correction above and negative-input rejections); `test/core/database/repositories/deposit_repository_test.dart` (new, 25 tests: items 1-6, 16, 22/23/24, a `requireActiveForAccount`-not-found case, item 25, and the term/rate/interestMethod/depositType gating rules); `test/core/database/repositories/transaction_repository_test.dart`'s new `Checkpoint F` group (4 tests covering items 26/27/28: funding-is-transfer, maturity-is-transfer, interest-is-income, plus a variant proving a separate `interestDestinationAccountId` never touches the deposit's own balance); and `test/core/database/deposit_migration_test.dart` (new -- item 29: a populated v11-to-current upgrade with a seeded deposit account and an interest-income transaction, asserting zero `deposit_details` rows are fabricated and every pre-existing row is numerically unchanged, then proving a brand-new deposit's details can be created against the migrated account; item 30 is satisfied by inspection, not a new test -- exactly like Checkpoint E's identical v10→v11 step, a pure `CREATE TABLE` cannot fail against any of the other seven pre-existing historical migration fixtures, none of which needed any change). No existing test's expected value was changed; no existing test file's assertions were weakened.
- These changes exist in the working tree only (HEAD is still `fbfd355`, the commit Checkpoint E's report was verified against); nothing has been staged or committed.

### 13.12 Implementation status (Checkpoint G — Add Account UX)

**This subsection is additive and does not modify §§12-13.11 above -- it records what Checkpoint G actually built against those unchanged sections, following the same "implementation status" convention §§13.7-13.11 above already established. No schema change, no `FinanceEngine` change, and no transaction-semantics change were needed or made.**

- **UI-type → `balanceClass`/`subtype` mapping, the single source of truth.** `lib/core/finance/account_creation_kind.dart` (new): `AccountCreationKind` enum -- `cash`/`bank`/`savings`/`wallet`/`deposit`/`creditCard` -- each carrying its frozen `(legacyTypeLabel, balanceClass, subtype)` triple. `savings` deliberately maps to the SAME `FinancialAccountSubtype.bank` as `bank` (§13.5 open question 1, "bank is not split" -- no new subtype was added), distinguished afterward only by its own `legacyTypeLabel` (`'savings'`, stored in the presentation-only `Accounts.type` column). No `balanceClass`/asset-liability/`legacyCardNeedsReview` term is ever shown to the user -- this enum is the only place that vocabulary is bridged to the plain-language choice.
- **`AccountRepository.createClassifiedAccount` (new method, `account_repository.dart`): the first repository method able to create a liability account or a `deposit`-subtype account at all.** The pre-existing `createAccount` is completely unchanged and still the only path the (untouched) `EditAccountScreen`/legacy dropdown vocabulary uses; `createClassifiedAccount` takes an EXPLICIT `balanceClass`/`subtype` pair instead of inferring one from `classifyLegacyAccountType`'s closed legacy vocabulary. Opening amount is stored as the same non-negative, class-native magnitude `LedgerAccount.openingBalance` already documents (owned for asset, owed for liability) -- there is no sign flip anywhere in this checkpoint, and a negative amount is rejected (`ArgumentError`) regardless of which `balanceClass` is being created.
- **`lib/core/database/repositories/financial_institution_repository.dart` (new): `FinancialInstitutionRepository`**, exactly two methods (`watchActiveForProfile`, `findOrCreate`) -- deliberately not a full institution-management product, per the checkpoint's own instruction. `findOrCreate` reuses an existing active institution only on an exact, trimmed, case-insensitive name match for the same profile; it never fuzzy-matches. The Add Account form's institution field is a single optional text field, gated off entirely for `cash` (`AccountCreationKind.allowsInstitution`).
- **`lib/core/database/services/account_creation_service.dart` (new): `AccountCreationService`**, the ONLY caller that composes more than one repository call for a single account-creation operation -- introduced narrowly, per the checkpoint's own "if fully atomic repository composition requires a small application service, introduce one narrowly scoped service" instruction. It does not duplicate or re-implement any repository's own validation; it only sequences already-existing calls inside one `AppDatabase.transaction`.
  - `createSimpleAccount` (cash/bank/savings/wallet): a single `createClassifiedAccount` call, no transaction wrapper needed (already one atomic `INSERT`).
  - `createCreditCardAccount`: inside one transaction -- `createClassifiedAccount` (liability, `subtype: creditCard`) → `CreditFacilityRepository.createFacility` → `PaymentInstrumentRepository.createInstrument` (`instrumentType: creditCard`). This is exactly §12.6's frozen "one step, three rows, one transaction" contract, now realized end-to-end through the app for the first time. Returns `CreditCardCreationResult { accountId, creditFacilityId, paymentInstrumentId }`.
  - `createDepositAccount`: inside one transaction -- `createClassifiedAccount` (asset, `subtype: deposit`) → `DepositRepository.createDetails`. Returns `DepositCreationResult { accountId, depositDetailsId }`. The deposit's principal is passed straight through as the new account's opening balance -- `DepositDetails` still has no balance column of its own (§12.1, unchanged since Checkpoint F).
  - **Failure safety**: if any step after the first throws, `AppDatabase.transaction` rolls back every write already made earlier in the same call, including the `Accounts` insert -- proven by `test/core/database/services/account_creation_service_test.dart`'s dedicated rollback tests (an invalid credit limit, an invalid `last4`, a compound method missing `compoundingFrequency`, and a `termNumber < 1`), each asserting zero rows exist in EVERY table the call would have touched afterward.
- **Never collects a full card number, CVV/CVC, PIN, or banking password** -- no field, form, or repository parameter anywhere in this checkpoint's new code accepts one; only `last4` (exactly 4 digits, existing `PaymentInstrumentRepository._validateLast4` rule, unchanged) and descriptive metadata (network, expiry, statement/due day) are ever asked for a credit card.
- **New routes** (`lib/core/routing/app_routes.dart`/`app_router.dart`): `AppRoutes.addAccount` (`/accounts/add`, the type chooser) and `AppRoutes.addAccountFormPath` (`/accounts/add/:kind`, the adaptive form). `addAccount` is registered BEFORE `AppRoutes.accountDetailPath` in `app_router.dart`'s route list -- the same literal-before-parameterized precedent `addTransaction`/`transactionDetailPath` already established, since both are 2-segment `/accounts/...` paths GoRouter would otherwise match in the wrong order.
- **New screens**: `lib/features/accounts/presentation/add_account_type_screen.dart` (`AddAccountTypeScreen`, the icon-led chooser -- one `AppCard`+`AppIconTile` row per `AccountCreationKind`, reusing existing shared primitives rather than a new list-row component) and `add_account_form_screen.dart` (`AddAccountFormScreen`, the adaptive form: common name/currency/amount/institution fields, plus credit-card-only or deposit-only fields shown only for their own kind). `lib/features/accounts/presentation/account_creation_kind_presentation.dart` (new) holds the shared per-kind title/description/icon both screens read, rather than each keeping its own copy of that switch.
- **`accounts_screen.dart`**: the FAB now calls `context.push(AppRoutes.addAccount)`; the old `_AddAccountDialog`/`_AddAccountDialogState` classes (a bare name+type dialog with no opening-balance field at all) are removed entirely, along with their now-unused imports (`CurrencyRegistry`, `account_form_fields.dart`, `providers.dart`).
- **`account_type_presentation.dart`**: added `'savings'`/`'deposit'`/`'creditCard'` cases to `accountTypeDisplayLabel`/`accountTypeIcon` ONLY -- `kAccountTypes` (the closed legacy set `EditAccountScreen`'s own dropdown still uses) is untouched, so a real account created by this checkpoint still renders a recognizable label/icon on the (unmodified, Checkpoint H's job) Accounts list/detail screens.
- **Deposit "Estimated interest/maturity" preview**: `AddAccountFormScreen` calls `DepositCalculator.calculateSimpleInterest`/`calculateCompoundInterest` directly -- it never re-implements either formula. The only locally-computed value is the preview maturity DATE, via the same public `addWholeCalendarMonths` helper `DepositRepository._computeMaturityDate` itself calls (not a re-implementation of a second calendar routine -- see §12.7/Checkpoint F's own "one shared routine" rule). The preview is always labeled "Estimated" and is never sent to any repository -- it exists purely for display.
- **Deliberate V1 deferrals** (none required a schema change; each is a scope trim, not a discovered blocker):
  - **`explicitMaturityDate` is not exposed as an independent input field.** `DepositRepository.createDetails` already REJECTS an `explicitMaturityDate` that disagrees with the value computed from `startDate`/`termNumber`/`termUnit` -- exposing it as a free-form field a user could mistype would only produce a confusing validation error for no benefit, since the computed value is shown read-only in the "Estimated maturity date" preview anyway.
  - **`DepositDetails.renewalMode`** (a free-form, never-read-by-code descriptive string, §12.1) is not exposed as its own input in V1; `autoRenew` (the boolean this checkpoint's brief actually asks for) is exposed via a switch and always passes `renewalMode: null`.
  - **Debit/cash card attachment to a new bank account is deferred**, not implemented -- the brief allows this only "if small and well tested"; given this checkpoint's already-large surface area, it was left out entirely rather than added without matching test coverage. No debit-card `FinancialAccount` is ever created by any path in this checkpoint (nor was one before it).
  - **Cheque/check readiness**: no cheque table, field, UI, or anticipatory schema column was added -- the Add Bank Account flow (a `bank`/`savings` `AccountCreationKind`) creates only the ordinary balance-bearing `FinancialAccount` a future checkpoint could attach cheque capability to later; nothing here forecloses that or models a cheque as its own account/balance.
- **Existing tests deliberately updated (not merely preserved), transparently, because they hard-coded the removed dialog's exact mechanics:**
  - `test/widget/accounts_screen_test.dart`'s `"H: navigation/action regression"` test: previously asserted the old `AlertDialog`'s exact title/fields/buttons and submitted through it. Now drives a real `GoRouter` (`AccountsScreen` → `AddAccountTypeScreen` → `AddAccountFormScreen`) under the Japanese locale, preserving the ORIGINAL testing intent -- a fully localized, real end-to-end account creation that appears in the (still Japanese) list -- through the new mechanics.
  - `test/widget/theme_compatibility_test.dart`'s `"Phase 5.8"` dark-theme test: previously asserted the old dialog's `AlertDialog`/title/field text render without exceptions under Dark. Now drives the same real `GoRouter` flow under `AppThemeStyle.dark` and asserts both the chooser and the form render without exception, preserving the original "renders cleanly under Dark" guarantee.
  - Both updates are additive to the flow's mechanics only -- neither test's underlying financial/localization/theme assertion was weakened, and no other existing test file was touched.
- **New test coverage**: `test/core/database/services/account_creation_service_test.dart` (new, 13 tests) -- `createSimpleAccount` for all four single-record kinds (correct `balanceClass`/`subtype`/opening amount/currency; `savings`/`bank` sharing one `subtype` while keeping distinct `type` labels; a null opening balance defaulting to zero); `createCreditCardAccount` success (all three rows created and correctly linked, non-negative owed-amount semantics) and two rollback-on-failure cases (invalid credit limit; invalid `last4`), each asserting zero rows in every touched table afterward; `createDepositAccount` success (both rows created, principal only on the `FinancialAccount`) and two rollback-on-failure cases (compound method missing `compoundingFrequency`; `termNumber < 1`).
- **Deferred (not implemented in this pass), stated plainly rather than silently skipped:** dedicated widget-level coverage for every one of the checkpoint brief's 30 enumerated test items (in particular items 1-2, 25-28 -- entry point, chooser display, successful-creation navigation, localization smoke, large-text/text-scale layout, dark-theme smoke beyond the one updated Phase 5.8 case) was not added as new standalone test files in this pass, beyond the two existing tests updated above (which do exercise entry point, localized end-to-end creation, real navigation, and a dark-theme smoke case as a side effect of preserving their original intent) and the service-level suite. The service layer -- the highest-risk surface for silent data corruption (multi-record atomicity) -- has full coverage; broader per-kind widget-test coverage (credit-card/deposit form field-level validation, cancel/back-creates-nothing, large-text/RTL smoke for the two new screens specifically) is the clearly recommended next increment before Checkpoint H, and is called out explicitly rather than assumed complete.
- These changes exist in the working tree only (HEAD is still `2178ad7`, the commit this checkpoint's brief names as authoritative); nothing has been staged or committed.

### 13.12.1 Android regression repair (still Checkpoint G -- not Checkpoint H)

**This subsection is additive and does not modify §§12-13.12 above.** Manual
Android testing after §13.12 landed found a real crash §13.12's own text did
not anticipate: opening Edit on a G-created credit card threw

> There should be exactly one item with [DropdownButton]'s value: creditCard.
> Either zero or 2 or more [DropdownMenuItem]s were detected with the same
> value.

**Root cause.** `EditAccountScreen`'s type dropdown (`account_form_fields.dart`'s
`AccountIdentityFormFields`) built its `DropdownMenuItem`s from `kAccountTypes`
(`cash`/`bank`/`card`/`wallet` -- unchanged since before Checkpoint G, per
§13.12's own note). `AccountCreationKind.legacyTypeLabel` -- what Checkpoint G
actually stores in the presentation-only `Accounts.type` column -- can also be
`savings`/`deposit`/`creditCard`, none of which were in that list. All three had
the identical latent defect; `cash`/`bank`/`wallet` happened to already match a
legacy label, so only `savings`/`deposit`/`creditCard` were ever reachable
through this bug. `AccountDetailScreen` never crashed -- it only reads
`accountTypeDisplayLabel`/`accountTypeIcon` (already extended for all three in
§13.12), never a `DropdownButtonFormField`.

**Repair, aligned with §13.2's own framing** ("the generic screen remains the
correct destination for every account that doesn't [have a dedicated
specialized screen]" -- `creditCard`/`deposit` don't have one yet; that is
still §13.4 checkpoint F/H's job, not this repair's):
- `account_type_presentation.dart`: added `kEditableAccountTypeLabels`
  (`kAccountTypes` + `'savings'` -- safe because `type` is presentation-only
  and `savings`/`bank` already share one `FinancialAccountSubtype`, per
  `AccountCreationKind.savings`'s own doc) and `isAccountTypeEditable(subtype)`
  (`false` only for `creditCard`/`deposit`). `kAccountTypes` itself is
  unchanged.
- `account_form_fields.dart`: `AccountIdentityFormFields` gained `typeOptions`
  (defaults to `kAccountTypes`, so any other caller is unaffected) and
  `typeEditable` (defaults to `true`). When `typeEditable` is false, it renders
  a read-only type display (mirroring the existing read-only currency field)
  instead of a dropdown. When true, its dropdown items are `{...typeOptions,
  type}` -- the current value is always included even if absent from
  `typeOptions`, so this specific "value has no matching item" crash cannot
  recur for any future/unexpected `type` string either.
- `edit_account_screen.dart`: passes `typeOptions: kEditableAccountTypeLabels`
  and `typeEditable: isAccountTypeEditable(account.subtypeValue)`.
- **No change to `AccountRepository.updateAccount`** -- it already has no
  `balanceClass`/`subtype` parameter (§12.2's own frozen invariant), so no
  path through this screen, editable or not, before or after this repair,
  could ever mutate either. This repair changes only which `type` values the
  UI is willing to display as an editable choice versus a fixed label -- it
  changes no immutability guarantee and required no repository change.
- No schema, migration, `FinanceEngine`, `DepositCalculator`, transaction, or
  dashboard change. No new user-facing strings (every string this repair
  displays -- `accountTypeLabel`, and each `accountTypeDisplayLabel` case --
  already existed from §13.12 onward).

**Result:** all six kinds Checkpoint G can create (`cash`/`bank`/`savings`/
`wallet`/`deposit`/`creditCard`), and every pre-Checkpoint-G legacy
representation (`cash`/`bank`/`wallet`/`card`, the last classified
`legacyCardNeedsReview`), open in Edit without exception. `deposit`/
`creditCard` show their type as a read-only label; every other subtype keeps
today's already-shipped free relabeling between `cash`/`bank`/`savings`/
`wallet`/`card`, unchanged.

**Deferred, explicitly, to a later checkpoint (not this repair):** an
account deactivation/closure/archive lifecycle (Android testing separately
found there is currently no way to close/deactivate an account without
destroying its history -- a real product gap, but a new feature, not a bug in
what Checkpoint G shipped); and Home/dashboard deposit-principal liquidity
presentation (a deposit's principal currently contributes to Home's balance
total the same as any other asset -- correct for net worth, potentially
misleading if read as "available money" -- deferred to Checkpoint I's
dashboard/net-worth/liquidity presentation work, per §13.3's own DEFER row for
the net worth screen).

### 13.13 Implementation status (Checkpoint I — Home dashboard net worth / available-money / liquidity presentation)

**This subsection is additive and does not modify §§12-13.12 above -- it records what Checkpoint I actually built against those unchanged sections, following the same "implementation status" convention §13.7-§13.12 above already established.**

**Scope note, stated explicitly per this checkpoint's own instruction to flag any conflict rather than silently resolve it:** §13.4's original one-line description of checkpoint I ("the dashboard's existing per-currency sum must explicitly exclude liability accounts from its asset total... net worth itself remains out of scope") and §13.3's DEFER row for "net worth screen/provider" both predate this checkpoint's actual, broader brief, which explicitly asked for net-worth-*ready* semantics to be computed and (conditionally) surfaced on the EXISTING Home dashboard -- not a new, dedicated "net worth screen." §13.3's own MUST row already lists "asset/liability totals; net-worth-*ready* semantics (not the screen itself)" as V1 foundation scope, so this is not a scope violation of that freeze -- only §13.4's terser one-line checkpoint-I description undersold what its own §13.3 MUST row already required. No screen/provider named "net worth" was added; `dashboardCurrencySummariesProvider` (the existing Home dashboard provider) gained two fields.

- **No schema or migration change.** `balanceClass`/`subtype`/`isActive`/`deletedAt` (§12.1/§12.2/Account Lifecycle Checkpoint) were already sufficient to express every distinction this checkpoint needed -- liquid vs. non-liquid, owned vs. owed, active vs. closed. No new column was added anywhere.
- **No `FinanceEngine` change.** `FinanceEngine.accountBalance` was already class-aware (§12.3/Checkpoint C) and already lifecycle-agnostic (it takes a `LedgerAccount` + a transaction list and has never read `isActive`/`deletedAt` at all) -- both properties this checkpoint's aggregation needed were already true before it started.
- **`lib/features/dashboard/presentation/dashboard_providers.dart`:** `CurrencyDashboardSummary.balance` (one ambiguous figure) is replaced by two explicit fields:
  - `availableBalance` -- immediately available/liquid money: `FinanceEngine.accountBalance`, summed over every account in this currency that is simultaneously **active** (`AccountRow.isActive`), an **asset** (`AccountRowX.isAsset`), and **not** `FinancialAccountSubtype.deposit`.
  - `netWorth` -- **Net worth = Assets − Liabilities** (this document's own frozen §4 definition, applied literally, for the first time, at the dashboard level): every account in this currency, active OR closed, an asset's balance added and a liability's balance (already a non-negative "amount owed" magnitude, never itself a stored negative number) subtracted.

  Both totals are produced by ONE loop over ONE call to `FinanceEngine.accountBalance` per account -- never two divergent calculations reading the same data differently. `_summaryForCurrency` now reads `allAccountsProvider` (active + closed) instead of `accountsProvider` (active-only); see the closed-account policy below for why.
- **Deposit treatment:** a `deposit`-subtype account's principal (its ordinary opening balance plus transactions -- `DepositDetails` itself has no balance column, §12.7/§13.11) counts fully toward `netWorth` (still an owned asset) and is explicitly excluded from `availableBalance` (locked, not currently spendable -- matching this document's own §5 "vault/lock icon, reinforcing that the money is not currently spendable" design intent for Fixed Deposit). `DepositCalculator`, interest/maturity calculation, and `DepositDetails` itself are completely untouched.
- **Credit-card/liability treatment:** a liability account's `accountBalance` (amount owed) is subtracted from `netWorth` and is never added to `availableBalance` under any condition -- a credit card's *available credit* (`CreditFacilityRepository.availableCredit`, §12.6) is a separate, pre-existing, unrelated concept (borrowing capacity, not cash owned) that this checkpoint does not touch or conflate with `availableBalance`. Zero-liability and non-zero-liability are both exercised by `dashboard_providers_test.dart`'s new tests (see below) -- a zero-balance credit card contributes zero to `netWorth`'s subtraction, exactly as it should.
- **Closed-account treatment and rationale.** Audited against the Account Lifecycle Checkpoint (already shipped, frozen, not reopened by this checkpoint) and this document's own §4/§12.2 immutability language; no explicit prior ruling existed for dashboard totals specifically, so the conservative policy this checkpoint's own brief specifies was applied: **closing an account must never make its balance, or its currency, silently disappear from net worth.** `netWorth` therefore includes every account regardless of `isActive`/`deletedAt`. `availableBalance`, by contrast, requires `isActive` -- a closed account cannot be selected for a new transaction (Account Lifecycle Checkpoint's own, unmodified rule), so its balance is not something the user can act on today, even though it is still owned. This is exactly the document's own framing: "selection availability and financial ownership are separate concepts." A practical, previously-latent consequence this checkpoint corrects as a byproduct: before this change, a currency whose only account had been closed disappeared from Home ENTIRELY (its whole `CurrencyDashboardSummary` never appeared, since `_summaryForCurrency` only ever iterated over `accountsProvider`'s active-only list and `currencyCodes` was derived from that same list) -- silently implying zero net worth in that currency. It now still appears, correctly showing `availableBalance: 0` and its true, preserved `netWorth`. `AccountLifecycleService` was not modified -- this is purely a dashboard read-path change.
- **Reactivating a closed account never duplicates financial value** -- by construction, not by any new guard: `netWorth`/`availableBalance` are both computed fresh, from the account's CURRENT `isActive` value and its ONE `FinanceEngine.accountBalance` result, every time the provider recomputes. There is no separate "closed-account total" ever added to an "active-account total"; a reactivated account simply starts satisfying `availableBalance`'s `isActive` condition again, and its balance -- already counted in `netWorth` throughout, closed or not -- is unaffected. Proven by `dashboard_providers_test.dart`'s explicit close→reactivate test.
- **`lib/features/dashboard/presentation/home_screen.dart` (presentation only, no new calculation):** `_HeroCurrencyCard`/`_SecondaryCurrencyCard` now show `availableBalance` as their one large, dominant figure (unchanged position/style/keys -- `heroCurrencyCard_<code>`/`secondaryCurrencyCard_<code>` are untouched) under the existing `totalAvailableBalance` caption, which is now accurate (previously ambiguous, per this checkpoint's own brief, because the figure it captioned used to silently include locked deposit principal). A new, single, restrained secondary line -- "Net worth: `<amount>`" (new key `homeNetWorthLine`) -- renders only when `netWorth != availableBalance` for that currency (i.e., only when the user actually holds a deposit and/or a liability account, active or closed, in that currency); for the common case (only cash/bank/savings/wallet accounts) it renders nothing at all, so the hero/secondary cards are exactly as visually restrained as before this checkpoint for the majority of users. No separate "Deposits"/"Liabilities" breakdown line was added -- this checkpoint's own brief listed that as something Home "may" show, not something it must, and the existing visual hierarchy (one dominant figure, minimal secondary text) argued against it. `_LivingCurrencyEquivalentLine`'s "≈ `<amount>`" line now converts `availableBalance` (the figure it sits directly under), not the old ambiguous `balance`. The "Accounts" list section below the summary cards, and every budget/goals/recurring-commitments section, are completely untouched -- they read `accountsProvider` (active-only) or unrelated providers, exactly as before.
- **Localization:** one new key, `homeNetWorthLine` (`"Net worth: {amount}"` / ja: `"純資産: {amount}"`), added to `app_en.arb`/`app_ja.arb` immediately after the existing `totalAvailableBalance` key, matching this file's own placeholder-metadata convention (see `couldNotLoadAccounts` for the precedent this follows in `app_ja.arb`). No other new strings were needed -- `totalAvailableBalance` itself is reused unchanged.
- Test coverage: `test/core/dashboard/dashboard_providers_test.dart`'s existing two tests were updated (mechanical rename only -- `.balance` to `.availableBalance`, with `.netWorth` added as an additional, strictly-stronger assertion in the scenario that already had no deposit/liability account, where the two values are necessarily equal) plus a new `Checkpoint I` group covering: cash/bank/savings/wallet each contributing to `availableBalance`; a deposit contributing to `netWorth` but not `availableBalance`; a zero-balance and a non-zero-balance credit-card liability, both correctly excluded from `availableBalance` and correctly subtracted from `netWorth`; a mixed portfolio (cash + bank + savings + wallet + deposit + credit card) producing exact expected `availableBalance`/`netWorth` totals; a closed account's balance surviving in `netWorth` while disappearing from `availableBalance`; a close-then-reactivate sequence proving no value is duplicated; and the pre-existing zero-account empty-list test (unmodified). `test/widget/home_screen_test.dart` gained tests confirming the new "Net worth" line appears only when it differs from the available balance and is absent otherwise, that every pre-existing budget/goals/recurring/accounts-list assertion is unaffected, and narrow-width (320px) / large-text-scale (1.6x-2.0x) rendering of the changed summary cards produces no overflow.
- These changes exist in the working tree only (baseline `c3f8873`); nothing has been staged or committed.

### 13.14 Implementation status (Checkpoint J — Deposits + Private Net Worth)

**This subsection is additive and does not modify §§12-13.13 above -- it records what Checkpoint J actually built against those unchanged sections, following the same "implementation status" convention §13.7-§13.13 above already established.**

**Audit findings (performed before any code change, per this checkpoint's own instruction):**

- **Savings vs. Bank persistence.** `AccountCreationKind.savings` (the Add Account UX's own classification mapping, unchanged by this checkpoint) already, deliberately, maps to `FinancialAccountSubtype.bank` -- the exact same subtype `AccountCreationKind.bank` maps to. The only persisted distinction between a user's "Savings" and "Bank" account today is the free-text, presentation-only `Accounts.type` legacy label (`'savings'` vs. `'bank'`), which `FinanceEngine`, `dashboardCurrencySummariesProvider`, and this checkpoint's new `netWorthSummariesProvider` all ignore -- balance/asset/liability/net-worth math is driven entirely by `balanceClass`/`subtype`, never by `type`. This is a genuine, pre-existing, documented limitation (not a bug introduced here): Savings cannot be distinguished from Bank in any accounting or filtering logic, only in the account's own display label. Per this checkpoint's explicit instruction, **no migration was added to fix this** -- Savings continues to behave exactly as Bank everywhere it matters financially.
- **No pre-existing Net Worth screen, route, or provider existed anywhere in the codebase** before this checkpoint (confirmed via search) -- `netWorth`/`NetWorth` matched only Checkpoint I's `CurrencyDashboardSummary.netWorth` field and its Home-dashboard consumer.
- **No pre-existing deposit-specific Account Detail UI existed** -- `AccountDetailScreen` rendered every account (deposit or otherwise) through one generic identity/balance/opening-balance/created-date card.
- **`FinanceEngine.accountBalance` audited and found to have no correctness defect** relevant to this checkpoint -- per item 11's instruction, it was left completely unmodified (as it also was in Checkpoint I; see §13.13 above for why it was already class-aware and lifecycle-agnostic).

**Home privacy (items 1-3):**

- **`lib/features/dashboard/presentation/home_screen.dart`:** the conditional "Net worth: `<amount>`" line Checkpoint I added to `_HeroCurrencyCard`/`_SecondaryCurrencyCard` (§13.13 above) is removed entirely. Home now shows exactly one figure per currency card -- `availableBalance` (immediately available/liquid money) -- under the existing, unchanged `totalAvailableBalance` caption. This is a presentation-only removal: `dashboardCurrencySummariesProvider`/`CurrencyDashboardSummary.netWorth` (Checkpoint I's own calculation) is completely untouched and still computed every time the dashboard resolves -- nothing about Checkpoint I's underlying net-worth arithmetic was undone, only this one screen's decision to surface it.
- **The user's full net worth is now reachable ONLY via a deliberate tap on a new "Net Worth" row in More** (`lib/features/settings/presentation/more_screen.dart`, in the existing Money Tools group, alongside Currency Converter) **which opens a new, dedicated `NetWorthScreen`** (`lib/features/networth/presentation/net_worth_screen.dart`) at a new route, `AppRoutes.netWorth = '/net-worth'` (`lib/core/routing/app_routes.dart`, registered in `lib/core/routing/app_router.dart`). This is a privacy boundary implemented purely through navigation depth, not a settings toggle -- there is no way to reach a net-worth figure from Home, and no auto-navigation to the Net Worth screen from anywhere.
- The now-unused `homeNetWorthLine` ARB key (added by Checkpoint I, §13.13 above) was removed from both `app_en.arb`/`app_ja.arb`, since nothing references it any more.

**Net Worth screen definitions (items 4-6):**

- **`lib/features/networth/presentation/net_worth_providers.dart`** (new file) defines `netWorthSummariesProvider`, a plain `Provider<AsyncValue<List<NetWorthCurrencySummary>>>` that watches `activeProfileProvider`/`allAccountsProvider`/`ledgerProvider` (the same three dependencies, same loading/error propagation shape, as `dashboardCurrencySummariesProvider`) and computes, per currency the profile holds money in:
  - `assetLines`/`liabilityLines` -- one `NetWorthAccountLine` (`accountId`, `name`, `balance`, `isLiability`, `isDeposit`, `isClosed`) per account, `balance` always `FinanceEngine.accountBalance`'s unmodified result;
  - `totalAssets` = sum of every asset line's balance (**deposits included** -- unlike Home's `availableBalance`, which excludes them; this is the one deliberate difference between "available money" and "net worth" this whole checkpoint exists to surface on its own dedicated screen);
  - `totalLiabilities` = sum of every liability line's balance (always the non-negative "amount owed" magnitude, never itself negative);
  - `netWorth` = `totalAssets - totalLiabilities` (this document's own frozen §4 definition, identical to Checkpoint I's dashboard-level `netWorth` -- this screen is a per-account, per-currency BREAKDOWN of that same number, not a second, independently-derived figure that could ever drift from it).
  - This is a deliberately separate, additive provider rather than an extension of `CurrencyDashboardSummary` -- that type stays exactly as minimal as Checkpoint I left it (see §13.13's own rationale for why), and this checkpoint's own item 1 instruction ("do not undo the underlying Checkpoint-I net-worth calculation") is satisfied literally by touching nothing in `dashboard_providers.dart` at all.
- **Closed-account policy (item 5) is identical to Checkpoint I's dashboard policy, reapplied here without any new logic:** `netWorthSummariesProvider` watches `allAccountsProvider` (active + closed, never `accountsProvider`), so a closed account's balance always contributes fully to `totalAssets`/`totalLiabilities`/`netWorth` -- `isClosed` (`AccountRow.deletedAt != null`) is purely a display flag on `NetWorthAccountLine`, used only to render a quiet "Closed" badge next to that line, exactly the same badge convention `AccountDetailScreen` already uses. Available money (Home) continues to exclude closed accounts entirely, per Account Lifecycle's own unmodified rule -- the two screens' definitions remain exactly as distinct as Checkpoint I established.
- **No FX conversion anywhere (item 6):** `netWorthSummariesProvider` produces one independent `NetWorthCurrencySummary` per currency (ordered living-currency-first, then home-currency, then alphabetically -- the same ordering `dashboardCurrencySummariesProvider`'s own private helper uses, intentionally duplicated rather than exported purely to keep this new file self-contained). `NetWorthScreen` renders each as its own card/section; a user holding both JPY and USD money sees two entirely separate totals, never one blended figure. This repository has no trustworthy FX conversion policy for this purpose (§9/§20's own FX-reference-rate-only stance), so none was invented.

**Deposit Account Detail upgrade (items 7-8):**

- **`lib/features/accounts/presentation/account_detail_screen.dart`:** a new `_DepositDetailsSection` card renders, conditionally (`account.subtypeValue == FinancialAccountSubtype.deposit`, and only once a `DepositDetails` row actually exists for that account), immediately above the existing "Recent activity" section. It shows exactly the fields the persisted `DepositDetails` model actually supports and this checkpoint's own item 7 named: interest rate (`interestRateBasisPoints / 100`, formatted to two decimal places, e.g. `"2.50%"` -- no shared percent formatter existed in this codebase before this checkpoint; this is a minimal, local, display-only conversion, not a new shared abstraction), start date, maturity date, and term (`"<termNumber> <unit>"`, singular/plural ARB key pairs matching this project's existing non-ICU localization convention). "Current/principal information" is already shown, unduplicated, by the existing generic hero balance and "Opening balance" metadata row above it -- this new card does not repeat either. It deliberately does NOT show `DepositCalculator`'s estimated-interest/estimated-maturity-value figures (out of scope), `depositType`/`autoRenew`/`renewalMode`/installment fields (not listed in item 7's required minimum), or any status this persisted model cannot actually support.
- **`lib/core/finance/deposit_status.dart`** (new file) defines `DepositStatus { active, matured }` and its sole constructor, `DepositStatus.fromMaturityDate({required DateTime maturityDateUtc, required DateTime nowUtc})` -- a pure function of exactly two calendar-only UTC dates, with **no `AccountRow` parameter at all**. This is a structural guarantee, not a call-site convention, that deposit status can never become coupled to `AccountRow.isActive`/`deletedAt` (item 8's explicit independence requirement) -- `_DepositDetailsSection` calls it with only `DepositDetailsRow.maturityDate` and today's date, never anything from the account's own lifecycle state. `Active`/`Matured` are the only two states this model's data can determine reliably (maturity date alone) -- no "pending funding"/"withdrawn early" states were fabricated, since no column exists to support either.
- **`lib/features/accounts/presentation/account_providers.dart`:** a new `depositDetailsForAccountProvider` (`AutoDisposeProviderFamily<DepositDetailsRow?, String>`, backed by a private autodispose `StreamProvider.family` watching `DepositRepository.watchForAccount`) gives `AccountDetailScreen` this one account's `DepositDetails` row reactively, `null` once none exists -- same autodispose-family convention `accountByIdProvider` already established, since only this one screen, for one specific account, ever needs it.
- **No changes to `DepositRepository`, `DepositDetails`, `DepositCalculator`, or any deposit validation rule** -- this checkpoint only reads existing persisted data through one new provider and one new presentation card.

**Explicit non-scope, per item 10 (unchanged):** no automatic interest posting, no maturity transactions or transfers, no tax calculation, no early-withdrawal penalty, no external bank rate lookup, and no FX conversion were added anywhere in this checkpoint.

**Localization (item 13):** new keys added to both `app_en.arb`/`app_ja.arb` (with matching `@key` placeholder metadata where needed, following this file's existing convention): `netWorthTitle`, `netWorthScreenSubtitle`, `netWorthTotalLabel`, `totalAssetsLabel`, `totalLiabilitiesLabel`, `assetsSectionTitle`, `liabilitiesSectionTitle`, `assetsDepositBadge`, `netWorthEmptyMessage`, `couldNotLoadNetWorth`, `depositDetailsSectionTitle`, `depositInterestRateLabel`, `depositStartDateLabel`, `depositMaturityDateLabel`, `depositTermLabel`, `depositStatusActive`, `depositStatusMatured`, and singular/plural term-unit key pairs `depositTermUnitDay(s)`/`depositTermUnitMonth(s)`/`depositTermUnitYear(s)` (Japanese values are identical between the singular/plural pair in each case, since Japanese does not inflect for count -- the key-pair shape is kept anyway, matching this project's existing non-ICU convention rather than switching to ICU plurals for one language).

**Test coverage:**

- `test/core/finance/deposit_status_test.dart` (new): pure boundary tests for `DepositStatus.fromMaturityDate` (strictly before/exactly on/strictly after maturity, plus the one-day-either-side boundary), with no database or widget involved.
- `test/core/networth/net_worth_providers_test.dart` (new): mirrors `dashboard_providers_test.dart`'s own harness exactly (plain `test()`, real in-memory Drift DB). Covers: zero-account empty list; a cash asset's contribution; a deposit's contribution to `totalAssets` (and its `isDeposit` flag); a credit-card liability's contribution to `totalLiabilities`/subtraction from `netWorth` (and its non-negative line balance); a closed account's continued contribution and `isClosed` flag; multiple independent currencies with no combining; and a mixed cash+deposit+credit-card portfolio's exact expected breakdown.
- `test/widget/home_screen_test.dart`: the Checkpoint I "Home dashboard net worth line" test group is replaced by a new "Checkpoint J -- Home privacy" group, asserting the words "Net worth" never appear anywhere on Home (hero card, secondary card, or the screen as a whole) even when a deposit and/or liability account exists, that available balance alone still renders correctly, and that the budget/accounts-list sections remain unaffected -- including at a narrow 320px width and 1.6x text scale.
- `test/widget/more_screen_test.dart`: extended with the new "Net Worth" row across the existing English row-label list, the tap-navigation loop (against a stub `AppRoutes.netWorth` route), and the Japanese-locale label assertion (`純資産`).
- `test/widget/net_worth_screen_test.dart` (new): the empty state; assets/liabilities sections with correct totals and a deposit badge; multiple independent currencies (no combined total); a closed account's continued contribution and Closed badge; a negative net worth's visible marking; narrow-width (320px) + 1.6x text scale; and a Japanese-locale smoke test.
- `test/widget/account_detail_screen_test.dart`: extended with a new "Checkpoint J -- Deposit details" group, seeding a real `subtype: deposit` account plus a `DepositDetails` row directly (the same precedent `deposit_repository_test.dart`/`dashboard_providers_test.dart` already established, since production Add Account still cannot create a deposit account through the app in V1). Covers: full field display plus an Active status for a future maturity date; a Matured status for a past maturity date; the card's total absence on a non-deposit account; **lifecycle independence** -- closing a deposit account leaves its deposit status/details card completely unaffected, with both the Account Lifecycle "Closed" badge and the deposit details card rendering simultaneously; and narrow-width (320px) + 1.6x text scale.

**Files changed:** `lib/core/routing/app_routes.dart`, `lib/core/routing/app_router.dart`, `lib/core/finance/deposit_status.dart` (new), `lib/features/networth/presentation/net_worth_providers.dart` (new), `lib/features/networth/presentation/net_worth_screen.dart` (new), `lib/features/settings/presentation/more_screen.dart`, `lib/features/dashboard/presentation/home_screen.dart`, `lib/features/accounts/presentation/account_providers.dart`, `lib/features/accounts/presentation/account_detail_screen.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ja.arb`, plus the test files listed above and this document.

These changes exist in the working tree only; nothing has been staged or committed.

### 13.15 Implementation status (Checkpoint K — Savings persisted subtype; Checkpoint L — Account Detail type-aware presentation)

**This subsection is additive and does not modify §§12-13.14 above -- it records what Checkpoints K and L actually built, following the same "implementation status" convention §13.7-§13.14 above already established. Checkpoint K shipped in an earlier session without its own status note; it is recorded here, alongside Checkpoint L, rather than left permanently undocumented.**

**Checkpoint K — Savings becomes its own `FinancialAccountSubtype`, resolving §13.5 open question 1.**

- §13.5's open question 1 asked whether `bank` legacy rows should be split into `checking`/`savings` legacy subtypes at migration time. Checkpoint K's answer: **no legacy split, ever** (no migration rewrites an existing `bank`-subtype row), but a new `FinancialAccountSubtype.savings` value now exists for accounts created going forward. `AccountCreationKind.savings` (previously aliasing `FinancialAccountSubtype.bank` -- see §13.14's own audit note above, which described that as a genuine pre-existing limitation) now maps to `FinancialAccountSubtype.savings` instead. `checking` remains undefined -- out of scope, not requested.
- **No schema migration.** `Accounts.subtype` was already, and remains, a plain unconstrained `TextColumn` with a safe-fallback reader (`FinancialAccountSubtype.fromStorageValue` falls back to `legacyUnknownNeedsReview`, never throws) -- exactly the storage shape §12.1/`FinancialAccountSubtype`'s own doc comment anticipated. `schemaVersion` stayed at 12.
- Savings remains, in every accounting sense, identical to Bank: an asset, liquid/available (dashboard's liquidity check only ever excludes `deposit`), a positive Net Worth contributor, a normal transaction account, with ordinary lifecycle (close/reactivate) behavior -- `FinanceEngine`, the dashboard liquidity check, `netWorthSummariesProvider`, and `AccountLifecycleService` needed zero changes, since none of them ever special-cased anything beyond `deposit`/`creditCard`.
- `classifyLegacyAccountType` (the legacy-migration classifier) was deliberately left untouched -- it never returns `savings`, so an existing Bank row (even one named "My Savings Account") is never heuristically reclassified.

**Checkpoint L — Account Detail becomes type-aware; a genuinely-stored field gets its first presentation.**

Audit findings (performed before any code change, per this checkpoint's own instruction): `AccountDetailScreen` already correctly rendered Cash/Bank/Savings/Wallet identically (asset, liquid, generic hero balance/opening-balance/created-date/recent-activity), and its existing Deposit section (Checkpoint J, §13.14) was already correct and required no changes -- lifecycle and deposit-maturity independence, already proven while closed, is now additionally proven through a full close-then-reactivate cycle (see test coverage below). Two genuine gaps were found:

- **The hero balance carried no label at all, for any account type.** For a credit-card/liability account this meant its non-negative "amount owed" magnitude (§12.3's frozen sign convention, unchanged) rendered with nothing distinguishing it from an asset's ordinary spendable balance. Fixed with a small, type-aware label directly above the hero number, driven purely by the persisted `AccountRow.isLiability` (never by name/subtype text): "Amount you currently owe" (`addAccountAmountOwedLabel` -- reused verbatim from Add Account's own credit-card opening-balance field, not duplicated) for a liability, "Balance" (`accountBalanceLabel`, new) for every asset alike, deposit included (a deposit's hero number is still a plain ledger balance in this schema, not a specially computed principal figure, so it gets no third label).
- **`AccountRow.institutionId` -- captured at Add Account creation time and persisted ever since -- was never displayed anywhere in the app.** Fixed with a read-only Institution row on Account Detail's existing metadata card, shown only when an account actually has one (never fabricated). A new `activeInstitutionsProvider` (`lib/features/accounts/presentation/account_providers.dart`) exposes `FinancialInstitutionRepository.watchActiveForProfile` for the active profile; the screen resolves `institutionId` against that list itself (no new single-institution repository method), mirroring `_RecentActivitySection`'s existing "watch the list, look up the id locally" pattern for account names.
- **`CreditFacilityDetails.creditLimitMinorUnits`/`statementClosingDay`/`dueDay`** (Checkpoint E, §12.6) were confirmed still genuinely stored but audited to have **no existing presentation anywhere** in the app (no repository-to-provider wiring exists for them, unlike Deposit's `depositDetailsForAccountProvider`) -- per this checkpoint's explicit "do not add credit limits/available credit unless already intended to be presented" instruction, they were deliberately left unsurfaced. See "Legitimate deferrals" below.
- A pre-existing, unrelated inconsistency was found and deliberately NOT fixed here: the "type · currency" subtitle line renders lowercase generic nouns for legacy types (`accountTypeCash`/`Bank`/`Card`/`Wallet` = "cash"/"bank"/"card"/"wallet") but Title-Case phrases for types added since Checkpoint G (`addAccountTypeSavingsTitle` = "Savings account", `addAccountTypeDepositTitle` = "Deposit", `addAccountTypeCreditCardTitle` = "Credit card"). Fixing this consistently would mean changing four long-standing ARB values consumed across many other screens/tests well beyond Account Detail -- broader than this checkpoint's "smallest coherent" mandate for a presentation-polish pass. Deferred; see below.
- No `FinanceEngine` change: audited and found to have no correctness defect relevant to this checkpoint (unchanged since §13.13/§13.14's own audits).
- No schema/migration change: both new fields (`institutionId`, `balanceClass`) were already persisted columns; only their presentation is new. `schemaVersion` stayed at 12.

**Files changed:** `lib/features/accounts/presentation/account_detail_screen.dart`, `lib/features/accounts/presentation/account_providers.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ja.arb`, `lib/l10n/generated/app_localizations.dart`, `lib/l10n/generated/app_localizations_en.dart`, `lib/l10n/generated/app_localizations_ja.dart`, `test/widget/account_detail_screen_test.dart`, plus this document.

**Localization:** two new keys, `accountBalanceLabel` ("Balance" / "残高") and `accountInstitutionLabel` ("Institution" / "金融機関"); the existing `addAccountAmountOwedLabel` ("Amount you currently owe" / "現在の未払い残高") is reused for a liability's hero-balance label rather than duplicated.

**Test coverage (`test/widget/account_detail_screen_test.dart`):** a new "Checkpoint L -- type-aware balance label & institution" group covers the "Balance" label for cash/bank/savings/wallet/deposit, the "Amount you currently owe" label for a credit-card/liability account (with its balance magnitude proven unchanged -- no sign flip), Savings displaying as "Savings account" with its persisted `savings` subtype confirmed directly and surviving an Edit round-trip unchanged, the Institution row appearing only when persisted (present and absent cases), a privacy check that no "Net Worth" text appears on this screen even with a mixed asset/liability portfolio, English and Japanese label assertions, and a narrow-320px/1.6x-text-scale render of a liability account with a long institution name. The existing "Checkpoint J -- Deposit details" group gains one new test proving a **matured** deposit's status survives a full close-then-reactivate cycle unchanged (only "closed, still active-maturity" was previously proven; "closed, still matured, and stays matured after reactivating" was not).

**Legitimate deferrals (explicitly reserved for a future checkpoint, not Cheque/Check Management):**

- Presenting `CreditFacilityDetails.creditLimitMinorUnits` and/or its derived `CreditFacilityRepository.availableCredit` on Account Detail, once a checkpoint explicitly scopes a richer Credit Card Detail experience.
- `statementClosingDay`/`dueDay` presentation, if a future checkpoint decides informational (non-computed) display of already-captured billing dates is worth adding.
- Normalizing the `accountTypeCash`/`Bank`/`Card`/`Wallet` vs. `addAccountType*Title` label-casing/suffix inconsistency across every screen that renders an account type string (Add Account, Accounts list, Account Detail, Edit Account) -- a cross-cutting cleanup, not an Account-Detail-scoped one.

**Privacy (reconfirmed, unchanged):** Net Worth remains absent from Home and from Account Detail; **More → Net Worth** remains the only deliberate entry point (Checkpoint J, §13.14 above) -- Checkpoint L touches neither Home nor the Net Worth screen/provider at all.

These changes exist in the working tree only; nothing has been staged or committed.


### 13.16 Implementation status (Checkpoint N — Cheque/Check Management)

**Audit performed before any code was written, per this checkpoint's own instruction ("do not choose the persistence model until this audit is complete").** Findings against the actual schema/repository/provider code (not guessed):

- **Schema.** `schemaVersion` was 12. `Accounts`/`Transactions` are the two ledger tables `FinanceEngine` reads. `PaymentInstruments` (Checkpoint D) is the closest existing precedent for "metadata describing how money moves through an account, many rows per account, zero accounting weight of its own" — but it has no per-instance amount/date/lifecycle, so it models a reusable *instrument* (a debit card), never an individual *event*. `CreditFacilityDetails`/`DepositDetails` (Checkpoints E/F) are the precedent for "one-to-one metadata attached to an eligible account subtype, currency inherited from the account, zero ledger balance of its own." `RecurringOccurrences` (Beta 1 Task 4A) is the precedent that matters most for Cheques: "a *pending* thing is never itself a row with financial weight; a row exists once it's *handled*, and `transactionId` is set if and only if it posted a real ledger transaction" — its `RecurringOccurrenceRepository.postOccurrence` (re-checks "already handled?" **inside** the same `AppDatabase.transaction` that posts, so a second call always throws rather than double-posting) is the exact idempotency pattern this checkpoint's `markCleared` needed and now reuses.
- **Balance/posting architecture.** `FinanceEngine.accountBalance` folds `account.openingBalance` plus every non-deleted `Transactions` row touching that account, using the `BalanceClass` effect table (§12.3) — it has no awareness of, and needs no change for, any table other than `Accounts`/`Transactions`. Every dashboard/net-worth provider (`dashboard_providers.dart`'s `isAvailable`, `net_worth_providers.dart`'s `netWorthSummariesProvider`) derives from `AccountRow`/`FinanceEngine` the same way — neither reads any other table either.
- **Could an existing `Transactions` row represent a pending cheque?** No — a `Transactions` row IS a posted ledger entry the moment it exists (`FinanceEngine` folds every non-deleted row into the balance unconditionally); there is no "pending transaction" concept anywhere in this schema, and inventing one would mean teaching `FinanceEngine` a new state to filter on, exactly the kind of core-engine change this checkpoint's brief says to avoid unless demonstrated necessary. It is not necessary: `RecurringOccurrences` already proves the alternative — keep the pending thing in its OWN table, with zero rows in `Transactions` until it actually posts.
- **Account eligibility.** Derived from `FinancialAccountSubtype`/`BalanceClass` (§12.1-§12.3), never a name heuristic, matching `CreditFacilityRepository`/`DepositRepository`'s own creation-time eligibility checks: `balanceClass: asset` and `subtype` in `{bank, savings}` — `cash`/`wallet` accounts do not carry chequebooks in practice; `deposit` is locked-term, not transactional; `creditCard` is a liability, out of scope; a `legacyCardNeedsReview`/`legacyUnknownNeedsReview` account is excluded until a user reclassifies it, the same discipline every prior eligible-subtype check already established. The same eligibility set governs which account a RECEIVED cheque may deposit into.
- **Conclusion: a schema migration is genuinely required** (this is new data with no existing column/table shape to reuse), but it is purely additive — two brand-new, empty tables — in exactly the same shape as Checkpoint E's/F's own v10→v11/v11→v12 steps, and it changes zero existing table.

**Chosen persistence model.** Two new Drift tables (`lib/core/database/tables.dart`), schema v13:

- **`ChequeBooks`** — one-to-*many* per eligible account (an account may have several chequebooks over its life), the `PaymentInstruments`-shaped precedent: `id`, `profileId`, `accountId` (immutable after creation), `label`, `startingNumber` (TEXT, purely informational), `createdAt`/`updatedAt`, `deletedAt` ("closed" — soft delete/archive, same non-invalidating-history convention `PaymentInstruments.deletedAt` already established), `syncVersion`/`syncStatus`.
- **`Cheques`** — one row per physical cheque, either direction: `id`, `profileId`, `accountId`, `direction` (`ChequeDirection.name`: `issued`/`received`), `chequeBookId` (nullable, set iff issued), `chequeNumber` (TEXT, never numeric — preserves leading zeros), `amountMinorUnits`/`currencyCode` (currency must equal the account's own — `CurrencyMismatchException` otherwise, no FX step anywhere in this checkpoint), `counterpartyName` (one column for both payee-for-issued and payer-for-received — the presentation layer alone picks the localized label from `direction`), `issueDate`, `receivedDate` (nullable, received-only), `status` (`ChequeStatus.name`: `pending`/`cleared`/`bounced`/`stopped`/`cancelled`), `clearedDate`/`bouncedDate`/`stoppedOrCancelledDate` (nullable, set exactly on the matching transition), `memo`, `transactionId` (nullable, set iff cleared — the `RecurringOccurrences.transactionId` linkage pattern, never a memo-text/description-parsing lookup), `createdAt`/`updatedAt`/`deletedAt`, `syncVersion`/`syncStatus`.

Both enums (`lib/core/finance/cheque_direction.dart`, `cheque_status.dart`) are stored via plain `Enum.name`/`.byName()`, matching `Transactions.type`/`RecurringOccurrences.status`'s convention rather than `BalanceClass`/`FinancialAccountSubtype`'s defensive `storageValue` pattern — `ChequeRepository` is the only writer of either column and there is no legacy-migration data to tolerate, unlike `Accounts.subtype`.

**Lifecycle (frozen).** `pending` → exactly one of `cleared` / `bounced` / `stopped` (issued only) / `cancelled` (either direction) — every one of the four reachable ONLY from `pending`, enforced by `ChequeRepository`, re-checked **inside** the same `AppDatabase.transaction` that performs the transition (the `RecurringOccurrenceRepository.postOccurrence` idempotency pattern). There is deliberately no bounce-after-clear reversal and no clear-after-bounce recovery in V1 — both are real-world but rare cases needing an explicit compensating-transaction mechanism this checkpoint defers rather than build unsafely (see "Legitimate deferrals" below); this is also what makes `cleared` and `bounced` mutually exclusive for a row's whole life.

**Accounting semantics.** A `pending` cheque (either direction) posts **zero** `Transactions` rows and is therefore invisible to `FinanceEngine`/every dashboard/net-worth provider by construction, not by any new filtering logic added to them — a pending issued cheque never reduces the drawing account's cleared balance; a pending received cheque is never counted as available/liquid money. `markCleared` posts **exactly one** `Transactions` row via the completely unmodified `TransactionRepository.recordExpense` (issued) / `recordIncome` (received) — inside the same DB transaction that updates the `Cheques` row's `status`/`clearedDate`/`transactionId`, so a failed post can never leave the two out of sync, and a second `markCleared` call always throws `ChequeLifecycleException` rather than posting twice (proven by a dedicated idempotency test). `bounced`/`stopped`/`cancelled` post **zero** rows, in every case, permanently — none of the three has any code path that ever calls `TransactionRepository`.

**No `FinanceEngine` change. No dashboard/net-worth provider change.** Both were audited and confirmed to need none: a cleared cheque's accounting effect is exactly one ordinary `Transactions` row, consumed exactly once through the completely unmodified ledger path — the same "no core-engine change needed" conclusion Checkpoints E/F already reached for `creditCard`/`deposit` accounts.

**Cheque-number uniqueness.** Application-layer only (same "not a database constraint" precedent `RecurringOccurrences`/`BudgetRepository` established): for `issued`, scoped to `(chequeBookId, chequeNumber)` — a different chequebook (a different account, or a later book on the same account) may legitimately reuse a number. For `received`, deliberately unconstrained — an external payer's cheque number is never the user's to control.

**Files added:** `lib/core/finance/cheque_direction.dart`, `cheque_status.dart`; `lib/core/database/repositories/cheque_book_repository.dart`, `cheque_repository.dart`, `cheque_book_not_found_exception.dart`, `cheque_not_found_exception.dart`, `cheque_validation_exception.dart`, `cheque_lifecycle_exception.dart`; `lib/features/cheques/presentation/cheque_providers.dart`, `cheques_screen.dart`, `cheque_detail_screen.dart`. **Files changed:** `lib/core/database/tables.dart` (new `ChequeBooks`/`Cheques` tables), `lib/core/database/app_database.dart` (schema v13, `from < 13` migration step), `lib/core/database/providers.dart` (two new repository providers), `lib/core/routing/app_routes.dart`/`app_router.dart` (`/cheques`, `/cheques/:id`), `lib/features/settings/presentation/more_screen.dart` (a new "Cheques" row in the Money Tools section — reached only from More, never Home, never bolted onto Add Transaction), `lib/l10n/app_en.arb`/`app_ja.arb` and their three generated files (41 new keys — a consistent "Cheque", never "Check", vocabulary in English; a consistent 小切手 vocabulary in Japanese).

**Test coverage:** `test/core/database/cheque_migration_test.dart` (the v12→v13 schema migration — zero rows fabricated, existing data untouched, the new schema genuinely usable post-migration including a full issue→clear round trip); `test/core/database/repositories/cheque_repository_test.dart` (37 cases across chequebook creation/eligibility, issued/received cheque creation and validation, every lifecycle transition and its rejections, and `FinanceEngine`-verified accounting invariants — pending never affects balance, clearing affects it by exactly the cheque amount, bounced/stopped never affect it, `markCleared` called twice throws on the second call and never double-posts); `test/widget/cheques_screen_test.dart` and `cheque_detail_screen_test.dart` (empty state, the FAB chooser, end-to-end issued/received recording including inline chequebook creation, status always rendered as text never color-only, status-gated action buttons, clearing revealing "View posted transaction" linked to the real `TransactionDetailScreen` route, deletion of a pending cheque, and a 320px/1.6x-text-scale layout check).

**Legitimate deferrals (explicitly reserved for a future checkpoint):**

- Bounce-after-clear reversal and clear-after-bounce recovery — both need an explicit compensating-transaction mechanism this checkpoint did not build, rather than a status flip that would silently corrupt the "cleared and bounced are mutually exclusive for life" invariant above.
- Deleting a cleared/bounced/stopped/cancelled cheque — `ChequeRepository.deletePending` only ever deletes a still-`pending` row (one with no linked `Transactions` row to begin with); historical preservation is preferred over any deletion path that could silently change posted accounting history.
- Cheque OCR/photo scanning, bank API integration/reconciliation, cheque printing/MICR, automatic bank clearing, remote cheque deposit, recurring cheques, post-dated-cheque automation beyond storing/displaying the date, and any cheque-specific FX conversion — all explicit non-goals of this checkpoint's own brief, none attempted.
- A dedicated Account Detail cheque-activity section — audited as a nice-to-have, not built in this pass to keep the change surface to "the smallest coherent architecture that gives correct cheque accounting" (this checkpoint's own instruction); `AccountDetailScreen` (Checkpoint L, §13.15) is untouched and unaffected.

**Privacy (reconfirmed, unchanged):** Net Worth remains absent from Home; **More → Net Worth** remains the only deliberate entry point (Checkpoint J, §13.14). Home gained no cheque-management clutter — Cheques is reached only via **More → Cheques**, mirroring Net Worth's/Currency Converter's own "deliberate extra tap" pattern, never a Home shortcut and never bolted onto Add Transaction.


### 13.17 Implementation status (Checkpoint O — Credit Card Account Experience)

**Audit performed before any code was written, per this checkpoint's own instruction.** Findings against the actual code (not guessed):

- **Credit-card persistence already existed in full since Checkpoint E.** `CreditFacilityDetails` (§12.6) is a one-to-one metadata table keyed by `accountId`, carrying `creditLimitMinorUnits` (a required, non-nullable `IntColumn` — zero is an explicit, valid "not yet assigned" placeholder; negative is rejected at write time) and `linkedPaymentAccountId` (informational only, never enforced). It has no `currencyCode` column of its own — it always inherits the linked `Account`'s currency. `CreditFacilityRepository.availableCredit` (a static helper) already computed `creditLimit - amountOwed`, unclamped, but nothing in the app called it before this checkpoint.
- **Add Account already fully supported entering a credit limit at creation** (Checkpoint G) — `AddAccountFormScreen`'s credit-card branch, `AccountCreationService.createCreditCardAccount`, and `CreditFacilityRepository.createFacility` all round-trip a limit correctly, including the zero-limit ("not yet assigned") case. This checkpoint made zero changes to account creation.
- **Editing an existing card's limit had no path at all.** `EditAccountScreen` handled name changes for every account kind but had no field, no state, and no repository method for revising `creditLimitMinorUnits` after creation. This was the one genuine gap in the write path.
- **No presentation existed for credit limit / available credit / utilization anywhere in the UI.** `AccountDetailScreen` rendered the liability hero ("Amount you currently owe") correctly (Checkpoint L) but had no credit-facility section, mirroring the Deposit section's absence before Checkpoint J.
- **`FinanceEngine`, `dashboard_providers.dart`, `net_worth_providers.dart`, and `chequeEligibleAccountsProvider` all needed zero changes.** Each was read directly, not assumed correct: `FinanceEngine`'s liability effect table (§12.3) already posts an expense as an increase to amount owed and a transfer-in as a payment that decreases it, and already throws `LiabilityOverpaymentException` rather than clamping at zero or inventing a "credit balance" concept — there is no code path anywhere that reads `CreditFacilityDetails` from a balance/net-worth/available-money calculation, so credit limit and derived available credit are structurally excluded from all three, not merely excluded by convention. `chequeEligibleAccountsProvider` filters on `account.isAsset && subtype ∈ {bank, savings}` — a credit card (`isAsset == false`) is excluded twice over, independently of the subtype check.
- **Account Lifecycle already preserved credit-facility metadata correctly.** `AccountLifecycleService.closeAccount`/`reactivateAccount` never touch `CreditFacilityDetails` (keyed by `accountId` alone, correct to leave untouched) — proven by pre-existing tests, not newly added ones.
- **Conclusion: no schema migration, no `FinanceEngine` change, no dashboard/net-worth provider change.** The only genuine gaps were (a) an edit path for the limit, and (b) a presentation layer deriving available credit/utilization from data that already existed.

**What was built (the smallest coherent repair for the two real gaps):**

- `CreditFacilityRepository.updateCreditLimit({accountId, creditLimit})` — validates currency match and non-negativity, then writes exactly `creditLimitMinorUnits`/`updatedAt` on the existing `CreditFacilityDetails` row. Never touches `Accounts`, never posts a `Transactions` row, never changes `openingBalanceMinorUnits`.
- `CreditFacilityPresentation` (`lib/features/accounts/presentation/credit_facility_presentation.dart`) — a pure, unpersisted presentation class: `hasConfiguredLimit` (limit > 0), `availableCredit` (display-clamped to zero — `CreditFacilityRepository.availableCredit`'s own unclamped domain value is never shown as negative "spending capacity"), `utilizationPercent` (`owed / limit * 100`, plain `double` division over integer minor units, deliberately unclamped so an over-limit balance shows e.g. 110% rather than being hidden). Never persisted; recomputed on every read from the same two `Money` values every other screen already resolves.
- `creditFacilityForAccountProvider` (`account_providers.dart`) — a `Provider.autoDispose.family` collapsing a private `StreamProvider.autoDispose.family` to `CreditFacilityDetailsRow?`, mirroring `depositDetailsForAccountProvider`'s exact existing two-layer shape.
- `AccountDetailScreen`: a new `_CreditFacilityDetailsSection` rendered only for `subtype: creditCard`, below the existing "Amount you currently owe" hero (never duplicating it) — a bordered card with Credit limit / Available credit / Credit utilization rows, each showing the existing `homeQuickGlanceNotSet` ("Not set") string when no limit is configured rather than fabricating a limit or a misleading 0%.
- `EditAccountScreen`: for a credit-card account only, a new `MoneyTextField` (keyed `editCreditLimitField`) seeded synchronously in `initState` from the resolved `CreditFacilityDetails` row (the same pre-fill pattern `goal_detail_screen.dart`'s edit-target-amount field already established, since `MoneyTextField.onParsed` never fires from `initialValue` alone) and saved via `CreditFacilityRepository.updateCreditLimit` after the ordinary account save — never in place of it, never combined into one write.

**Available-credit and utilization formulas (exactly as specified):** `availableCredit = max(0, limit - owed)` for display; `utilization = owed / limit * 100`, calculated only when `limit > 0`, never divided by zero. Worked and tested: normal (¥500,000 / ¥80,000 owed → ¥420,000 available, 16.00%); zero balance (¥0 owed → full limit available, 0.00%); at limit (owed == limit → ¥0 available, 100.00%); over limit (¥550,000 owed > ¥500,000 limit → ¥0 available shown, 110.00% shown, never hidden or clamped).

**Overpayment.** Unchanged, pre-existing `FinanceEngine` behavior, confirmed by reading the effect table rather than by new credit-card-specific tests: a payment that would take a liability's owed amount below zero throws `LiabilityOverpaymentException` — there is no "credit balance as asset" concept anywhere in this schema, and this checkpoint did not introduce one.

**Files changed:** `lib/core/database/repositories/credit_facility_repository.dart` (+`updateCreditLimit`), `lib/features/accounts/presentation/account_providers.dart` (+`creditFacilityForAccountProvider`), `lib/features/accounts/presentation/account_detail_screen.dart` (+`_CreditFacilityDetailsSection`), `lib/features/accounts/presentation/edit_account_screen.dart` (+credit-limit field/state/save wiring), `lib/l10n/app_en.arb`/`app_ja.arb` (+4 keys: `creditFacilityDetailsSectionTitle`, `availableCreditLabel`, `creditUtilizationLabel`, `editCreditLimitFieldLabel`; generated l10n files not hand-regenerated in this sandbox — `flutter gen-l10n` must be run before building). **Files added:** `lib/features/accounts/presentation/credit_facility_presentation.dart`.

**Test coverage added:** `test/core/database/repositories/credit_facility_repository_test.dart` (`updateCreditLimit` round-trip, currency-mismatch/negative/zero/not-found rejection, no effect on the account row); `test/features/accounts/presentation/credit_facility_presentation_test.dart` (new file — `hasConfiguredLimit`/`availableCredit`/`utilizationPercent` across normal, zero-balance, at-limit, and over-limit cases); `test/widget/account_detail_screen_test.dart` (a new "Checkpoint O" group — normal/over-limit/missing-limit presentation, non-leakage onto other subtypes, no Net Worth leakage, EN/JA localization, 320px/1.6x-text-scale layout); `test/widget/edit_account_screen_test.dart` (a full create → set limit → save → reopen Edit → same limit appears → change limit → save → Account Detail reflects it round trip, plus confirmation that editing the limit alone never touches balance/liability class/currency and never posts a `Transactions` row); `test/core/dashboard/dashboard_providers_test.dart` and `test/core/networth/net_worth_providers_test.dart` (new credit-card-specific cases proving a large/changed credit limit never moves either dashboard total or net worth — only the amount owed does, exactly as the pre-existing subtype-agnostic architecture already guaranteed); `test/core/database/repositories/cheque_repository_test.dart` (two new cases proving a credit-card account is rejected both for chequebook creation and for issuing a cheque against it — the double `isAsset`/subtype exclusion already in place, now proven in practice rather than only by reading the set literal).

Ledger semantics (expense increases owed; a transfer-in payment decreases it; a credit-card instrument may only be attributed to its own liability account), available/liquid-money exclusion, and close/reactivate metadata preservation were already covered by pre-existing tests (`transaction_repository_test.dart` cases 7-14; `dashboard_providers_test.dart` cases F1/F2/G; `account_lifecycle_service_test.dart`'s credit-card group) and were **not** duplicated — per this checkpoint's own instruction, existing passing coverage of already-correct behavior is left alone.

**No schema/migration change:** `schemaVersion` is unchanged. Available credit and utilization are derived, never persisted; no new column was added to `Accounts` or `CreditFacilityDetails`.

**Privacy/Home boundary (reconfirmed, unchanged):** Net Worth remains absent from Home; **More → Net Worth** remains the only deliberate entry point. No credit-limit/available-credit/utilization/debt summary was added to Home in this checkpoint — this checkpoint is Account Detail/Edit only.

**Legitimate deferrals (explicitly reserved, unchanged from the checkpoint's own brief):** statement generation/closing balances, APR/interest accrual, billing-cycle automation, minimum-payment calculations, due-date/late-fee engines, annual fees, rewards/points/cashback, card-network/bank-API integration, automatic reconciliation, credit-score features, payment reminders/automatic recurring payments, installment-plan accounting, foreign-currency card settlement. None of these was partially built or half-persisted by this checkpoint.

These changes exist in the working tree only; nothing has been staged or committed.

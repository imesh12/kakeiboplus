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

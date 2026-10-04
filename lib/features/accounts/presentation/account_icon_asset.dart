import '../../../shared/icons/public_icon_asset.dart';

/// Accounts Icon Pack Full Integration checkpoint: the ONE centralized
/// resolver for an account's TYPE visual identity. Replaces the two
/// narrower, public-pool-only helpers this feature briefly had
/// (`accountTypePublicIconAsset`/`accountCreationKindPublicIconAsset`,
/// from the Public Icons Pool Integration checkpoint) -- superseded now
/// that Accounts has its OWN specialized icon tier, per this
/// checkpoint's explicit "do not scatter asset-path checks, extend the
/// shared resolver once" instruction.
///
/// # Precedence
///
///   account-specific icon ([accountTypeIconAsset], this file)
///   > public/generic icon (`publicIconAssetFor`, `shared/icons/public_icon_asset.dart`)
///   > Material fallback glyph (`accountTypeIcon`/`accountCreationKindIcon`,
///     `account_type_presentation.dart`/`account_creation_kind_presentation.dart`)
///
/// [accountIconAssetFor] is the single function every screen should call
/// for an `AppIconTile.assetPath` -- it already walks that whole ladder,
/// so no screen needs to know there even ARE two icon tiers above
/// Material. Every call site also still passes `accountTypeIcon(type)`/
/// `accountCreationKindIcon(kind)` as `AppIconTile.icon` unchanged -- a
/// `null` result here always means "render that Material glyph", never
/// blank, never a broken image.
///
/// # Keyed by the persisted `type` STRING, not an enum
///
/// Both call sites this resolver serves ultimately key off the same
/// legacy `Accounts.type` string vocabulary: `AccountDetailScreen`
/// reads it directly from a persisted row, and `AddAccountTypeScreen`'s
/// `AccountCreationKind` already carries that exact string as its own
/// `legacyTypeLabel` (see that enum's constructor) -- so a single
/// `String`-keyed function serves both without needing two parallel
/// enum-specific wrappers.
///
/// # Sourced from the approved Accounts icon pack
///
/// Every mapped path below was copied once from the approved
/// `docs/design/app-icon/accounts/` pack into `assets/icons/accounts/`
/// under a normalized filename -- that source folder is never
/// referenced at runtime. Only a type with a CONFIDENT, unambiguous
/// visual match is mapped; see [accountTypeIconAsset]'s own doc for
/// exactly which of the pack's 6 files were used and which was
/// deliberately left out.
String? accountIconAssetFor(String type) =>
    accountTypeIconAsset(type) ??
    switch (type) {
      // 'bank' has no dedicated artwork in the approved Accounts pack
      // (the pack is cash / credit card / deposit / savings account /
      // wallet -- no bank file). Per this checkpoint's own precedence
      // rule, it falls through to the public pool's `business-building
      // .png` (Public Icons Pool Integration checkpoint) instead of
      // Material -- this is the public tier doing its job, not a gap.
      'bank' => publicIconAssetFor(PublicIconKey.bank),
      _ => null,
    };

/// The account-specific tier ONLY (no public-pool fallback) -- exposed
/// separately so a caller or test can distinguish "this account type
/// has its OWN curated artwork" from "it only has the generic public
/// icon". [accountIconAssetFor] is still what every real call site
/// should use.
///
/// Mapped, with the approved pack file each came from:
///   - `cash`                 -> `cash.png` (exact: a hand holding cash)
///   - `card` / `creditCard`  -> `credite-cards.png` (exact: two stacked
///     payment cards) -- both legacy string values already resolve to
///     the exact same Material glyph today (`Icons.credit_card_outlined`
///     via `accountTypeIcon`), so they share this same artwork too.
///   - `wallet`                -> `wallet.png` (exact: a leather billfold)
///   - `deposit`                -> `deposit.png` (exact: a safe/vault --
///     visually a strong match for a locked-term deposit, arguably a
///     clearer concept than the Material fallback it replaces,
///     `Icons.lock_clock_outlined`)
///   - `savings`                -> `Saving_account_.png`, copied as
///     `savings_account.png` (exact: the artwork is literally labeled
///     "SAVINGS ACCOUNT PASSBOOK")
///
/// Deliberately NOT mapped, despite being one of the 6 approved files:
///   - the pack's `saving.png` -- by hash, this file is BYTE-IDENTICAL
///     to the artwork already in production use for the unrelated
///     Savings GOALS feature (`assets/icons/dashboard/savings_goal.png`
///     / `assets/icons/more/savings_goal.png`). Reusing it here for the
///     "savings" ACCOUNT TYPE -- a different concept the pack's own
///     separate `Saving_account_.png` already covers unambiguously --
///     would overload one image across two distinct product concepts
///     for no reason. Left unmapped per this checkpoint's own "do not
///     blindly assume all three [deposit/saving/Saving_account_] mean
///     the same thing" / "do not force-map ambiguous types" instructions.
///   - `bank` -- no file in this pack represents it at all; see
///     [accountIconAssetFor]'s own doc for its public-pool fallback.
///   - every other legacy/transitional value
///     (`legacyCardNeedsReview`/`legacyUnknownNeedsReview`, or any
///     future/unrecognized string) -- intentionally returns `null`,
///     never a guess.
String? accountTypeIconAsset(String type) => switch (type) {
  'cash' => 'assets/icons/accounts/cash.png',
  'card' || 'creditCard' => 'assets/icons/accounts/credit_card.png',
  'wallet' => 'assets/icons/accounts/wallet.png',
  'deposit' => 'assets/icons/accounts/deposit.png',
  'savings' => 'assets/icons/accounts/savings_account.png',
  _ => null,
};

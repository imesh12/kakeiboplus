import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/ledger_models.dart';
import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';
import 'account_not_found_exception.dart';

/// Converts a Drift [AccountRow] into the pure-Dart [LedgerAccount] shape
/// [FinanceEngine] operates on, and exposes its opening balance as a
/// proper [Money] rather than a bare integer.
extension AccountRowX on AccountRow {
  Money get openingBalance => Money.fromMinorUnits(openingBalanceMinorUnits, currencyCode);

  LedgerAccount toLedgerAccount() => LedgerAccount(
        id: id,
        currencyCode: currencyCode,
        openingBalance: openingBalance,
      );
}

class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  Stream<List<AccountRow>> watchActiveForProfile(String profileId) {
    // Deliberately no explicit generic type arguments on `.select`/
    // `.orderBy` here — Dart infers them, which avoids pinning this file
    // to an exact Drift-generated typedef name that could not be
    // verified without a working `dart analyze` in the sandbox that
    // wrote this file (see CLAUDE_FIRST_CODING_PROMPT.md).
    final query = _db.select(_db.accounts)
      ..where(
        (tbl) =>
            tbl.profileId.equals(profileId) &
            tbl.isActive.equals(true) &
            tbl.deletedAt.isNull(),
      )
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    return query.watch();
  }

  Future<AccountRow> requireById(String id) {
    return (_db.select(_db.accounts)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  /// Creates a new account. [openingBalance], if given, must already be
  /// denominated in [currencyCode] — mismatched currencies throw
  /// [CurrencyMismatchException] rather than being silently coerced.
  Future<String> createAccount({
    required String profileId,
    required String name,
    required String type,
    required String currencyCode,
    Money? openingBalance,
  }) async {
    final Money balance = openingBalance ?? Money.zero(currencyCode);
    if (balance.currencyCode != currencyCode) {
      throw CurrencyMismatchException(currencyCode, balance.currencyCode);
    }
    final String id = _uuid.v4();
    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            profileId: profileId,
            name: name,
            type: type,
            currencyCode: currencyCode,
            openingBalanceMinorUnits: Value<int>(balance.minorUnits),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id))).write(
      AccountsCompanion(
        deletedAt: Value<DateTime?>(DateTime.now().toUtc()),
        isActive: const Value<bool>(false),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  /// Reactively resolves [id] to its live row, or `null` once it's
  /// soft-deleted or if it never existed -- the same "unavailable below
  /// the UI layer" convention `TransactionRepository.watchById`/
  /// `goalSummaryProvider` already use. V1 Account Detail/Edit
  /// Checkpoint: what the account detail and edit screens watch, so a
  /// stale or missing account id resolves to an explicit unavailable
  /// state rather than a thrown error or stale data.
  Stream<AccountRow?> watchById(String id) {
    final query = _db.select(_db.accounts)
      ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull());
    return query.watchSingleOrNull();
  }

  /// Updates an existing account's safe metadata fields only -- V1
  /// Account Detail/Edit Checkpoint. **Never [currencyCode] or
  /// [openingBalanceMinorUnits]**: every historical transaction on this
  /// account was recorded (and its own `currencyCode` stored) against the
  /// account's currency at the time -- see `Transactions.currencyCode`'s
  /// own doc comment and `FinanceEngine.accountBalance`, which combines
  /// the account's opening balance with every transaction via plain
  /// [Money] addition and throws [CurrencyMismatchException] the moment
  /// two differently-currencied [Money] values meet. Changing an
  /// account's currency after the fact would either silently reinterpret
  /// every existing minor-unit amount under a new currency or start
  /// throwing on every future balance computation; neither is acceptable,
  /// so this method has no way to do it at all. `profileId`/`currencyCode`/
  /// `openingBalanceMinorUnits`/`createdAt` are also never touched here --
  /// only [name] and [type] (the account's *kind*, e.g. cash/bank/card/
  /// wallet, which `LedgerAccount`/`FinanceEngine` never read) may change.
  ///
  /// Race-safe like every other repository update in this app: the WHERE
  /// clause re-asserts the row is still active at the moment of the
  /// write itself, not just at an earlier read. A `rowsAffected` of
  /// anything other than 1 means [id] was deleted between the caller's
  /// read and this write (or never existed), so this throws
  /// [AccountNotFoundException] rather than silently reporting success
  /// for a write that changed nothing.
  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
  }) async {
    final int rowsAffected = await (_db.update(_db.accounts)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .write(
      AccountsCompanion(
        name: Value<String>(name),
        type: Value<String>(type),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
    if (rowsAffected != 1) {
      throw AccountNotFoundException(id);
    }
  }
}

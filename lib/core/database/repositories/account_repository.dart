import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../finance/ledger_models.dart';
import '../../money/currency_mismatch_exception.dart';
import '../../money/money.dart';
import '../app_database.dart';

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
}

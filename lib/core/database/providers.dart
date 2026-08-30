import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'repositories/account_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/currency_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/transaction_repository.dart';

/// The single [AppDatabase] instance for the app's lifetime. A plain
/// `Provider` (not `.autoDispose`) — the database connection should stay
/// open for as long as the app runs, not be torn down whenever its last
/// listener unsubscribes. Closed via `ref.onDispose` only for
/// completeness (e.g. hot-restart in debug builds); in a real app run
/// this provider's container lives for the whole process.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final Provider<CurrencyRepository> currencyRepositoryProvider = Provider<CurrencyRepository>(
  (ref) => CurrencyRepository(ref.watch(appDatabaseProvider)),
);

final Provider<ProfileRepository> profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(appDatabaseProvider)),
);

final Provider<AccountRepository> accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(appDatabaseProvider)),
);

final Provider<CategoryRepository> categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(appDatabaseProvider)),
);

final Provider<TransactionRepository> transactionRepositoryProvider =
    Provider<TransactionRepository>(
  (ref) => TransactionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

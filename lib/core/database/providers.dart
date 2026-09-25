import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'repositories/account_repository.dart';
import 'repositories/budget_repository.dart';
import 'repositories/cloud_account_link_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/credit_facility_repository.dart';
import 'repositories/currency_repository.dart';
import 'repositories/deposit_repository.dart';
import 'repositories/financial_institution_repository.dart';
import 'repositories/payment_instrument_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/recurring_occurrence_repository.dart';
import 'repositories/recurring_rule_repository.dart';
import 'repositories/savings_goal_contribution_repository.dart';
import 'repositories/savings_goal_repository.dart';
import 'repositories/transaction_repository.dart';
import 'services/account_creation_service.dart';
import 'services/account_lifecycle_service.dart';

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

final Provider<BudgetRepository> budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

final Provider<SavingsGoalRepository> savingsGoalRepositoryProvider =
    Provider<SavingsGoalRepository>(
  (ref) => SavingsGoalRepository(ref.watch(appDatabaseProvider)),
);

final Provider<SavingsGoalContributionRepository> savingsGoalContributionRepositoryProvider =
    Provider<SavingsGoalContributionRepository>(
  (ref) => SavingsGoalContributionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(savingsGoalRepositoryProvider),
  ),
);

final Provider<RecurringRuleRepository> recurringRuleRepositoryProvider =
    Provider<RecurringRuleRepository>(
  (ref) => RecurringRuleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

final Provider<RecurringOccurrenceRepository> recurringOccurrenceRepositoryProvider =
    Provider<RecurringOccurrenceRepository>(
  (ref) => RecurringOccurrenceRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(recurringRuleRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
  ),
);

/// Checkpoint 12.2 (Cloud Identity / Auth Foundation). Same
/// single-argument `Provider<AppDatabase>`-only wiring shape as
/// [profileRepositoryProvider] -- this repository has no cross-
/// repository dependency (it only ever reads/writes its own
/// `cloud_account_links` table, keyed by a `profileId` string its
/// callers already have via `activeProfileProvider`).
final Provider<CloudAccountLinkRepository> cloudAccountLinkRepositoryProvider =
    Provider<CloudAccountLinkRepository>(
  (ref) => CloudAccountLinkRepository(ref.watch(appDatabaseProvider)),
);

/// Checkpoint G (docs/20 §13.4/§12.6): the four new repository/service
/// providers the Add Account UX needs. Each follows this file's own
/// existing wiring convention exactly -- a plain (non-`.autoDispose`)
/// `Provider` that watches [appDatabaseProvider] and, where the
/// repository's constructor requires it (matching
/// `CreditFacilityRepository`/`DepositRepository`/
/// `PaymentInstrumentRepository`'s own existing constructors, unchanged
/// by this checkpoint), [accountRepositoryProvider].
final Provider<FinancialInstitutionRepository> financialInstitutionRepositoryProvider =
    Provider<FinancialInstitutionRepository>(
  (ref) => FinancialInstitutionRepository(ref.watch(appDatabaseProvider)),
);

final Provider<CreditFacilityRepository> creditFacilityRepositoryProvider =
    Provider<CreditFacilityRepository>(
  (ref) => CreditFacilityRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

final Provider<DepositRepository> depositRepositoryProvider = Provider<DepositRepository>(
  (ref) => DepositRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

final Provider<PaymentInstrumentRepository> paymentInstrumentRepositoryProvider =
    Provider<PaymentInstrumentRepository>(
  (ref) => PaymentInstrumentRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(accountRepositoryProvider),
  ),
);

/// The Add Account UX's single entry point for atomic multi-record
/// account creation -- see [AccountCreationService]'s own doc.
final Provider<AccountCreationService> accountCreationServiceProvider =
    Provider<AccountCreationService>(
  (ref) => AccountCreationService(
    db: ref.watch(appDatabaseProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    creditFacilityRepository: ref.watch(creditFacilityRepositoryProvider),
    depositRepository: ref.watch(depositRepositoryProvider),
    paymentInstrumentRepository: ref.watch(paymentInstrumentRepositoryProvider),
    financialInstitutionRepository: ref.watch(financialInstitutionRepositoryProvider),
  ),
);

/// Account Lifecycle Checkpoint: the single entry point for
/// closing/reactivating an existing account -- see
/// [AccountLifecycleService]'s own doc. Same wiring convention as
/// [accountCreationServiceProvider] immediately above.
final Provider<AccountLifecycleService> accountLifecycleServiceProvider =
    Provider<AccountLifecycleService>(
  (ref) => AccountLifecycleService(
    db: ref.watch(appDatabaseProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    paymentInstrumentRepository: ref.watch(paymentInstrumentRepositoryProvider),
    recurringRuleRepository: ref.watch(recurringRuleRepositoryProvider),
  ),
);

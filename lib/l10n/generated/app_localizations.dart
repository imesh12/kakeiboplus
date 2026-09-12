import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// No description provided for @internationalPreferences.
  ///
  /// In en, this message translates to:
  /// **'International preferences'**
  String get internationalPreferences;

  /// No description provided for @locationSection.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationSection;

  /// No description provided for @currencySection.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencySection;

  /// No description provided for @languageAndFormatSection.
  ///
  /// In en, this message translates to:
  /// **'Language & format'**
  String get languageAndFormatSection;

  /// No description provided for @homeCountry.
  ///
  /// In en, this message translates to:
  /// **'Home country'**
  String get homeCountry;

  /// No description provided for @currentCountry.
  ///
  /// In en, this message translates to:
  /// **'Current country'**
  String get currentCountry;

  /// No description provided for @homeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Home currency'**
  String get homeCurrency;

  /// No description provided for @livingCurrency.
  ///
  /// In en, this message translates to:
  /// **'Living currency'**
  String get livingCurrency;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get dateFormat;

  /// No description provided for @numberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get numberFormat;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// No description provided for @navAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get navAdd;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @transactionTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionTypeExpense;

  /// No description provided for @transactionTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionTypeIncome;

  /// No description provided for @transactionTypeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transactionTypeTransfer;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @accountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountLabel;

  /// No description provided for @fromAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get fromAccountLabel;

  /// No description provided for @toAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get toAccountLabel;

  /// No description provided for @categoryOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get categoryOptionalLabel;

  /// No description provided for @noteOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptionalLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @addAccountFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'Add an account first (Profile → Accounts) before recording money.'**
  String get addAccountFirstMessage;

  /// No description provided for @couldNotLoadAccounts.
  ///
  /// In en, this message translates to:
  /// **'Could not load accounts: {error}'**
  String couldNotLoadAccounts(String error);

  /// No description provided for @couldNotLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories: {error}'**
  String couldNotLoadCategories(String error);

  /// No description provided for @couldNotSaveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String couldNotSaveTransaction(String error);

  /// No description provided for @enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get enterValidAmount;

  /// No description provided for @chooseDestinationAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination account.'**
  String get chooseDestinationAccount;

  /// No description provided for @noEligibleTransferDestination.
  ///
  /// In en, this message translates to:
  /// **'No other {currency} account to transfer to yet. Cross-currency transfers are not supported in this version.'**
  String noEligibleTransferDestination(String currency);

  /// No description provided for @currencyMismatchError.
  ///
  /// In en, this message translates to:
  /// **'That amount\'s currency doesn\'t match the selected account ({fromCurrency} → {toCurrency}).'**
  String currencyMismatchError(String fromCurrency, String toCurrency);

  /// No description provided for @transactionNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This transaction is no longer available -- it may have been deleted elsewhere.'**
  String get transactionNoLongerAvailable;

  /// No description provided for @addExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpenseTitle;

  /// No description provided for @addIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get addIncomeTitle;

  /// No description provided for @editExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpenseTitle;

  /// No description provided for @editIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit income'**
  String get editIncomeTitle;

  /// No description provided for @editTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get editTransferTitle;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(String name);

  /// No description provided for @accountsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsSectionTitle;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @couldNotLoadBalances.
  ///
  /// In en, this message translates to:
  /// **'Could not load your balances: {error}'**
  String couldNotLoadBalances(String error);

  /// No description provided for @addAccountToSeeBalance.
  ///
  /// In en, this message translates to:
  /// **'Add an account to see your balance, income, and spending here.'**
  String get addAccountToSeeBalance;

  /// No description provided for @noAccountsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet. Add one to start tracking.'**
  String get noAccountsYetMessage;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String somethingWentWrong(String error);

  /// No description provided for @totalAvailableBalance.
  ///
  /// In en, this message translates to:
  /// **'Total available balance'**
  String get totalAvailableBalance;

  /// No description provided for @incomeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Income this month'**
  String get incomeThisMonth;

  /// No description provided for @spentThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent this month'**
  String get spentThisMonth;

  /// No description provided for @dailySpendingPace.
  ///
  /// In en, this message translates to:
  /// **'Daily spending pace'**
  String get dailySpendingPace;

  /// No description provided for @dailySpendingPaceDetail.
  ///
  /// In en, this message translates to:
  /// **'Average spend per day so far this month'**
  String get dailySpendingPaceDetail;

  /// No description provided for @remainingMonthlyBudget.
  ///
  /// In en, this message translates to:
  /// **'Remaining monthly budget'**
  String get remainingMonthlyBudget;

  /// No description provided for @noBudgetSetMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t set a monthly budget yet. Set one to see how much you have left to spend.'**
  String get noBudgetSetMessage;

  /// No description provided for @setMonthlyBudgetButton.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly budget'**
  String get setMonthlyBudgetButton;

  /// No description provided for @budgetStatusOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get budgetStatusOnTrack;

  /// No description provided for @budgetStatusAheadOfPace.
  ///
  /// In en, this message translates to:
  /// **'Ahead of pace'**
  String get budgetStatusAheadOfPace;

  /// No description provided for @budgetStatusOverBudget.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get budgetStatusOverBudget;

  /// No description provided for @budgetStatusThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get budgetStatusThisMonth;

  /// No description provided for @ofAmount.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String ofAmount(String amount);

  /// No description provided for @percentUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String percentUsedLabel(String percent);

  /// No description provided for @recommendedDailySpend.
  ///
  /// In en, this message translates to:
  /// **'Recommended: {amount} / day for the rest of the month'**
  String recommendedDailySpend(String amount);

  /// No description provided for @savingsGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get savingsGoalsTitle;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @noSavingsGoalMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t set a savings goal yet.'**
  String get noSavingsGoalMessage;

  /// No description provided for @setSavingsGoalButton.
  ///
  /// In en, this message translates to:
  /// **'Set a savings goal'**
  String get setSavingsGoalButton;

  /// No description provided for @allGoalsCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'All your savings goals are completed.'**
  String get allGoalsCompletedMessage;

  /// No description provided for @overdueLabel.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueLabel;

  /// No description provided for @goalStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get goalStatusInProgress;

  /// No description provided for @goalStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get goalStatusCompleted;

  /// No description provided for @recurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringTitle;

  /// No description provided for @noRecurringMessage.
  ///
  /// In en, this message translates to:
  /// **'No recurring bills or income set up yet.'**
  String get noRecurringMessage;

  /// No description provided for @setUpRecurringButton.
  ///
  /// In en, this message translates to:
  /// **'Set up recurring'**
  String get setUpRecurringButton;

  /// No description provided for @recurringStatusDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get recurringStatusDueToday;

  /// No description provided for @recurringStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get recurringStatusUpcoming;

  /// No description provided for @couldNotLoadTransactions.
  ///
  /// In en, this message translates to:
  /// **'Could not load transactions: {error}'**
  String couldNotLoadTransactions(String error);

  /// No description provided for @noTransactionsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet. Tap Add to record one.'**
  String get noTransactionsYetMessage;

  /// No description provided for @searchTransactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get searchTransactionsLabel;

  /// No description provided for @searchTransactionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search by category, account, note, or amount'**
  String get searchTransactionsHint;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @noMatchingTransactions.
  ///
  /// In en, this message translates to:
  /// **'No matching transactions'**
  String get noMatchingTransactions;

  /// No description provided for @dateGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateGroupToday;

  /// No description provided for @dateGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateGroupYesterday;

  /// No description provided for @dateGroupSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{group} transactions'**
  String dateGroupSemanticLabel(String group);

  /// No description provided for @spokenPlusAmount.
  ///
  /// In en, this message translates to:
  /// **'plus {amount}'**
  String spokenPlusAmount(String amount);

  /// No description provided for @spokenMinusAmount.
  ///
  /// In en, this message translates to:
  /// **'minus {amount}'**
  String spokenMinusAmount(String amount);

  /// No description provided for @noAccountsYetTapToAddMessage.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet. Tap + to add one.'**
  String get noAccountsYetTapToAddMessage;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'bank'**
  String get accountTypeBank;

  /// No description provided for @accountTypeCard.
  ///
  /// In en, this message translates to:
  /// **'card'**
  String get accountTypeCard;

  /// No description provided for @accountTypeWallet.
  ///
  /// In en, this message translates to:
  /// **'wallet'**
  String get accountTypeWallet;

  /// No description provided for @addAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccountDialogTitle;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountNameLabel;

  /// No description provided for @enterAccountNameMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get enterAccountNameMessage;

  /// No description provided for @accountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get accountTypeLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @addAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAccountButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

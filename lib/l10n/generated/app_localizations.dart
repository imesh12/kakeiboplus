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

  /// Checkpoint M: the product name, used as the accessibility semantic label for the brand wordmark image on the More screen (see docs/14_DECISION_LOG.md ADR-036). This is a proper/brand name -- translators must keep the value exactly 'KakeiboPlus' in every locale, never translate it.
  ///
  /// In en, this message translates to:
  /// **'KakeiboPlus'**
  String get brandName;

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

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @moreScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your money tools and preferences'**
  String get moreScreenSubtitle;

  /// No description provided for @morePlanningSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get morePlanningSectionTitle;

  /// No description provided for @moreMoneyToolsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Money Tools'**
  String get moreMoneyToolsSectionTitle;

  /// No description provided for @moreOrganizationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get moreOrganizationSectionTitle;

  /// No description provided for @morePersonalizationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get morePersonalizationSectionTitle;

  /// No description provided for @moreCloudSecuritySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud & Security'**
  String get moreCloudSecuritySectionTitle;

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

  /// No description provided for @transactionLinkedToChequeError.
  ///
  /// In en, this message translates to:
  /// **'This transaction was created by a cleared cheque and can\'t be edited or deleted directly.'**
  String get transactionLinkedToChequeError;

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

  /// No description provided for @accountFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountFallbackTitle;

  /// No description provided for @accountNoLongerAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This account is no longer available.'**
  String get accountNoLongerAvailableMessage;

  /// No description provided for @couldNotLoadAccountDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not load this account: {error}'**
  String couldNotLoadAccountDetail(String error);

  /// No description provided for @accountOpeningBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get accountOpeningBalanceLabel;

  /// No description provided for @accountCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get accountCreatedLabel;

  /// No description provided for @accountBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountBalanceLabel;

  /// No description provided for @accountInstitutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get accountInstitutionLabel;

  /// No description provided for @accountRecentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get accountRecentActivityTitle;

  /// No description provided for @accountNoRecentActivityMessage.
  ///
  /// In en, this message translates to:
  /// **'No recent activity for this account.'**
  String get accountNoRecentActivityMessage;

  /// No description provided for @editAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccountTitle;

  /// No description provided for @accountCurrencyLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Currency can\'t be changed after an account is created.'**
  String get accountCurrencyLockedMessage;

  /// No description provided for @closeAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Close account'**
  String get closeAccountAction;

  /// No description provided for @closeCreditCardAction.
  ///
  /// In en, this message translates to:
  /// **'Deactivate card'**
  String get closeCreditCardAction;

  /// No description provided for @reactivateAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Reactivate account'**
  String get reactivateAccountAction;

  /// No description provided for @closeAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Close this account?'**
  String get closeAccountConfirmTitle;

  /// No description provided for @closeAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Its transaction history stays exactly as it is. It just won\'t be available for new transactions until you reactivate it.'**
  String get closeAccountConfirmMessage;

  /// No description provided for @closeCreditCardConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate this card?'**
  String get closeCreditCardConfirmTitle;

  /// No description provided for @closeCreditCardConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Its transaction history stays exactly as it is. It just won\'t be available for new charges or payments until you reactivate it.'**
  String get closeCreditCardConfirmMessage;

  /// No description provided for @reactivateAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactivate this account?'**
  String get reactivateAccountConfirmTitle;

  /// No description provided for @reactivateAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'It will be available for new transactions again, with its existing history and balance unchanged.'**
  String get reactivateAccountConfirmMessage;

  /// No description provided for @accountClosedLabel.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get accountClosedLabel;

  /// No description provided for @closedAccountsSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Closed accounts'**
  String get closedAccountsSectionHeader;

  /// No description provided for @accountHasActiveRecurringRulesMessage.
  ///
  /// In en, this message translates to:
  /// **'This account is still used by one or more recurring rules. Change or delete them first, then try closing this account again.'**
  String get accountHasActiveRecurringRulesMessage;

  /// No description provided for @couldNotCloseAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not close this account: {error}'**
  String couldNotCloseAccountMessage(String error);

  /// No description provided for @couldNotReactivateAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not reactivate this account: {error}'**
  String couldNotReactivateAccountMessage(String error);

  /// No description provided for @budgetsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets · {month}'**
  String budgetsScreenTitle(String month);

  /// No description provided for @couldNotLoadBudgets.
  ///
  /// In en, this message translates to:
  /// **'Could not load budgets: {error}'**
  String couldNotLoadBudgets(String error);

  /// No description provided for @noBudgetsSetThisMonthMessage.
  ///
  /// In en, this message translates to:
  /// **'No budgets set for this month yet. Tap + to set an overall monthly budget or a category budget.'**
  String get noBudgetsSetThisMonthMessage;

  /// No description provided for @overallBudgetsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Overall budgets'**
  String get overallBudgetsSectionTitle;

  /// No description provided for @categoryBudgetsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Category budgets'**
  String get categoryBudgetsSectionTitle;

  /// No description provided for @overallMonthlyBudgetOption.
  ///
  /// In en, this message translates to:
  /// **'Overall monthly budget'**
  String get overallMonthlyBudgetOption;

  /// No description provided for @categoryBudgetOption.
  ///
  /// In en, this message translates to:
  /// **'Category budget'**
  String get categoryBudgetOption;

  /// No description provided for @editOverallBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit overall monthly budget'**
  String get editOverallBudgetTitle;

  /// No description provided for @setOverallBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set overall monthly budget'**
  String get setOverallBudgetTitle;

  /// No description provided for @monthlyBudgetAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget amount'**
  String get monthlyBudgetAmountLabel;

  /// No description provided for @editCategoryBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit category budget'**
  String get editCategoryBudgetTitle;

  /// No description provided for @setCategoryBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set category budget'**
  String get setCategoryBudgetTitle;

  /// No description provided for @categoryFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryFieldLabel;

  /// No description provided for @chooseCategoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a category.'**
  String get chooseCategoryMessage;

  /// No description provided for @categoryBudgetAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Category budget amount'**
  String get categoryBudgetAmountLabel;

  /// No description provided for @previousMonthTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonthTooltip;

  /// No description provided for @nextMonthTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonthTooltip;

  /// No description provided for @monthSummarySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Month summary'**
  String get monthSummarySectionTitle;

  /// No description provided for @totalBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Total budget'**
  String get totalBudgetLabel;

  /// No description provided for @spentLabel.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentLabel;

  /// No description provided for @noCategoryBudgetsForMonthMessage.
  ///
  /// In en, this message translates to:
  /// **'No category budgets for this month.'**
  String get noCategoryBudgetsForMonthMessage;

  /// No description provided for @overBudgetByAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'{amount} over budget'**
  String overBudgetByAmountLabel(String amount);

  /// No description provided for @editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editTooltip;

  /// No description provided for @removeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeTooltip;

  /// No description provided for @couldNotLoadGoals.
  ///
  /// In en, this message translates to:
  /// **'Could not load goals: {error}'**
  String couldNotLoadGoals(String error);

  /// No description provided for @noSavingsGoalsYetTapMessage.
  ///
  /// In en, this message translates to:
  /// **'No savings goals yet. Tap + to set one.'**
  String get noSavingsGoalsYetTapMessage;

  /// No description provided for @newSavingsGoalDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New savings goal'**
  String get newSavingsGoalDialogTitle;

  /// No description provided for @goalNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get goalNameLabel;

  /// No description provided for @enterGoalNameMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this goal.'**
  String get enterGoalNameMessage;

  /// No description provided for @targetAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get targetAmountLabel;

  /// No description provided for @noTargetDateMessage.
  ///
  /// In en, this message translates to:
  /// **'No target date'**
  String get noTargetDateMessage;

  /// No description provided for @targetDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get targetDateLabel;

  /// No description provided for @chooseButton.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get chooseButton;

  /// No description provided for @clearTargetDateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear target date'**
  String get clearTargetDateTooltip;

  /// No description provided for @goalFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goalFallbackTitle;

  /// No description provided for @editGoalAction.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get editGoalAction;

  /// No description provided for @deleteGoalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete goal'**
  String get deleteGoalTooltip;

  /// No description provided for @couldNotLoadGoalDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not load this goal: {error}'**
  String couldNotLoadGoalDetail(String error);

  /// No description provided for @goalNoLongerAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This goal is no longer available.'**
  String get goalNoLongerAvailableMessage;

  /// No description provided for @deleteGoalConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this goal?'**
  String get deleteGoalConfirmTitle;

  /// No description provided for @deleteGoalConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Its contribution history is kept, but the goal itself will no longer be active.'**
  String get deleteGoalConfirmMessage;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @remainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingLabel;

  /// No description provided for @recommendedDailyContributionLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommended daily contribution'**
  String get recommendedDailyContributionLabel;

  /// No description provided for @contributionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Contribution history'**
  String get contributionHistoryTitle;

  /// No description provided for @couldNotLoadContributionHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not load contribution history: {error}'**
  String couldNotLoadContributionHistory(String error);

  /// No description provided for @noContributionsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No contributions yet.'**
  String get noContributionsYetMessage;

  /// No description provided for @addContributionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a contribution'**
  String get addContributionDialogTitle;

  /// No description provided for @addContributionButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addContributionButton;

  /// couldNotLoadRecurringRules
  ///
  /// In en, this message translates to:
  /// **'Could not load recurring rules: {error}'**
  String couldNotLoadRecurringRules(String error);

  /// No description provided for @noRecurringRulesYetTapMessage.
  ///
  /// In en, this message translates to:
  /// **'No recurring rules yet. Tap + to add one.'**
  String get noRecurringRulesYetTapMessage;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptionsTitle;

  /// No description provided for @subscriptionsEstimatedMonthlyTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Est. monthly'**
  String get subscriptionsEstimatedMonthlyTotalLabel;

  /// No description provided for @subscriptionsEstimatedYearlyTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Est. yearly'**
  String get subscriptionsEstimatedYearlyTotalLabel;

  /// No description provided for @noActiveSubscriptionsMessage.
  ///
  /// In en, this message translates to:
  /// **'No active subscriptions yet.'**
  String get noActiveSubscriptionsMessage;

  /// No description provided for @deleteRecurringRuleConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this recurring rule?'**
  String get deleteRecurringRuleConfirmTitle;

  /// No description provided for @deleteRecurringRuleConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Its posted transactions and handled occurrence history are kept, but the rule itself will no longer be active.'**
  String get deleteRecurringRuleConfirmMessage;

  /// No description provided for @deleteRuleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteRuleTooltip;

  /// No description provided for @skipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipButton;

  /// No description provided for @postButton.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postButton;

  /// No description provided for @editRecurringRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring rule'**
  String get editRecurringRuleTitle;

  /// No description provided for @newRecurringRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'New recurring rule'**
  String get newRecurringRuleTitle;

  /// No description provided for @recurringKindFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get recurringKindFieldLabel;

  /// No description provided for @recurringRuleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get recurringRuleNameLabel;

  /// No description provided for @enterRecurringRuleNameMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this rule.'**
  String get enterRecurringRuleNameMessage;

  /// No description provided for @sourceAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Source account'**
  String get sourceAccountLabel;

  /// No description provided for @destinationAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination account'**
  String get destinationAccountLabel;

  /// No description provided for @noSameCurrencyDestinationMessage.
  ///
  /// In en, this message translates to:
  /// **'No same-currency destination accounts available.'**
  String get noSameCurrencyDestinationMessage;

  /// No description provided for @noneOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneOptionLabel;

  /// No description provided for @frequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequencyLabel;

  /// No description provided for @recurrenceFrequencyDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceFrequencyDaily;

  /// No description provided for @recurrenceFrequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurrenceFrequencyWeekly;

  /// No description provided for @recurrenceFrequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurrenceFrequencyMonthly;

  /// No description provided for @recurrenceFrequencyYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get recurrenceFrequencyYearly;

  /// No description provided for @intervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Every N (interval)'**
  String get intervalLabel;

  /// No description provided for @enterWholeNumberMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of 1 or more.'**
  String get enterWholeNumberMessage;

  /// No description provided for @remindMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMeLabel;

  /// No description provided for @remindMeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local notification when this is due -- never posts automatically.'**
  String get remindMeSubtitle;

  /// No description provided for @notificationsPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Notifications permission wasn\'t granted -- reminders stay off.'**
  String get notificationsPermissionDeniedMessage;

  /// No description provided for @chooseStartDateMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a start date'**
  String get chooseStartDateMessage;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDateLabel;

  /// No description provided for @noEndDateMessage.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEndDateMessage;

  /// No description provided for @endDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDateLabel;

  /// No description provided for @clearEndDateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear end date'**
  String get clearEndDateTooltip;

  /// No description provided for @chooseAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose an account.'**
  String get chooseAccountMessage;

  /// transfersCrossCurrencyNotSupportedMessage
  ///
  /// In en, this message translates to:
  /// **'Transfers between different currencies aren\'t supported yet ({fromCurrency} → {toCurrency}).'**
  String transfersCrossCurrencyNotSupportedMessage(
      String fromCurrency, String toCurrency);

  /// No description provided for @categoriesScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesScreenTitle;

  /// No description provided for @noCategoriesYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get noCategoriesYetMessage;

  /// No description provided for @systemCategoryIndicatorLabel.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemCategoryIndicatorLabel;

  /// No description provided for @addExpenseCategoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expense category'**
  String get addExpenseCategoryDialogTitle;

  /// No description provided for @addIncomeCategoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add income category'**
  String get addIncomeCategoryDialogTitle;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoryNameLabel;

  /// No description provided for @addCategoryButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addCategoryButton;

  /// No description provided for @categoryIconGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get categoryIconGroceries;

  /// No description provided for @categoryIconPublicTransport.
  ///
  /// In en, this message translates to:
  /// **'Public Transport'**
  String get categoryIconPublicTransport;

  /// No description provided for @categoryIconBillsUtilities.
  ///
  /// In en, this message translates to:
  /// **'Bills & Utilities'**
  String get categoryIconBillsUtilities;

  /// No description provided for @categoryIconDiningOut.
  ///
  /// In en, this message translates to:
  /// **'Dining Out'**
  String get categoryIconDiningOut;

  /// No description provided for @categoryIconHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryIconHealth;

  /// No description provided for @categoryIconOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryIconOther;

  /// No description provided for @categoryIconSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categoryIconSalary;

  /// No description provided for @categoryIconOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other Income'**
  String get categoryIconOtherIncome;

  /// No description provided for @categoryIconCoffeeCafe.
  ///
  /// In en, this message translates to:
  /// **'Coffee & Cafe'**
  String get categoryIconCoffeeCafe;

  /// No description provided for @categoryIconBarsDrinks.
  ///
  /// In en, this message translates to:
  /// **'Bars & Drinks'**
  String get categoryIconBarsDrinks;

  /// No description provided for @categoryIconBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get categoryIconBakery;

  /// No description provided for @categoryIconShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryIconShopping;

  /// No description provided for @categoryIconClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get categoryIconClothing;

  /// No description provided for @categoryIconJewelryAccessories.
  ///
  /// In en, this message translates to:
  /// **'Jewelry & Accessories'**
  String get categoryIconJewelryAccessories;

  /// No description provided for @categoryIconCarFuel.
  ///
  /// In en, this message translates to:
  /// **'Car & Fuel'**
  String get categoryIconCarFuel;

  /// No description provided for @categoryIconTaxiRideshare.
  ///
  /// In en, this message translates to:
  /// **'Taxi & Rideshare'**
  String get categoryIconTaxiRideshare;

  /// No description provided for @categoryIconBikeScooter.
  ///
  /// In en, this message translates to:
  /// **'Bike & Scooter'**
  String get categoryIconBikeScooter;

  /// No description provided for @categoryIconFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get categoryIconFlights;

  /// No description provided for @categoryIconRentHousing.
  ///
  /// In en, this message translates to:
  /// **'Rent & Housing'**
  String get categoryIconRentHousing;

  /// No description provided for @categoryIconElectricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get categoryIconElectricity;

  /// No description provided for @categoryIconWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get categoryIconWater;

  /// No description provided for @categoryIconInternetPhone.
  ///
  /// In en, this message translates to:
  /// **'Internet & Phone'**
  String get categoryIconInternetPhone;

  /// No description provided for @categoryIconRepairsMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Repairs & Maintenance'**
  String get categoryIconRepairsMaintenance;

  /// No description provided for @categoryIconPharmacyMedicine.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy & Medicine'**
  String get categoryIconPharmacyMedicine;

  /// No description provided for @categoryIconFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get categoryIconFitness;

  /// No description provided for @categoryIconPersonalCare.
  ///
  /// In en, this message translates to:
  /// **'Personal Care'**
  String get categoryIconPersonalCare;

  /// No description provided for @categoryIconMoviesEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Movies & Entertainment'**
  String get categoryIconMoviesEntertainment;

  /// No description provided for @categoryIconGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get categoryIconGames;

  /// No description provided for @categoryIconEventsTickets.
  ///
  /// In en, this message translates to:
  /// **'Events & Tickets'**
  String get categoryIconEventsTickets;

  /// No description provided for @categoryIconCelebrations.
  ///
  /// In en, this message translates to:
  /// **'Celebrations'**
  String get categoryIconCelebrations;

  /// No description provided for @categoryIconEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryIconEducation;

  /// No description provided for @categoryIconBooksLearning.
  ///
  /// In en, this message translates to:
  /// **'Books & Learning'**
  String get categoryIconBooksLearning;

  /// No description provided for @categoryIconKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get categoryIconKids;

  /// No description provided for @categoryIconPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get categoryIconPets;

  /// No description provided for @categoryIconTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryIconTravel;

  /// No description provided for @categoryIconHotelsLodging.
  ///
  /// In en, this message translates to:
  /// **'Hotels & Lodging'**
  String get categoryIconHotelsLodging;

  /// No description provided for @categoryIconBankFees.
  ///
  /// In en, this message translates to:
  /// **'Bank & Financial Fees'**
  String get categoryIconBankFees;

  /// No description provided for @categoryIconInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get categoryIconInsurance;

  /// No description provided for @categoryIconSavingsInvestments.
  ///
  /// In en, this message translates to:
  /// **'Savings & Investments'**
  String get categoryIconSavingsInvestments;

  /// No description provided for @categoryIconCardFees.
  ///
  /// In en, this message translates to:
  /// **'Card Fees'**
  String get categoryIconCardFees;

  /// No description provided for @categoryIconTaxes.
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get categoryIconTaxes;

  /// No description provided for @categoryIconGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoryIconGifts;

  /// No description provided for @categoryIconDonationsCharity.
  ///
  /// In en, this message translates to:
  /// **'Donations & Charity'**
  String get categoryIconDonationsCharity;

  /// No description provided for @categoryIconSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get categoryIconSubscriptions;

  /// No description provided for @categoryIconCloudStorage.
  ///
  /// In en, this message translates to:
  /// **'Cloud & Storage'**
  String get categoryIconCloudStorage;

  /// No description provided for @categoryIconAiSoftware.
  ///
  /// In en, this message translates to:
  /// **'AI & Software'**
  String get categoryIconAiSoftware;

  /// No description provided for @categoryIconInvestmentIncome.
  ///
  /// In en, this message translates to:
  /// **'Investment Income'**
  String get categoryIconInvestmentIncome;

  /// No description provided for @categoryIconBusinessIncome.
  ///
  /// In en, this message translates to:
  /// **'Business Income'**
  String get categoryIconBusinessIncome;

  /// No description provided for @categoryIconBonusReward.
  ///
  /// In en, this message translates to:
  /// **'Bonus & Reward'**
  String get categoryIconBonusReward;

  /// No description provided for @categoryIconMiscellaneous.
  ///
  /// In en, this message translates to:
  /// **'Miscellaneous'**
  String get categoryIconMiscellaneous;

  /// No description provided for @categoryColorSlate.
  ///
  /// In en, this message translates to:
  /// **'Slate'**
  String get categoryColorSlate;

  /// No description provided for @categoryColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get categoryColorRed;

  /// No description provided for @categoryColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get categoryColorOrange;

  /// No description provided for @categoryColorAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get categoryColorAmber;

  /// No description provided for @categoryColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get categoryColorYellow;

  /// No description provided for @categoryColorLime.
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get categoryColorLime;

  /// No description provided for @categoryColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get categoryColorGreen;

  /// No description provided for @categoryColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get categoryColorTeal;

  /// No description provided for @categoryColorCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get categoryColorCyan;

  /// No description provided for @categoryColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get categoryColorBlue;

  /// No description provided for @categoryColorIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get categoryColorIndigo;

  /// No description provided for @categoryColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get categoryColorPurple;

  /// No description provided for @categoryColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get categoryColorPink;

  /// No description provided for @categoryColorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get categoryColorBrown;

  /// No description provided for @editCategoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategoryDialogTitle;

  /// No description provided for @categoryIconFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get categoryIconFieldLabel;

  /// No description provided for @categoryColorFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get categoryColorFieldLabel;

  /// No description provided for @editCategoryButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editCategoryButton;

  /// No description provided for @editCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategoryTooltip;

  /// No description provided for @cardNetworkBadgeUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get cardNetworkBadgeUnknownLabel;

  /// Checkpoint U1: screen-reader label for CurrencyBadge -- announces the ISO 4217 code even where the badge itself renders only a symbol/region glyph.
  ///
  /// In en, this message translates to:
  /// **'Currency: {code}'**
  String currencyBadgeSemanticLabel(Object code);

  /// profileLocationSummary
  ///
  /// In en, this message translates to:
  /// **'Living in {currentCountry} ({livingCurrency}) · Home: {homeCountry} ({homeCurrency})'**
  String profileLocationSummary(String currentCountry, String livingCurrency,
      String homeCountry, String homeCurrency);

  /// couldNotLoadProfile
  ///
  /// In en, this message translates to:
  /// **'Could not load profile: {error}'**
  String couldNotLoadProfile(String error);

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @beta0DisclaimerMessage.
  ///
  /// In en, this message translates to:
  /// **'Multi-currency tracking, reference exchange rates, and recurring reminders are ready to use today. Receipt scanning, cloud sync, and AI coaching are coming in a future update.'**
  String get beta0DisclaimerMessage;

  /// No description provided for @homeQuickGlanceNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get homeQuickGlanceNotSet;

  /// No description provided for @homeGoalsQuickGlanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get homeGoalsQuickGlanceLabel;

  /// couldNotSavePreferencesMessage
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String couldNotSavePreferencesMessage(String error);

  /// No description provided for @editTransactionGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransactionGenericTitle;

  /// couldNotLoadTransactionDetail
  ///
  /// In en, this message translates to:
  /// **'Could not load this transaction: {error}'**
  String couldNotLoadTransactionDetail(String error);

  /// No description provided for @transactionDetailScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transactionDetailScreenTitle;

  /// No description provided for @deleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteTooltip;

  /// No description provided for @deleteTransactionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction?'**
  String get deleteTransactionConfirmTitle;

  /// No description provided for @deleteTransactionConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'It will no longer count toward any balance, budget, or total.'**
  String get deleteTransactionConfirmMessage;

  /// No description provided for @transactionDetailFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transactionDetailFromLabel;

  /// No description provided for @transactionDetailToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transactionDetailToLabel;

  /// No description provided for @transactionDetailNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get transactionDetailNoteLabel;

  /// No description provided for @appearanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSectionTitle;

  /// No description provided for @themeCustomizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Customization'**
  String get themeCustomizationTitle;

  /// No description provided for @themeCustomizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make the app yours.'**
  String get themeCustomizationSubtitle;

  /// No description provided for @presetThemesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Preset themes'**
  String get presetThemesSectionTitle;

  /// No description provided for @themeStyleLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeStyleLight;

  /// No description provided for @themeStyleDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeStyleDark;

  /// No description provided for @themeStylePink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get themeStylePink;

  /// No description provided for @themeStyleOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get themeStyleOcean;

  /// No description provided for @themeStyleForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get themeStyleForest;

  /// No description provided for @themeSelectedSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get themeSelectedSemanticLabel;

  /// No description provided for @themeCustomizationPrivacyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'All themes keep your data 100% secure and 100% local.'**
  String get themeCustomizationPrivacyDisclaimer;

  /// No description provided for @referenceRateSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reference Rate'**
  String get referenceRateSectionTitle;

  /// No description provided for @referenceRateExplanation.
  ///
  /// In en, this message translates to:
  /// **'An approximate market rate for reference only -- not guaranteed for an actual exchange or transfer.'**
  String get referenceRateExplanation;

  /// referenceRateEquation
  ///
  /// In en, this message translates to:
  /// **'1 {base} = {rate} {quote}'**
  String referenceRateEquation(String base, String rate, String quote);

  /// No description provided for @referenceRateSameCurrencyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your home and living currency are the same, so there\'s no reference rate to show.'**
  String get referenceRateSameCurrencyMessage;

  /// referenceRateSourceLabel
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String referenceRateSourceLabel(String source);

  /// referenceRateUpdatedLabel
  ///
  /// In en, this message translates to:
  /// **'Updated {timestamp}'**
  String referenceRateUpdatedLabel(String timestamp);

  /// No description provided for @referenceRateStaleIndicator.
  ///
  /// In en, this message translates to:
  /// **'Showing the last rate we could fetch'**
  String get referenceRateStaleIndicator;

  /// No description provided for @referenceRateUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Reference rate isn\'t available right now.'**
  String get referenceRateUnavailableMessage;

  /// No description provided for @referenceRateRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get referenceRateRefreshTooltip;

  /// approxAmountLabel
  ///
  /// In en, this message translates to:
  /// **'≈ {amount}'**
  String approxAmountLabel(String amount);

  /// approxAmountStaleLabel
  ///
  /// In en, this message translates to:
  /// **'≈ {amount} (cached)'**
  String approxAmountStaleLabel(String amount);

  /// No description provided for @currencyConverterTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency Converter'**
  String get currencyConverterTitle;

  /// No description provided for @currencyConverterFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get currencyConverterFromLabel;

  /// No description provided for @currencyConverterToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get currencyConverterToLabel;

  /// No description provided for @currencyConverterAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get currencyConverterAmountLabel;

  /// No description provided for @currencyConverterSwapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Swap currencies'**
  String get currencyConverterSwapTooltip;

  /// No description provided for @currencyConverterSameCurrencyMessage.
  ///
  /// In en, this message translates to:
  /// **'From and To are the same currency, so the converted amount is exactly what you entered.'**
  String get currencyConverterSameCurrencyMessage;

  /// No description provided for @currencyConverterEnterAmountMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount to convert.'**
  String get currencyConverterEnterAmountMessage;

  /// No description provided for @amountTooLargeMessage.
  ///
  /// In en, this message translates to:
  /// **'The converted amount is too large to display.'**
  String get amountTooLargeMessage;

  /// No description provided for @favoritePairsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorite pairs'**
  String get favoritePairsSectionTitle;

  /// No description provided for @favoritePairsSessionNote.
  ///
  /// In en, this message translates to:
  /// **'Favorite pairs are remembered for this session only.'**
  String get favoritePairsSessionNote;

  /// No description provided for @noFavoritePairsMessage.
  ///
  /// In en, this message translates to:
  /// **'No favorite pairs yet.'**
  String get noFavoritePairsMessage;

  /// No description provided for @addFavoritePairTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add favorite pair'**
  String get addFavoritePairTooltip;

  /// No description provided for @removeFavoritePairTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove favorite pair'**
  String get removeFavoritePairTooltip;

  /// favoritePairsLimitReachedMessage
  ///
  /// In en, this message translates to:
  /// **'You can save up to {limit} favorite pairs.'**
  String favoritePairsLimitReachedMessage(int limit);

  /// No description provided for @cloudAccountSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Account'**
  String get cloudAccountSectionTitle;

  /// No description provided for @cloudAccountStatusChipUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get cloudAccountStatusChipUnavailable;

  /// No description provided for @cloudAccountStatusChipLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Local only'**
  String get cloudAccountStatusChipLocalOnly;

  /// No description provided for @cloudAccountStatusChipSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get cloudAccountStatusChipSignedIn;

  /// No description provided for @cloudAccountStatusChipSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get cloudAccountStatusChipSessionExpired;

  /// No description provided for @cloudAccountUnavailableExplanation.
  ///
  /// In en, this message translates to:
  /// **'Cloud accounts aren\'t available in this version yet. Everything you enter stays on this device.'**
  String get cloudAccountUnavailableExplanation;

  /// No description provided for @cloudAccountLocalOnlyExplanation.
  ///
  /// In en, this message translates to:
  /// **'You\'re not signed in. Your data stays on this device only.'**
  String get cloudAccountLocalOnlyExplanation;

  /// cloudAccountSignedInExplanation
  ///
  /// In en, this message translates to:
  /// **'Signed in with cloud account {cloudUserId}. Syncing your financial data isn\'t available yet -- this only remembers who you\'re signed in as.'**
  String cloudAccountSignedInExplanation(String cloudUserId);

  /// No description provided for @cloudAccountSessionExpiredExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your cloud session expired. Sign in again to continue. Nothing stored on this device has been affected.'**
  String get cloudAccountSessionExpiredExplanation;

  /// No description provided for @cloudAccountSignInButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get cloudAccountSignInButtonLabel;

  /// No description provided for @cloudAccountSignOutButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get cloudAccountSignOutButtonLabel;

  /// No description provided for @cloudAccountSignOutNeverDeletesLocalDataNote.
  ///
  /// In en, this message translates to:
  /// **'Signing out never deletes anything saved on this device.'**
  String get cloudAccountSignOutNeverDeletesLocalDataNote;

  /// No description provided for @cloudAccountDifferentAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t switch cloud accounts'**
  String get cloudAccountDifferentAccountDialogTitle;

  /// No description provided for @cloudAccountDifferentAccountDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This device is already linked to a different cloud account. Switching to a new cloud account on a device with existing local data isn\'t supported yet. Your local data has not been changed.'**
  String get cloudAccountDifferentAccountDialogMessage;

  /// No description provided for @cloudAccountDialogDismissLabel.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get cloudAccountDialogDismissLabel;

  /// No description provided for @addAccountTypeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccountTypeScreenTitle;

  /// No description provided for @addAccountTypeCashTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get addAccountTypeCashTitle;

  /// No description provided for @addAccountTypeCashDescription.
  ///
  /// In en, this message translates to:
  /// **'Physical cash you keep on hand, like bills in your wallet.'**
  String get addAccountTypeCashDescription;

  /// No description provided for @addAccountTypeBankTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get addAccountTypeBankTitle;

  /// No description provided for @addAccountTypeBankDescription.
  ///
  /// In en, this message translates to:
  /// **'A checking or everyday account at a bank.'**
  String get addAccountTypeBankDescription;

  /// No description provided for @addAccountTypeSavingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings account'**
  String get addAccountTypeSavingsTitle;

  /// No description provided for @addAccountTypeSavingsDescription.
  ///
  /// In en, this message translates to:
  /// **'A savings account you keep separate from everyday spending.'**
  String get addAccountTypeSavingsDescription;

  /// No description provided for @addAccountTypeWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'E-money / Wallet'**
  String get addAccountTypeWalletTitle;

  /// No description provided for @addAccountTypeWalletDescription.
  ///
  /// In en, this message translates to:
  /// **'A digital wallet or e-money balance, like a prepaid app balance.'**
  String get addAccountTypeWalletDescription;

  /// No description provided for @addAccountTypeDepositTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get addAccountTypeDepositTitle;

  /// No description provided for @addAccountTypeDepositDescription.
  ///
  /// In en, this message translates to:
  /// **'A fixed or recurring deposit that earns interest until maturity.'**
  String get addAccountTypeDepositDescription;

  /// No description provided for @addAccountTypeCreditCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get addAccountTypeCreditCardTitle;

  /// No description provided for @addAccountTypeCreditCardDescription.
  ///
  /// In en, this message translates to:
  /// **'A credit card balance you owe, with a credit limit.'**
  String get addAccountTypeCreditCardDescription;

  /// No description provided for @addAccountAmountOwedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount you currently owe'**
  String get addAccountAmountOwedLabel;

  /// No description provided for @addAccountPrincipalLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount deposited'**
  String get addAccountPrincipalLabel;

  /// No description provided for @addAccountInstitutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Institution (optional)'**
  String get addAccountInstitutionLabel;

  /// No description provided for @addAccountInstitutionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Chase, HSBC'**
  String get addAccountInstitutionHint;

  /// No description provided for @addAccountCreditLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get addAccountCreditLimitLabel;

  /// No description provided for @addAccountCardNetworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Card network (optional)'**
  String get addAccountCardNetworkLabel;

  /// No description provided for @addAccountCardNetworkNone.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get addAccountCardNetworkNone;

  /// No description provided for @addAccountCardNetworkVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get addAccountCardNetworkVisa;

  /// No description provided for @addAccountCardNetworkMastercard.
  ///
  /// In en, this message translates to:
  /// **'Mastercard'**
  String get addAccountCardNetworkMastercard;

  /// No description provided for @addAccountCardNetworkJcb.
  ///
  /// In en, this message translates to:
  /// **'JCB'**
  String get addAccountCardNetworkJcb;

  /// No description provided for @addAccountCardNetworkAmex.
  ///
  /// In en, this message translates to:
  /// **'American Express'**
  String get addAccountCardNetworkAmex;

  /// No description provided for @addAccountCardNetworkOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get addAccountCardNetworkOther;

  /// No description provided for @addAccountLast4Label.
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits (optional)'**
  String get addAccountLast4Label;

  /// No description provided for @addAccountLast4ErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter exactly 4 digits.'**
  String get addAccountLast4ErrorMessage;

  /// No description provided for @addAccountExpiryMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry month (optional)'**
  String get addAccountExpiryMonthLabel;

  /// No description provided for @addAccountExpiryYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry year (optional)'**
  String get addAccountExpiryYearLabel;

  /// No description provided for @addAccountStatementClosingDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Statement closing day (optional)'**
  String get addAccountStatementClosingDayLabel;

  /// No description provided for @addAccountDueDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment due day (optional)'**
  String get addAccountDueDayLabel;

  /// No description provided for @addAccountDayOfMonthErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a day between 1 and 31.'**
  String get addAccountDayOfMonthErrorMessage;

  /// No description provided for @addAccountDepositTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Deposit type'**
  String get addAccountDepositTypeLabel;

  /// No description provided for @addAccountDepositTypeFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get addAccountDepositTypeFixed;

  /// No description provided for @addAccountDepositTypeShortTerm.
  ///
  /// In en, this message translates to:
  /// **'Short-term'**
  String get addAccountDepositTypeShortTerm;

  /// No description provided for @addAccountDepositTypeRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get addAccountDepositTypeRecurring;

  /// No description provided for @addAccountDepositTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get addAccountDepositTypeOther;

  /// No description provided for @addAccountStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get addAccountStartDateLabel;

  /// No description provided for @addAccountChooseStartDateMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a start date.'**
  String get addAccountChooseStartDateMessage;

  /// No description provided for @addAccountAnnualRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual interest rate (%)'**
  String get addAccountAnnualRateLabel;

  /// No description provided for @addAccountInterestMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest method'**
  String get addAccountInterestMethodLabel;

  /// No description provided for @addAccountInterestMethodSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get addAccountInterestMethodSimple;

  /// No description provided for @addAccountInterestMethodCompound.
  ///
  /// In en, this message translates to:
  /// **'Compound'**
  String get addAccountInterestMethodCompound;

  /// No description provided for @addAccountTermNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Term length'**
  String get addAccountTermNumberLabel;

  /// No description provided for @addAccountTermNumberErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a term of at least 1.'**
  String get addAccountTermNumberErrorMessage;

  /// No description provided for @addAccountTermUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Term unit'**
  String get addAccountTermUnitLabel;

  /// No description provided for @addAccountTermUnitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get addAccountTermUnitDays;

  /// No description provided for @addAccountTermUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get addAccountTermUnitMonths;

  /// No description provided for @addAccountTermUnitYears.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get addAccountTermUnitYears;

  /// No description provided for @addAccountCompoundingFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Compounding frequency'**
  String get addAccountCompoundingFrequencyLabel;

  /// No description provided for @addAccountCompoundingFrequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get addAccountCompoundingFrequencyMonthly;

  /// No description provided for @addAccountCompoundingFrequencyQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get addAccountCompoundingFrequencyQuarterly;

  /// No description provided for @addAccountCompoundingFrequencySemiannual.
  ///
  /// In en, this message translates to:
  /// **'Semiannual'**
  String get addAccountCompoundingFrequencySemiannual;

  /// No description provided for @addAccountCompoundingFrequencyAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get addAccountCompoundingFrequencyAnnual;

  /// No description provided for @addAccountCompoundingFrequencyAtMaturity.
  ///
  /// In en, this message translates to:
  /// **'At maturity'**
  String get addAccountCompoundingFrequencyAtMaturity;

  /// No description provided for @addAccountChooseCompoundingFrequencyMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a compounding frequency.'**
  String get addAccountChooseCompoundingFrequencyMessage;

  /// No description provided for @addAccountAutoRenewLabel.
  ///
  /// In en, this message translates to:
  /// **'Renew automatically at maturity'**
  String get addAccountAutoRenewLabel;

  /// No description provided for @addAccountInstallmentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Installment amount (optional)'**
  String get addAccountInstallmentAmountLabel;

  /// No description provided for @addAccountInstallmentFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Installment frequency (optional)'**
  String get addAccountInstallmentFrequencyLabel;

  /// No description provided for @addAccountInstallmentFrequencyNone.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get addAccountInstallmentFrequencyNone;

  /// No description provided for @addAccountInstallmentFrequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get addAccountInstallmentFrequencyWeekly;

  /// No description provided for @addAccountInstallmentFrequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get addAccountInstallmentFrequencyMonthly;

  /// No description provided for @addAccountInstallmentFrequencyQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get addAccountInstallmentFrequencyQuarterly;

  /// No description provided for @addAccountInstallmentFrequencyYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get addAccountInstallmentFrequencyYearly;

  /// No description provided for @addAccountInterestDestinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Send interest to (optional)'**
  String get addAccountInterestDestinationLabel;

  /// No description provided for @addAccountNoneOption.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get addAccountNoneOption;

  /// No description provided for @addAccountEstimatedInterestLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated interest'**
  String get addAccountEstimatedInterestLabel;

  /// No description provided for @addAccountEstimatedMaturityValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated maturity value'**
  String get addAccountEstimatedMaturityValueLabel;

  /// No description provided for @addAccountEstimatedMaturityDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated maturity date'**
  String get addAccountEstimatedMaturityDateLabel;

  /// No description provided for @addAccountEstimateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Estimate only -- not a guaranteed bank figure.'**
  String get addAccountEstimateDisclaimer;

  /// No description provided for @addAccountCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get addAccountCreateButton;

  /// addAccountCreationFailedMessage
  ///
  /// In en, this message translates to:
  /// **'Could not create the account: {error}'**
  String addAccountCreationFailedMessage(String error);

  /// No description provided for @addAccountExpiryMonthErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a month between 1 and 12.'**
  String get addAccountExpiryMonthErrorMessage;

  /// Checkpoint J: title of the dedicated Net Worth screen, and the label of the More-screen row that opens it. Reached only via a deliberate tap from More -- never shown on Home.
  ///
  /// In en, this message translates to:
  /// **'Net Worth'**
  String get netWorthTitle;

  /// Checkpoint J: a short explanatory line at the top of the Net Worth screen, clarifying that multiple currencies are shown as independent sections rather than one converted total.
  ///
  /// In en, this message translates to:
  /// **'Everything you own, minus everything you owe. Shown separately per currency -- amounts are never converted or combined.'**
  String get netWorthScreenSubtitle;

  /// Checkpoint J: the small eyebrow caption under a currency's hero net-worth figure on the Net Worth screen.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get netWorthTotalLabel;

  /// No description provided for @totalAssetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total assets'**
  String get totalAssetsLabel;

  /// No description provided for @totalLiabilitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total liabilities'**
  String get totalLiabilitiesLabel;

  /// No description provided for @assetsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assetsSectionTitle;

  /// No description provided for @liabilitiesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get liabilitiesSectionTitle;

  /// Checkpoint J: a small badge next to a deposit account's line in the Net Worth screen's Assets list, distinguishing it from ordinary cash/bank/wallet assets.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get assetsDepositBadge;

  /// Checkpoint J: empty state for the Net Worth screen when the profile genuinely has no accounts at all.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet. Add one to see your net worth here.'**
  String get netWorthEmptyMessage;

  /// Checkpoint J: error state for the Net Worth screen.
  ///
  /// In en, this message translates to:
  /// **'Could not load your net worth: {error}'**
  String couldNotLoadNetWorth(String error);

  /// Checkpoint J: title of the deposit-specific details card on Account Detail, shown only for deposit-subtype accounts.
  ///
  /// In en, this message translates to:
  /// **'Deposit details'**
  String get depositDetailsSectionTitle;

  /// No description provided for @depositInterestRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest rate'**
  String get depositInterestRateLabel;

  /// No description provided for @depositStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get depositStartDateLabel;

  /// No description provided for @depositMaturityDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Maturity date'**
  String get depositMaturityDateLabel;

  /// No description provided for @depositTermLabel.
  ///
  /// In en, this message translates to:
  /// **'Term'**
  String get depositTermLabel;

  /// Checkpoint J: shown when today is strictly before the deposit's maturity date. Independent of the account's own open/closed lifecycle status.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get depositStatusActive;

  /// Checkpoint J: shown when today is on or after the deposit's maturity date. Says nothing about whether the principal was withdrawn or rolled over. Independent of the account's own open/closed lifecycle status.
  ///
  /// In en, this message translates to:
  /// **'Matured'**
  String get depositStatusMatured;

  /// No description provided for @depositTermUnitDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get depositTermUnitDay;

  /// No description provided for @depositTermUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get depositTermUnitDays;

  /// No description provided for @depositTermUnitMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get depositTermUnitMonth;

  /// No description provided for @depositTermUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get depositTermUnitMonths;

  /// No description provided for @depositTermUnitYear.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get depositTermUnitYear;

  /// No description provided for @depositTermUnitYears.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get depositTermUnitYears;

  /// Checkpoint N. Deliberately 'Cheque', never 'Check' -- this app's frozen vocabulary for the instrument. Translators: keep this consistent with every other chequeXxx/XxxxChequeXxx key below.
  ///
  /// In en, this message translates to:
  /// **'Cheques'**
  String get chequesTitle;

  /// No description provided for @couldNotLoadCheques.
  ///
  /// In en, this message translates to:
  /// **'Could not load cheques: {error}'**
  String couldNotLoadCheques(String error);

  /// No description provided for @noChequesYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No cheques yet. Tap + to record one.'**
  String get noChequesYetMessage;

  /// No description provided for @recordIssuedChequeTitle.
  ///
  /// In en, this message translates to:
  /// **'Record issued cheque'**
  String get recordIssuedChequeTitle;

  /// No description provided for @recordReceivedChequeTitle.
  ///
  /// In en, this message translates to:
  /// **'Record received cheque'**
  String get recordReceivedChequeTitle;

  /// No description provided for @chequeStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get chequeStatusPending;

  /// No description provided for @chequeStatusCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get chequeStatusCleared;

  /// No description provided for @chequeStatusBounced.
  ///
  /// In en, this message translates to:
  /// **'Bounced'**
  String get chequeStatusBounced;

  /// No description provided for @chequeStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get chequeStatusStopped;

  /// No description provided for @chequeStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get chequeStatusCancelled;

  /// No description provided for @unknownAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown account'**
  String get unknownAccountLabel;

  /// No description provided for @chequeNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'No.'**
  String get chequeNumberLabel;

  /// No description provided for @chequeNumberFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Cheque number'**
  String get chequeNumberFieldLabel;

  /// No description provided for @chequeBookLabelField.
  ///
  /// In en, this message translates to:
  /// **'Chequebook'**
  String get chequeBookLabelField;

  /// No description provided for @enterChequeBookLabelMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a label for this chequebook.'**
  String get enterChequeBookLabelMessage;

  /// No description provided for @startingChequeNumberOptionalField.
  ///
  /// In en, this message translates to:
  /// **'Starting cheque number (optional)'**
  String get startingChequeNumberOptionalField;

  /// No description provided for @newChequeBookDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New chequebook'**
  String get newChequeBookDialogTitle;

  /// No description provided for @selectAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Select an account.'**
  String get selectAccountMessage;

  /// No description provided for @selectChequeBookMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a chequebook.'**
  String get selectChequeBookMessage;

  /// No description provided for @enterChequeNumberMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the cheque number.'**
  String get enterChequeNumberMessage;

  /// No description provided for @payeeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get payeeFieldLabel;

  /// No description provided for @payerFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Payer / From'**
  String get payerFieldLabel;

  /// No description provided for @enterPayeeMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the payee\'s name.'**
  String get enterPayeeMessage;

  /// No description provided for @enterPayerMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the payer\'s name.'**
  String get enterPayerMessage;

  /// No description provided for @issueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Issue date'**
  String get issueDateLabel;

  /// No description provided for @receivedDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Received date'**
  String get receivedDateLabel;

  /// No description provided for @clearedDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Cleared date'**
  String get clearedDateLabel;

  /// No description provided for @bouncedDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Bounced date'**
  String get bouncedDateLabel;

  /// No description provided for @stoppedDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Stopped date'**
  String get stoppedDateLabel;

  /// No description provided for @cancelledDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled date'**
  String get cancelledDateLabel;

  /// No description provided for @memoOptionalFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Memo (optional)'**
  String get memoOptionalFieldLabel;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// No description provided for @markAsClearedButton.
  ///
  /// In en, this message translates to:
  /// **'Mark as cleared'**
  String get markAsClearedButton;

  /// No description provided for @markAsBouncedButton.
  ///
  /// In en, this message translates to:
  /// **'Mark as bounced'**
  String get markAsBouncedButton;

  /// No description provided for @stopChequeButton.
  ///
  /// In en, this message translates to:
  /// **'Stop cheque'**
  String get stopChequeButton;

  /// No description provided for @cancelChequeButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel cheque'**
  String get cancelChequeButton;

  /// No description provided for @deleteChequeButton.
  ///
  /// In en, this message translates to:
  /// **'Delete cheque'**
  String get deleteChequeButton;

  /// No description provided for @deleteChequeConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this cheque? This cannot be undone.'**
  String get deleteChequeConfirmationMessage;

  /// No description provided for @viewPostedTransactionButton.
  ///
  /// In en, this message translates to:
  /// **'View posted transaction'**
  String get viewPostedTransactionButton;

  /// No description provided for @chequeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get chequeDetailTitle;

  /// No description provided for @chequeNoLongerAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This cheque is no longer available.'**
  String get chequeNoLongerAvailableMessage;

  /// Checkpoint O: title of the credit-card-specific details card on Account Detail, shown only for creditCard-subtype accounts when a credit facility exists.
  ///
  /// In en, this message translates to:
  /// **'Credit details'**
  String get creditFacilityDetailsSectionTitle;

  /// Checkpoint O: max(0, creditLimit - amountOwed) -- a presentation-only figure, never persisted. Shown as 'Not set' when no meaningful credit limit is configured.
  ///
  /// In en, this message translates to:
  /// **'Available credit'**
  String get availableCreditLabel;

  /// Checkpoint O: amountOwed / creditLimit * 100, formatted as a percentage. May exceed 100% for an over-limit balance -- never clamped or hidden. Shown as 'Not set' when no meaningful credit limit is configured.
  ///
  /// In en, this message translates to:
  /// **'Credit utilization'**
  String get creditUtilizationLabel;

  /// Checkpoint O: Edit Account's credit-limit input, shown only for a creditCard-subtype account. Deliberately the same wording as addAccountCreditLimitLabel -- same concept, same field, just editable after creation too now.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get editCreditLimitFieldLabel;
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

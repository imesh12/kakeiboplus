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
  /// **'Beta 0 -- local money engine. FX, receipts, notifications, cloud sync, and AI coaching are not implemented yet.'**
  String get beta0DisclaimerMessage;

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

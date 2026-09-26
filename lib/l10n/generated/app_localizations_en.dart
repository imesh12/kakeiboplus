// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get brandName => 'KakeiboPlus';

  @override
  String get internationalPreferences => 'International preferences';

  @override
  String get locationSection => 'Location';

  @override
  String get currencySection => 'Currency';

  @override
  String get languageAndFormatSection => 'Language & format';

  @override
  String get homeCountry => 'Home country';

  @override
  String get currentCountry => 'Current country';

  @override
  String get homeCurrency => 'Home currency';

  @override
  String get livingCurrency => 'Living currency';

  @override
  String get language => 'Language';

  @override
  String get dateFormat => 'Date format';

  @override
  String get numberFormat => 'Number format';

  @override
  String get timezone => 'Timezone';

  @override
  String get save => 'Save';

  @override
  String get navHome => 'Home';

  @override
  String get navActivity => 'Activity';

  @override
  String get navAdd => 'Add';

  @override
  String get navProfile => 'Profile';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navMore => 'More';

  @override
  String get moreScreenSubtitle => 'Manage your money tools and preferences';

  @override
  String get morePlanningSectionTitle => 'Planning';

  @override
  String get moreMoneyToolsSectionTitle => 'Money Tools';

  @override
  String get moreOrganizationSectionTitle => 'Organization';

  @override
  String get morePersonalizationSectionTitle => 'Personalization';

  @override
  String get moreCloudSecuritySectionTitle => 'Cloud & Security';

  @override
  String get transactionTypeExpense => 'Expense';

  @override
  String get transactionTypeIncome => 'Income';

  @override
  String get transactionTypeTransfer => 'Transfer';

  @override
  String get amountLabel => 'Amount';

  @override
  String get accountLabel => 'Account';

  @override
  String get fromAccountLabel => 'From account';

  @override
  String get toAccountLabel => 'To account';

  @override
  String get categoryOptionalLabel => 'Category (optional)';

  @override
  String get noteOptionalLabel => 'Note (optional)';

  @override
  String get dateLabel => 'Date';

  @override
  String get addAccountFirstMessage =>
      'Add an account first (Profile → Accounts) before recording money.';

  @override
  String couldNotLoadAccounts(String error) {
    return 'Could not load accounts: $error';
  }

  @override
  String couldNotLoadCategories(String error) {
    return 'Could not load categories: $error';
  }

  @override
  String couldNotSaveTransaction(String error) {
    return 'Could not save: $error';
  }

  @override
  String get enterValidAmount => 'Enter a valid amount.';

  @override
  String get chooseDestinationAccount => 'Choose a destination account.';

  @override
  String noEligibleTransferDestination(String currency) {
    return 'No other $currency account to transfer to yet. Cross-currency transfers are not supported in this version.';
  }

  @override
  String currencyMismatchError(String fromCurrency, String toCurrency) {
    return 'That amount\'s currency doesn\'t match the selected account ($fromCurrency → $toCurrency).';
  }

  @override
  String get transactionNoLongerAvailable =>
      'This transaction is no longer available -- it may have been deleted elsewhere.';

  @override
  String get transactionLinkedToChequeError =>
      'This transaction was created by a cleared cheque and can\'t be edited or deleted directly.';

  @override
  String get addExpenseTitle => 'Add expense';

  @override
  String get addIncomeTitle => 'Add income';

  @override
  String get editExpenseTitle => 'Edit expense';

  @override
  String get editIncomeTitle => 'Edit income';

  @override
  String get editTransferTitle => 'Edit transfer';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get accountsSectionTitle => 'Accounts';

  @override
  String get manage => 'Manage';

  @override
  String couldNotLoadBalances(String error) {
    return 'Could not load your balances: $error';
  }

  @override
  String get addAccountToSeeBalance =>
      'Add an account to see your balance, income, and spending here.';

  @override
  String get noAccountsYetMessage =>
      'No accounts yet. Add one to start tracking.';

  @override
  String somethingWentWrong(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get totalAvailableBalance => 'Total available balance';

  @override
  String get incomeThisMonth => 'Income this month';

  @override
  String get spentThisMonth => 'Spent this month';

  @override
  String get dailySpendingPace => 'Daily spending pace';

  @override
  String get dailySpendingPaceDetail =>
      'Average spend per day so far this month';

  @override
  String get remainingMonthlyBudget => 'Remaining monthly budget';

  @override
  String get noBudgetSetMessage =>
      'You haven\'t set a monthly budget yet. Set one to see how much you have left to spend.';

  @override
  String get setMonthlyBudgetButton => 'Set a monthly budget';

  @override
  String get budgetStatusOnTrack => 'On track';

  @override
  String get budgetStatusAheadOfPace => 'Ahead of pace';

  @override
  String get budgetStatusOverBudget => 'Over budget';

  @override
  String get budgetStatusThisMonth => 'This month';

  @override
  String ofAmount(String amount) {
    return 'of $amount';
  }

  @override
  String percentUsedLabel(String percent) {
    return '$percent% used';
  }

  @override
  String recommendedDailySpend(String amount) {
    return 'Recommended: $amount / day for the rest of the month';
  }

  @override
  String get savingsGoalsTitle => 'Savings Goals';

  @override
  String get viewAll => 'View all';

  @override
  String get noSavingsGoalMessage => 'You haven\'t set a savings goal yet.';

  @override
  String get setSavingsGoalButton => 'Set a savings goal';

  @override
  String get allGoalsCompletedMessage =>
      'All your savings goals are completed.';

  @override
  String get overdueLabel => 'Overdue';

  @override
  String get goalStatusInProgress => 'In progress';

  @override
  String get goalStatusCompleted => 'Completed';

  @override
  String get recurringTitle => 'Recurring';

  @override
  String get noRecurringMessage => 'No recurring bills or income set up yet.';

  @override
  String get setUpRecurringButton => 'Set up recurring';

  @override
  String get recurringStatusDueToday => 'Due today';

  @override
  String get recurringStatusUpcoming => 'Upcoming';

  @override
  String couldNotLoadTransactions(String error) {
    return 'Could not load transactions: $error';
  }

  @override
  String get noTransactionsYetMessage =>
      'No transactions yet. Tap Add to record one.';

  @override
  String get searchTransactionsLabel => 'Search transactions';

  @override
  String get searchTransactionsHint =>
      'Search by category, account, note, or amount';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get noMatchingTransactions => 'No matching transactions';

  @override
  String get dateGroupToday => 'Today';

  @override
  String get dateGroupYesterday => 'Yesterday';

  @override
  String dateGroupSemanticLabel(String group) {
    return '$group transactions';
  }

  @override
  String spokenPlusAmount(String amount) {
    return 'plus $amount';
  }

  @override
  String spokenMinusAmount(String amount) {
    return 'minus $amount';
  }

  @override
  String get noAccountsYetTapToAddMessage =>
      'No accounts yet. Tap + to add one.';

  @override
  String get accountTypeCash => 'cash';

  @override
  String get accountTypeBank => 'bank';

  @override
  String get accountTypeCard => 'card';

  @override
  String get accountTypeWallet => 'wallet';

  @override
  String get addAccountDialogTitle => 'Add account';

  @override
  String get accountNameLabel => 'Name';

  @override
  String get enterAccountNameMessage => 'Enter a name.';

  @override
  String get accountTypeLabel => 'Type';

  @override
  String get cancel => 'Cancel';

  @override
  String get addAccountButton => 'Add';

  @override
  String get accountFallbackTitle => 'Account';

  @override
  String get accountNoLongerAvailableMessage =>
      'This account is no longer available.';

  @override
  String couldNotLoadAccountDetail(String error) {
    return 'Could not load this account: $error';
  }

  @override
  String get accountOpeningBalanceLabel => 'Opening balance';

  @override
  String get accountCreatedLabel => 'Created';

  @override
  String get accountBalanceLabel => 'Balance';

  @override
  String get accountInstitutionLabel => 'Institution';

  @override
  String get accountRecentActivityTitle => 'Recent activity';

  @override
  String get accountNoRecentActivityMessage =>
      'No recent activity for this account.';

  @override
  String get editAccountTitle => 'Edit account';

  @override
  String get accountCurrencyLockedMessage =>
      'Currency can\'t be changed after an account is created.';

  @override
  String get closeAccountAction => 'Close account';

  @override
  String get closeCreditCardAction => 'Deactivate card';

  @override
  String get reactivateAccountAction => 'Reactivate account';

  @override
  String get closeAccountConfirmTitle => 'Close this account?';

  @override
  String get closeAccountConfirmMessage =>
      'Its transaction history stays exactly as it is. It just won\'t be available for new transactions until you reactivate it.';

  @override
  String get closeCreditCardConfirmTitle => 'Deactivate this card?';

  @override
  String get closeCreditCardConfirmMessage =>
      'Its transaction history stays exactly as it is. It just won\'t be available for new charges or payments until you reactivate it.';

  @override
  String get reactivateAccountConfirmTitle => 'Reactivate this account?';

  @override
  String get reactivateAccountConfirmMessage =>
      'It will be available for new transactions again, with its existing history and balance unchanged.';

  @override
  String get accountClosedLabel => 'Closed';

  @override
  String get closedAccountsSectionHeader => 'Closed accounts';

  @override
  String get accountHasActiveRecurringRulesMessage =>
      'This account is still used by one or more recurring rules. Change or delete them first, then try closing this account again.';

  @override
  String couldNotCloseAccountMessage(String error) {
    return 'Could not close this account: $error';
  }

  @override
  String couldNotReactivateAccountMessage(String error) {
    return 'Could not reactivate this account: $error';
  }

  @override
  String budgetsScreenTitle(String month) {
    return 'Budgets · $month';
  }

  @override
  String couldNotLoadBudgets(String error) {
    return 'Could not load budgets: $error';
  }

  @override
  String get noBudgetsSetThisMonthMessage =>
      'No budgets set for this month yet. Tap + to set an overall monthly budget or a category budget.';

  @override
  String get overallBudgetsSectionTitle => 'Overall budgets';

  @override
  String get categoryBudgetsSectionTitle => 'Category budgets';

  @override
  String get overallMonthlyBudgetOption => 'Overall monthly budget';

  @override
  String get categoryBudgetOption => 'Category budget';

  @override
  String get editOverallBudgetTitle => 'Edit overall monthly budget';

  @override
  String get setOverallBudgetTitle => 'Set overall monthly budget';

  @override
  String get monthlyBudgetAmountLabel => 'Monthly budget amount';

  @override
  String get editCategoryBudgetTitle => 'Edit category budget';

  @override
  String get setCategoryBudgetTitle => 'Set category budget';

  @override
  String get categoryFieldLabel => 'Category';

  @override
  String get chooseCategoryMessage => 'Choose a category.';

  @override
  String get categoryBudgetAmountLabel => 'Category budget amount';

  @override
  String get previousMonthTooltip => 'Previous month';

  @override
  String get nextMonthTooltip => 'Next month';

  @override
  String get monthSummarySectionTitle => 'Month summary';

  @override
  String get totalBudgetLabel => 'Total budget';

  @override
  String get spentLabel => 'Spent';

  @override
  String get noCategoryBudgetsForMonthMessage =>
      'No category budgets for this month.';

  @override
  String overBudgetByAmountLabel(String amount) {
    return '$amount over budget';
  }

  @override
  String get editTooltip => 'Edit';

  @override
  String get removeTooltip => 'Remove';

  @override
  String couldNotLoadGoals(String error) {
    return 'Could not load goals: $error';
  }

  @override
  String get noSavingsGoalsYetTapMessage =>
      'No savings goals yet. Tap + to set one.';

  @override
  String get newSavingsGoalDialogTitle => 'New savings goal';

  @override
  String get goalNameLabel => 'Goal name';

  @override
  String get enterGoalNameMessage => 'Enter a name for this goal.';

  @override
  String get targetAmountLabel => 'Target amount';

  @override
  String get noTargetDateMessage => 'No target date';

  @override
  String get targetDateLabel => 'Target date';

  @override
  String get chooseButton => 'Choose';

  @override
  String get clearTargetDateTooltip => 'Clear target date';

  @override
  String get goalFallbackTitle => 'Goal';

  @override
  String get editGoalAction => 'Edit goal';

  @override
  String get deleteGoalTooltip => 'Delete goal';

  @override
  String couldNotLoadGoalDetail(String error) {
    return 'Could not load this goal: $error';
  }

  @override
  String get goalNoLongerAvailableMessage =>
      'This goal is no longer available.';

  @override
  String get deleteGoalConfirmTitle => 'Delete this goal?';

  @override
  String get deleteGoalConfirmMessage =>
      'Its contribution history is kept, but the goal itself will no longer be active.';

  @override
  String get deleteButton => 'Delete';

  @override
  String get remainingLabel => 'Remaining';

  @override
  String get recommendedDailyContributionLabel =>
      'Recommended daily contribution';

  @override
  String get contributionHistoryTitle => 'Contribution history';

  @override
  String couldNotLoadContributionHistory(String error) {
    return 'Could not load contribution history: $error';
  }

  @override
  String get noContributionsYetMessage => 'No contributions yet.';

  @override
  String get addContributionDialogTitle => 'Add a contribution';

  @override
  String get addContributionButton => 'Add';

  @override
  String couldNotLoadRecurringRules(String error) {
    return 'Could not load recurring rules: $error';
  }

  @override
  String get noRecurringRulesYetTapMessage =>
      'No recurring rules yet. Tap + to add one.';

  @override
  String get subscriptionsTitle => 'Subscriptions';

  @override
  String get subscriptionsEstimatedMonthlyTotalLabel => 'Est. monthly';

  @override
  String get subscriptionsEstimatedYearlyTotalLabel => 'Est. yearly';

  @override
  String get noActiveSubscriptionsMessage => 'No active subscriptions yet.';

  @override
  String get deleteRecurringRuleConfirmTitle => 'Delete this recurring rule?';

  @override
  String get deleteRecurringRuleConfirmMessage =>
      'Its posted transactions and handled occurrence history are kept, but the rule itself will no longer be active.';

  @override
  String get deleteRuleTooltip => 'Delete';

  @override
  String get skipButton => 'Skip';

  @override
  String get postButton => 'Post';

  @override
  String get editRecurringRuleTitle => 'Edit recurring rule';

  @override
  String get newRecurringRuleTitle => 'New recurring rule';

  @override
  String get recurringKindFieldLabel => 'Type';

  @override
  String get recurringRuleNameLabel => 'Name';

  @override
  String get enterRecurringRuleNameMessage => 'Enter a name for this rule.';

  @override
  String get sourceAccountLabel => 'Source account';

  @override
  String get destinationAccountLabel => 'Destination account';

  @override
  String get noSameCurrencyDestinationMessage =>
      'No same-currency destination accounts available.';

  @override
  String get noneOptionLabel => 'None';

  @override
  String get frequencyLabel => 'Frequency';

  @override
  String get recurrenceFrequencyDaily => 'Daily';

  @override
  String get recurrenceFrequencyWeekly => 'Weekly';

  @override
  String get recurrenceFrequencyMonthly => 'Monthly';

  @override
  String get recurrenceFrequencyYearly => 'Yearly';

  @override
  String get intervalLabel => 'Every N (interval)';

  @override
  String get enterWholeNumberMessage => 'Enter a whole number of 1 or more.';

  @override
  String get remindMeLabel => 'Remind me';

  @override
  String get remindMeSubtitle =>
      'Local notification when this is due -- never posts automatically.';

  @override
  String get notificationsPermissionDeniedMessage =>
      'Notifications permission wasn\'t granted -- reminders stay off.';

  @override
  String get chooseStartDateMessage => 'Choose a start date';

  @override
  String get startDateLabel => 'Start date';

  @override
  String get noEndDateMessage => 'No end date';

  @override
  String get endDateLabel => 'End date';

  @override
  String get clearEndDateTooltip => 'Clear end date';

  @override
  String get chooseAccountMessage => 'Choose an account.';

  @override
  String transfersCrossCurrencyNotSupportedMessage(
      String fromCurrency, String toCurrency) {
    return 'Transfers between different currencies aren\'t supported yet ($fromCurrency → $toCurrency).';
  }

  @override
  String get categoriesScreenTitle => 'Categories';

  @override
  String get noCategoriesYetMessage => 'No categories yet.';

  @override
  String get systemCategoryIndicatorLabel => 'System';

  @override
  String get addExpenseCategoryDialogTitle => 'Add expense category';

  @override
  String get addIncomeCategoryDialogTitle => 'Add income category';

  @override
  String get categoryNameLabel => 'Name';

  @override
  String get addCategoryButton => 'Add';

  @override
  String profileLocationSummary(String currentCountry, String livingCurrency,
      String homeCountry, String homeCurrency) {
    return 'Living in $currentCountry ($livingCurrency) · Home: $homeCountry ($homeCurrency)';
  }

  @override
  String couldNotLoadProfile(String error) {
    return 'Could not load profile: $error';
  }

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get beta0DisclaimerMessage =>
      'Multi-currency tracking, reference exchange rates, and recurring reminders are ready to use today. Receipt scanning, cloud sync, and AI coaching are coming in a future update.';

  @override
  String get homeQuickGlanceNotSet => 'Not set';

  @override
  String get homeGoalsQuickGlanceLabel => 'Goals';

  @override
  String couldNotSavePreferencesMessage(String error) {
    return 'Could not save: $error';
  }

  @override
  String get editTransactionGenericTitle => 'Edit transaction';

  @override
  String couldNotLoadTransactionDetail(String error) {
    return 'Could not load this transaction: $error';
  }

  @override
  String get transactionDetailScreenTitle => 'Transaction';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get deleteTransactionConfirmTitle => 'Delete this transaction?';

  @override
  String get deleteTransactionConfirmMessage =>
      'It will no longer count toward any balance, budget, or total.';

  @override
  String get transactionDetailFromLabel => 'From';

  @override
  String get transactionDetailToLabel => 'To';

  @override
  String get transactionDetailNoteLabel => 'Note';

  @override
  String get appearanceSectionTitle => 'Appearance';

  @override
  String get themeCustomizationTitle => 'Theme Customization';

  @override
  String get themeCustomizationSubtitle => 'Make the app yours.';

  @override
  String get presetThemesSectionTitle => 'Preset themes';

  @override
  String get themeStyleLight => 'Light';

  @override
  String get themeStyleDark => 'Dark';

  @override
  String get themeStylePink => 'Pink';

  @override
  String get themeStyleOcean => 'Ocean';

  @override
  String get themeStyleForest => 'Forest';

  @override
  String get themeSelectedSemanticLabel => 'Selected';

  @override
  String get themeCustomizationPrivacyDisclaimer =>
      'All themes keep your data 100% secure and 100% local.';

  @override
  String get referenceRateSectionTitle => 'Reference Rate';

  @override
  String get referenceRateExplanation =>
      'An approximate market rate for reference only -- not guaranteed for an actual exchange or transfer.';

  @override
  String referenceRateEquation(String base, String rate, String quote) {
    return '1 $base = $rate $quote';
  }

  @override
  String get referenceRateSameCurrencyMessage =>
      'Your home and living currency are the same, so there\'s no reference rate to show.';

  @override
  String referenceRateSourceLabel(String source) {
    return 'Source: $source';
  }

  @override
  String referenceRateUpdatedLabel(String timestamp) {
    return 'Updated $timestamp';
  }

  @override
  String get referenceRateStaleIndicator =>
      'Showing the last rate we could fetch';

  @override
  String get referenceRateUnavailableMessage =>
      'Reference rate isn\'t available right now.';

  @override
  String get referenceRateRefreshTooltip => 'Refresh';

  @override
  String approxAmountLabel(String amount) {
    return '≈ $amount';
  }

  @override
  String approxAmountStaleLabel(String amount) {
    return '≈ $amount (cached)';
  }

  @override
  String get currencyConverterTitle => 'Currency Converter';

  @override
  String get currencyConverterFromLabel => 'From';

  @override
  String get currencyConverterToLabel => 'To';

  @override
  String get currencyConverterAmountLabel => 'Amount';

  @override
  String get currencyConverterSwapTooltip => 'Swap currencies';

  @override
  String get currencyConverterSameCurrencyMessage =>
      'From and To are the same currency, so the converted amount is exactly what you entered.';

  @override
  String get currencyConverterEnterAmountMessage =>
      'Enter an amount to convert.';

  @override
  String get amountTooLargeMessage =>
      'The converted amount is too large to display.';

  @override
  String get favoritePairsSectionTitle => 'Favorite pairs';

  @override
  String get favoritePairsSessionNote =>
      'Favorite pairs are remembered for this session only.';

  @override
  String get noFavoritePairsMessage => 'No favorite pairs yet.';

  @override
  String get addFavoritePairTooltip => 'Add favorite pair';

  @override
  String get removeFavoritePairTooltip => 'Remove favorite pair';

  @override
  String favoritePairsLimitReachedMessage(int limit) {
    return 'You can save up to $limit favorite pairs.';
  }

  @override
  String get cloudAccountSectionTitle => 'Cloud Account';

  @override
  String get cloudAccountStatusChipUnavailable => 'Unavailable';

  @override
  String get cloudAccountStatusChipLocalOnly => 'Local only';

  @override
  String get cloudAccountStatusChipSignedIn => 'Signed in';

  @override
  String get cloudAccountStatusChipSessionExpired => 'Session expired';

  @override
  String get cloudAccountUnavailableExplanation =>
      'Cloud accounts aren\'t available in this version yet. Everything you enter stays on this device.';

  @override
  String get cloudAccountLocalOnlyExplanation =>
      'You\'re not signed in. Your data stays on this device only.';

  @override
  String cloudAccountSignedInExplanation(String cloudUserId) {
    return 'Signed in with cloud account $cloudUserId. Syncing your financial data isn\'t available yet -- this only remembers who you\'re signed in as.';
  }

  @override
  String get cloudAccountSessionExpiredExplanation =>
      'Your cloud session expired. Sign in again to continue. Nothing stored on this device has been affected.';

  @override
  String get cloudAccountSignInButtonLabel => 'Sign in';

  @override
  String get cloudAccountSignOutButtonLabel => 'Sign out';

  @override
  String get cloudAccountSignOutNeverDeletesLocalDataNote =>
      'Signing out never deletes anything saved on this device.';

  @override
  String get cloudAccountDifferentAccountDialogTitle =>
      'Can\'t switch cloud accounts';

  @override
  String get cloudAccountDifferentAccountDialogMessage =>
      'This device is already linked to a different cloud account. Switching to a new cloud account on a device with existing local data isn\'t supported yet. Your local data has not been changed.';

  @override
  String get cloudAccountDialogDismissLabel => 'OK';

  @override
  String get addAccountTypeScreenTitle => 'Add account';

  @override
  String get addAccountTypeCashTitle => 'Cash';

  @override
  String get addAccountTypeCashDescription =>
      'Physical cash you keep on hand, like bills in your wallet.';

  @override
  String get addAccountTypeBankTitle => 'Bank account';

  @override
  String get addAccountTypeBankDescription =>
      'A checking or everyday account at a bank.';

  @override
  String get addAccountTypeSavingsTitle => 'Savings account';

  @override
  String get addAccountTypeSavingsDescription =>
      'A savings account you keep separate from everyday spending.';

  @override
  String get addAccountTypeWalletTitle => 'E-money / Wallet';

  @override
  String get addAccountTypeWalletDescription =>
      'A digital wallet or e-money balance, like a prepaid app balance.';

  @override
  String get addAccountTypeDepositTitle => 'Deposit';

  @override
  String get addAccountTypeDepositDescription =>
      'A fixed or recurring deposit that earns interest until maturity.';

  @override
  String get addAccountTypeCreditCardTitle => 'Credit card';

  @override
  String get addAccountTypeCreditCardDescription =>
      'A credit card balance you owe, with a credit limit.';

  @override
  String get addAccountAmountOwedLabel => 'Amount you currently owe';

  @override
  String get addAccountPrincipalLabel => 'Amount deposited';

  @override
  String get addAccountInstitutionLabel => 'Institution (optional)';

  @override
  String get addAccountInstitutionHint => 'e.g. Chase, HSBC';

  @override
  String get addAccountCreditLimitLabel => 'Credit limit';

  @override
  String get addAccountCardNetworkLabel => 'Card network (optional)';

  @override
  String get addAccountCardNetworkNone => 'Not specified';

  @override
  String get addAccountCardNetworkVisa => 'Visa';

  @override
  String get addAccountCardNetworkMastercard => 'Mastercard';

  @override
  String get addAccountCardNetworkJcb => 'JCB';

  @override
  String get addAccountCardNetworkAmex => 'American Express';

  @override
  String get addAccountCardNetworkOther => 'Other';

  @override
  String get addAccountLast4Label => 'Last 4 digits (optional)';

  @override
  String get addAccountLast4ErrorMessage => 'Enter exactly 4 digits.';

  @override
  String get addAccountExpiryMonthLabel => 'Expiry month (optional)';

  @override
  String get addAccountExpiryYearLabel => 'Expiry year (optional)';

  @override
  String get addAccountStatementClosingDayLabel =>
      'Statement closing day (optional)';

  @override
  String get addAccountDueDayLabel => 'Payment due day (optional)';

  @override
  String get addAccountDayOfMonthErrorMessage =>
      'Enter a day between 1 and 31.';

  @override
  String get addAccountDepositTypeLabel => 'Deposit type';

  @override
  String get addAccountDepositTypeFixed => 'Fixed';

  @override
  String get addAccountDepositTypeShortTerm => 'Short-term';

  @override
  String get addAccountDepositTypeRecurring => 'Recurring';

  @override
  String get addAccountDepositTypeOther => 'Other';

  @override
  String get addAccountStartDateLabel => 'Start date';

  @override
  String get addAccountChooseStartDateMessage => 'Choose a start date.';

  @override
  String get addAccountAnnualRateLabel => 'Annual interest rate (%)';

  @override
  String get addAccountInterestMethodLabel => 'Interest method';

  @override
  String get addAccountInterestMethodSimple => 'Simple';

  @override
  String get addAccountInterestMethodCompound => 'Compound';

  @override
  String get addAccountTermNumberLabel => 'Term length';

  @override
  String get addAccountTermNumberErrorMessage => 'Enter a term of at least 1.';

  @override
  String get addAccountTermUnitLabel => 'Term unit';

  @override
  String get addAccountTermUnitDays => 'Days';

  @override
  String get addAccountTermUnitMonths => 'Months';

  @override
  String get addAccountTermUnitYears => 'Years';

  @override
  String get addAccountCompoundingFrequencyLabel => 'Compounding frequency';

  @override
  String get addAccountCompoundingFrequencyMonthly => 'Monthly';

  @override
  String get addAccountCompoundingFrequencyQuarterly => 'Quarterly';

  @override
  String get addAccountCompoundingFrequencySemiannual => 'Semiannual';

  @override
  String get addAccountCompoundingFrequencyAnnual => 'Annual';

  @override
  String get addAccountCompoundingFrequencyAtMaturity => 'At maturity';

  @override
  String get addAccountChooseCompoundingFrequencyMessage =>
      'Choose a compounding frequency.';

  @override
  String get addAccountAutoRenewLabel => 'Renew automatically at maturity';

  @override
  String get addAccountInstallmentAmountLabel =>
      'Installment amount (optional)';

  @override
  String get addAccountInstallmentFrequencyLabel =>
      'Installment frequency (optional)';

  @override
  String get addAccountInstallmentFrequencyNone => 'Not specified';

  @override
  String get addAccountInstallmentFrequencyWeekly => 'Weekly';

  @override
  String get addAccountInstallmentFrequencyMonthly => 'Monthly';

  @override
  String get addAccountInstallmentFrequencyQuarterly => 'Quarterly';

  @override
  String get addAccountInstallmentFrequencyYearly => 'Yearly';

  @override
  String get addAccountInterestDestinationLabel =>
      'Send interest to (optional)';

  @override
  String get addAccountNoneOption => 'None';

  @override
  String get addAccountEstimatedInterestLabel => 'Estimated interest';

  @override
  String get addAccountEstimatedMaturityValueLabel =>
      'Estimated maturity value';

  @override
  String get addAccountEstimatedMaturityDateLabel => 'Estimated maturity date';

  @override
  String get addAccountEstimateDisclaimer =>
      'Estimate only -- not a guaranteed bank figure.';

  @override
  String get addAccountCreateButton => 'Create account';

  @override
  String addAccountCreationFailedMessage(String error) {
    return 'Could not create the account: $error';
  }

  @override
  String get addAccountExpiryMonthErrorMessage =>
      'Enter a month between 1 and 12.';

  @override
  String get netWorthTitle => 'Net Worth';

  @override
  String get netWorthScreenSubtitle =>
      'Everything you own, minus everything you owe. Shown separately per currency -- amounts are never converted or combined.';

  @override
  String get netWorthTotalLabel => 'Net worth';

  @override
  String get totalAssetsLabel => 'Total assets';

  @override
  String get totalLiabilitiesLabel => 'Total liabilities';

  @override
  String get assetsSectionTitle => 'Assets';

  @override
  String get liabilitiesSectionTitle => 'Liabilities';

  @override
  String get assetsDepositBadge => 'Deposit';

  @override
  String get netWorthEmptyMessage =>
      'No accounts yet. Add one to see your net worth here.';

  @override
  String couldNotLoadNetWorth(String error) {
    return 'Could not load your net worth: $error';
  }

  @override
  String get depositDetailsSectionTitle => 'Deposit details';

  @override
  String get depositInterestRateLabel => 'Interest rate';

  @override
  String get depositStartDateLabel => 'Start date';

  @override
  String get depositMaturityDateLabel => 'Maturity date';

  @override
  String get depositTermLabel => 'Term';

  @override
  String get depositStatusActive => 'Active';

  @override
  String get depositStatusMatured => 'Matured';

  @override
  String get depositTermUnitDay => 'day';

  @override
  String get depositTermUnitDays => 'days';

  @override
  String get depositTermUnitMonth => 'month';

  @override
  String get depositTermUnitMonths => 'months';

  @override
  String get depositTermUnitYear => 'year';

  @override
  String get depositTermUnitYears => 'years';

  @override
  String get chequesTitle => 'Cheques';

  @override
  String couldNotLoadCheques(String error) {
    return 'Could not load cheques: $error';
  }

  @override
  String get noChequesYetMessage => 'No cheques yet. Tap + to record one.';

  @override
  String get recordIssuedChequeTitle => 'Record issued cheque';

  @override
  String get recordReceivedChequeTitle => 'Record received cheque';

  @override
  String get chequeStatusPending => 'Pending';

  @override
  String get chequeStatusCleared => 'Cleared';

  @override
  String get chequeStatusBounced => 'Bounced';

  @override
  String get chequeStatusStopped => 'Stopped';

  @override
  String get chequeStatusCancelled => 'Cancelled';

  @override
  String get unknownAccountLabel => 'Unknown account';

  @override
  String get chequeNumberLabel => 'No.';

  @override
  String get chequeNumberFieldLabel => 'Cheque number';

  @override
  String get chequeBookLabelField => 'Chequebook';

  @override
  String get enterChequeBookLabelMessage =>
      'Enter a label for this chequebook.';

  @override
  String get startingChequeNumberOptionalField =>
      'Starting cheque number (optional)';

  @override
  String get newChequeBookDialogTitle => 'New chequebook';

  @override
  String get selectAccountMessage => 'Select an account.';

  @override
  String get selectChequeBookMessage => 'Select a chequebook.';

  @override
  String get enterChequeNumberMessage => 'Enter the cheque number.';

  @override
  String get payeeFieldLabel => 'Payee';

  @override
  String get payerFieldLabel => 'Payer / From';

  @override
  String get enterPayeeMessage => 'Enter the payee\'s name.';

  @override
  String get enterPayerMessage => 'Enter the payer\'s name.';

  @override
  String get issueDateLabel => 'Issue date';

  @override
  String get receivedDateLabel => 'Received date';

  @override
  String get clearedDateLabel => 'Cleared date';

  @override
  String get bouncedDateLabel => 'Bounced date';

  @override
  String get stoppedDateLabel => 'Stopped date';

  @override
  String get cancelledDateLabel => 'Cancelled date';

  @override
  String get memoOptionalFieldLabel => 'Memo (optional)';

  @override
  String get confirmButton => 'Confirm';

  @override
  String get markAsClearedButton => 'Mark as cleared';

  @override
  String get markAsBouncedButton => 'Mark as bounced';

  @override
  String get stopChequeButton => 'Stop cheque';

  @override
  String get cancelChequeButton => 'Cancel cheque';

  @override
  String get deleteChequeButton => 'Delete cheque';

  @override
  String get deleteChequeConfirmationMessage =>
      'Delete this cheque? This cannot be undone.';

  @override
  String get viewPostedTransactionButton => 'View posted transaction';

  @override
  String get chequeDetailTitle => 'Cheque';

  @override
  String get chequeNoLongerAvailableMessage =>
      'This cheque is no longer available.';

  @override
  String get creditFacilityDetailsSectionTitle => 'Credit details';

  @override
  String get availableCreditLabel => 'Available credit';

  @override
  String get creditUtilizationLabel => 'Credit utilization';

  @override
  String get editCreditLimitFieldLabel => 'Credit limit';
}

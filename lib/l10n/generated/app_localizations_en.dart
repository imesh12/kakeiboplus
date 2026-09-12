// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get addExpenseTitle => 'Add expense';

  @override
  String get addIncomeTitle => 'Add income';

  @override
  String get editExpenseTitle => 'Edit expense';

  @override
  String get editIncomeTitle => 'Edit income';

  @override
  String get editTransferTitle => 'Edit transfer';
}

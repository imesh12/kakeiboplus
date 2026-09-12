// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get internationalPreferences => '言語・地域設定';

  @override
  String get locationSection => '地域';

  @override
  String get currencySection => '通貨';

  @override
  String get languageAndFormatSection => '言語と表示形式';

  @override
  String get homeCountry => '母国';

  @override
  String get currentCountry => '現在の国';

  @override
  String get homeCurrency => '基準通貨';

  @override
  String get livingCurrency => '生活通貨';

  @override
  String get language => '言語';

  @override
  String get dateFormat => '日付形式';

  @override
  String get numberFormat => '数値形式';

  @override
  String get timezone => 'タイムゾーン';

  @override
  String get save => '保存';

  @override
  String get navHome => 'ホーム';

  @override
  String get navActivity => 'アクティビティ';

  @override
  String get navAdd => '追加';

  @override
  String get navProfile => 'プロフィール';

  @override
  String get transactionTypeExpense => '支出';

  @override
  String get transactionTypeIncome => '収入';

  @override
  String get transactionTypeTransfer => '振替';

  @override
  String get amountLabel => '金額';

  @override
  String get accountLabel => '口座';

  @override
  String get fromAccountLabel => '振替元口座';

  @override
  String get toAccountLabel => '振替先口座';

  @override
  String get categoryOptionalLabel => 'カテゴリ（任意）';

  @override
  String get noteOptionalLabel => 'メモ（任意）';

  @override
  String get dateLabel => '日付';

  @override
  String get addAccountFirstMessage => '取引を記録する前に、まず口座を追加してください（プロフィール → 口座）。';

  @override
  String couldNotLoadAccounts(String error) {
    return '口座を読み込めませんでした: $error';
  }

  @override
  String couldNotLoadCategories(String error) {
    return 'カテゴリを読み込めませんでした: $error';
  }

  @override
  String couldNotSaveTransaction(String error) {
    return '保存できませんでした: $error';
  }

  @override
  String get enterValidAmount => '有効な金額を入力してください。';

  @override
  String get chooseDestinationAccount => '振替先口座を選択してください。';

  @override
  String noEligibleTransferDestination(String currency) {
    return '他に振替可能な$currency口座がありません。異なる通貨間の振替は現在のバージョンでは対応していません。';
  }

  @override
  String currencyMismatchError(String fromCurrency, String toCurrency) {
    return 'この金額の通貨が選択した口座と一致しません（$fromCurrency → $toCurrency）。';
  }

  @override
  String get transactionNoLongerAvailable => 'この取引は利用できません。他の場所で削除された可能性があります。';

  @override
  String get addExpenseTitle => '支出を追加';

  @override
  String get addIncomeTitle => '収入を追加';

  @override
  String get editExpenseTitle => '支出を編集';

  @override
  String get editIncomeTitle => '収入を編集';

  @override
  String get editTransferTitle => '振替を編集';
}

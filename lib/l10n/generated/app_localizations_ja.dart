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
}

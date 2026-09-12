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

  @override
  String homeGreeting(String name) {
    return '$nameさん、こんにちは';
  }

  @override
  String get accountsSectionTitle => '口座';

  @override
  String get manage => '管理';

  @override
  String couldNotLoadBalances(String error) {
    return '残高を読み込めませんでした: $error';
  }

  @override
  String get addAccountToSeeBalance => '口座を追加すると、残高・収入・支出がここに表示されます。';

  @override
  String get noAccountsYetMessage => '口座がまだありません。追加して記録を始めましょう。';

  @override
  String somethingWentWrong(String error) {
    return '問題が発生しました: $error';
  }

  @override
  String get totalAvailableBalance => '利用可能残高の合計';

  @override
  String get incomeThisMonth => '今月の収入';

  @override
  String get spentThisMonth => '今月の支出';

  @override
  String get dailySpendingPace => '1日あたりの支出ペース';

  @override
  String get dailySpendingPaceDetail => '今月これまでの1日あたりの平均支出';

  @override
  String get remainingMonthlyBudget => '今月の残り予算';

  @override
  String get noBudgetSetMessage => 'まだ今月の予算を設定していません。設定すると、使える残り金額がここに表示されます。';

  @override
  String get setMonthlyBudgetButton => '今月の予算を設定';

  @override
  String get budgetStatusOnTrack => '順調';

  @override
  String get budgetStatusAheadOfPace => 'ペースより早い';

  @override
  String get budgetStatusOverBudget => '予算超過';

  @override
  String get budgetStatusThisMonth => '今月';

  @override
  String ofAmount(String amount) {
    return '$amountのうち';
  }

  @override
  String percentUsedLabel(String percent) {
    return '$percent%使用';
  }

  @override
  String recommendedDailySpend(String amount) {
    return 'おすすめ: 今月の残り期間は1日$amount';
  }

  @override
  String get savingsGoalsTitle => '貯蓄目標';

  @override
  String get viewAll => 'すべて表示';

  @override
  String get noSavingsGoalMessage => 'まだ貯蓄目標を設定していません。';

  @override
  String get setSavingsGoalButton => '貯蓄目標を設定';

  @override
  String get allGoalsCompletedMessage => 'すべての貯蓄目標を達成しました。';

  @override
  String get overdueLabel => '期限超過';

  @override
  String get goalStatusInProgress => '進行中';

  @override
  String get goalStatusCompleted => '達成';

  @override
  String get recurringTitle => '定期';

  @override
  String get noRecurringMessage => '定期的な支払いや収入がまだ設定されていません。';

  @override
  String get setUpRecurringButton => '定期を設定';

  @override
  String get recurringStatusDueToday => '今日が期限';

  @override
  String get recurringStatusUpcoming => '今後の予定';

  @override
  String couldNotLoadTransactions(String error) {
    return '取引を読み込めませんでした: $error';
  }

  @override
  String get noTransactionsYetMessage => 'まだ取引がありません。「追加」をタップして記録しましょう。';

  @override
  String get searchTransactionsLabel => '取引を検索';

  @override
  String get searchTransactionsHint => 'カテゴリ・口座・メモ・金額で検索';

  @override
  String get clearSearchTooltip => '検索をクリア';

  @override
  String get clearFilters => 'フィルターをクリア';

  @override
  String get noMatchingTransactions => '一致する取引がありません';

  @override
  String get dateGroupToday => '今日';

  @override
  String get dateGroupYesterday => '昨日';

  @override
  String dateGroupSemanticLabel(String group) {
    return '$groupの取引';
  }

  @override
  String spokenPlusAmount(String amount) {
    return 'プラス$amount';
  }

  @override
  String spokenMinusAmount(String amount) {
    return 'マイナス$amount';
  }

  @override
  String get noAccountsYetTapToAddMessage => '口座がまだありません。+ をタップして追加してください。';

  @override
  String get accountTypeCash => '現金';

  @override
  String get accountTypeBank => '銀行';

  @override
  String get accountTypeCard => 'カード';

  @override
  String get accountTypeWallet => 'ウォレット';

  @override
  String get addAccountDialogTitle => '口座を追加';

  @override
  String get accountNameLabel => '名前';

  @override
  String get enterAccountNameMessage => '名前を入力してください。';

  @override
  String get accountTypeLabel => '種類';

  @override
  String get cancel => 'キャンセル';

  @override
  String get addAccountButton => '追加';

  @override
  String budgetsScreenTitle(String month) {
    return '予算 · $month';
  }

  @override
  String couldNotLoadBudgets(String error) {
    return '予算を読み込めませんでした: $error';
  }

  @override
  String get noBudgetsSetThisMonthMessage =>
      '今月の予算はまだ設定されていません。+ をタップして全体予算またはカテゴリ予算を設定してください。';

  @override
  String get overallBudgetsSectionTitle => '全体予算';

  @override
  String get categoryBudgetsSectionTitle => 'カテゴリ予算';

  @override
  String get overallMonthlyBudgetOption => '毎月の全体予算';

  @override
  String get categoryBudgetOption => 'カテゴリ予算';

  @override
  String get editOverallBudgetTitle => '毎月の全体予算を編集';

  @override
  String get setOverallBudgetTitle => '毎月の全体予算を設定';

  @override
  String get monthlyBudgetAmountLabel => '毎月の予算額';

  @override
  String get editCategoryBudgetTitle => 'カテゴリ予算を編集';

  @override
  String get setCategoryBudgetTitle => 'カテゴリ予算を設定';

  @override
  String get categoryFieldLabel => 'カテゴリ';

  @override
  String get chooseCategoryMessage => 'カテゴリを選択してください。';

  @override
  String get categoryBudgetAmountLabel => 'カテゴリ予算額';

  @override
  String get editTooltip => '編集';

  @override
  String get removeTooltip => '削除';

  @override
  String couldNotLoadGoals(String error) {
    return '目標を読み込めませんでした: $error';
  }

  @override
  String get noSavingsGoalsYetTapMessage => '貯蓄目標がまだありません。+ をタップして設定してください。';

  @override
  String get newSavingsGoalDialogTitle => '新しい貯蓄目標';

  @override
  String get goalNameLabel => '目標名';

  @override
  String get enterGoalNameMessage => 'この目標の名前を入力してください。';

  @override
  String get targetAmountLabel => '目標金額';

  @override
  String get noTargetDateMessage => '目標日なし';

  @override
  String get targetDateLabel => '目標日';

  @override
  String get chooseButton => '選択';

  @override
  String get clearTargetDateTooltip => '目標日をクリア';

  @override
  String get goalFallbackTitle => '目標';

  @override
  String get editGoalAction => '目標を編集';

  @override
  String get deleteGoalTooltip => '目標を削除';

  @override
  String couldNotLoadGoalDetail(String error) {
    return 'この目標を読み込めませんでした: $error';
  }

  @override
  String get goalNoLongerAvailableMessage => 'この目標は利用できません。';

  @override
  String get deleteGoalConfirmTitle => 'この目標を削除しますか?';

  @override
  String get deleteGoalConfirmMessage => '積立履歴は保持されますが、目標自体は有効ではなくなります。';

  @override
  String get deleteButton => '削除';

  @override
  String get remainingLabel => '残り';

  @override
  String get recommendedDailyContributionLabel => '推奨される1日あたりの積立額';

  @override
  String get contributionHistoryTitle => '積立履歴';

  @override
  String couldNotLoadContributionHistory(String error) {
    return '積立履歴を読み込めませんでした: $error';
  }

  @override
  String get noContributionsYetMessage => '積立はまだありません。';

  @override
  String get addContributionDialogTitle => '積立を追加';

  @override
  String get addContributionButton => '追加';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get brandName => 'KakeiboPlus';

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
  String get navAccounts => '口座';

  @override
  String get navMore => 'その他';

  @override
  String get moreScreenSubtitle => 'お金の管理ツールと設定';

  @override
  String get morePlanningSectionTitle => 'プランニング';

  @override
  String get moreMoneyToolsSectionTitle => 'マネーツール';

  @override
  String get moreOrganizationSectionTitle => '整理';

  @override
  String get morePersonalizationSectionTitle => '個人設定';

  @override
  String get moreCloudSecuritySectionTitle => 'クラウドとセキュリティ';

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
  String get transactionLinkedToChequeError =>
      'この取引は決済済みの小切手によって作成されたため、直接編集または削除できません。';

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
  String get accountFallbackTitle => '口座';

  @override
  String get accountNoLongerAvailableMessage => 'この口座は利用できません。';

  @override
  String couldNotLoadAccountDetail(String error) {
    return 'この口座を読み込めませんでした: $error';
  }

  @override
  String get accountOpeningBalanceLabel => '開始時の残高';

  @override
  String get accountCreatedLabel => '作成日';

  @override
  String get accountBalanceLabel => '残高';

  @override
  String get accountInstitutionLabel => '金融機関';

  @override
  String get accountRecentActivityTitle => '最近の履歴';

  @override
  String get accountNoRecentActivityMessage => 'この口座の履歴はまだありません。';

  @override
  String get editAccountTitle => '口座を編集';

  @override
  String get accountCurrencyLockedMessage => '口座を作成した後は通貨を変更できません。';

  @override
  String get closeAccountAction => '口座を閉じる';

  @override
  String get closeCreditCardAction => 'カードを停止する';

  @override
  String get reactivateAccountAction => '口座を再開する';

  @override
  String get closeAccountConfirmTitle => 'この口座を閉じますか？';

  @override
  String get closeAccountConfirmMessage =>
      '取引履歴はそのまま保持されます。再開するまで、新しい取引には使用できなくなります。';

  @override
  String get closeCreditCardConfirmTitle => 'このカードを停止しますか？';

  @override
  String get closeCreditCardConfirmMessage =>
      '取引履歴はそのまま保持されます。再開するまで、新しい支払いや返済には使用できなくなります。';

  @override
  String get reactivateAccountConfirmTitle => 'この口座を再開しますか？';

  @override
  String get reactivateAccountConfirmMessage =>
      '既存の履歴や残高はそのまま、新しい取引に再び使用できるようになります。';

  @override
  String get accountClosedLabel => '閉鎖済み';

  @override
  String get closedAccountsSectionHeader => '閉鎖済みの口座';

  @override
  String get accountHasActiveRecurringRulesMessage =>
      'この口座はまだ1件以上の定期ルールで使用されています。先にそれらを変更または削除してから、もう一度お試しください。';

  @override
  String couldNotCloseAccountMessage(String error) {
    return 'この口座を閉じられませんでした: $error';
  }

  @override
  String couldNotReactivateAccountMessage(String error) {
    return 'この口座を再開できませんでした: $error';
  }

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
  String get deleteGoalConfirmTitle => 'この目標を削除しますか？';

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

  @override
  String couldNotLoadRecurringRules(String error) {
    return '定期ルールを読み込めませんでした: $error';
  }

  @override
  String get noRecurringRulesYetTapMessage => '定期ルールがまだありません。+ をタップして追加してください。';

  @override
  String get subscriptionsTitle => 'サブスクリプション';

  @override
  String get subscriptionsEstimatedMonthlyTotalLabel => '推定月額';

  @override
  String get subscriptionsEstimatedYearlyTotalLabel => '推定年額';

  @override
  String get noActiveSubscriptionsMessage => '有効なサブスクリプションはまだありません。';

  @override
  String get deleteRecurringRuleConfirmTitle => 'この定期ルールを削除しますか？';

  @override
  String get deleteRecurringRuleConfirmMessage =>
      '記録済みの取引と処理済みの発生履歴は保持されますが、ルール自体は非アクティブになります。';

  @override
  String get deleteRuleTooltip => '削除';

  @override
  String get skipButton => 'スキップ';

  @override
  String get postButton => '記録';

  @override
  String get editRecurringRuleTitle => '定期ルールを編集';

  @override
  String get newRecurringRuleTitle => '新しい定期ルール';

  @override
  String get recurringKindFieldLabel => '種類';

  @override
  String get recurringRuleNameLabel => '名前';

  @override
  String get enterRecurringRuleNameMessage => 'このルールの名前を入力してください。';

  @override
  String get sourceAccountLabel => '元の口座';

  @override
  String get destinationAccountLabel => '送金先の口座';

  @override
  String get noSameCurrencyDestinationMessage => '同じ通貨の送金先口座がありません。';

  @override
  String get noneOptionLabel => 'なし';

  @override
  String get frequencyLabel => '頻度';

  @override
  String get recurrenceFrequencyDaily => '毎日';

  @override
  String get recurrenceFrequencyWeekly => '毎週';

  @override
  String get recurrenceFrequencyMonthly => '毎月';

  @override
  String get recurrenceFrequencyYearly => '毎年';

  @override
  String get intervalLabel => '間隔（N回ごと）';

  @override
  String get enterWholeNumberMessage => '1以上の整数を入力してください。';

  @override
  String get remindMeLabel => 'リマインドする';

  @override
  String get remindMeSubtitle => '期日になるとローカル通知が届きます。自動的に記録されることはありません。';

  @override
  String get notificationsPermissionDeniedMessage =>
      '通知の許可が得られなかったため、リマインダーはオフのままです。';

  @override
  String get chooseStartDateMessage => '開始日を選択';

  @override
  String get startDateLabel => '開始日';

  @override
  String get noEndDateMessage => '終了日なし';

  @override
  String get endDateLabel => '終了日';

  @override
  String get clearEndDateTooltip => '終了日をクリア';

  @override
  String get chooseAccountMessage => '口座を選択してください。';

  @override
  String transfersCrossCurrencyNotSupportedMessage(
      String fromCurrency, String toCurrency) {
    return '異なる通貨間の振替はまだサポートされていません（$fromCurrency → $toCurrency）。';
  }

  @override
  String get categoriesScreenTitle => 'カテゴリ';

  @override
  String get noCategoriesYetMessage => 'カテゴリがまだありません。';

  @override
  String get systemCategoryIndicatorLabel => 'システム';

  @override
  String get addExpenseCategoryDialogTitle => '支出カテゴリを追加';

  @override
  String get addIncomeCategoryDialogTitle => '収入カテゴリを追加';

  @override
  String get categoryNameLabel => '名前';

  @override
  String get addCategoryButton => '追加';

  @override
  String profileLocationSummary(String currentCountry, String livingCurrency,
      String homeCountry, String homeCurrency) {
    return '現在の国: $currentCountry（$livingCurrency）・母国: $homeCountry（$homeCurrency）';
  }

  @override
  String couldNotLoadProfile(String error) {
    return 'プロフィールを読み込めませんでした: $error';
  }

  @override
  String get budgetsTitle => '予算';

  @override
  String get beta0DisclaimerMessage =>
      '複数通貨の管理、参考為替レート、繰り返しのリマインダーは今すぐご利用いただけます。レシート読み取り、クラウド同期、AIコーチングは今後のアップデートで追加予定です。';

  @override
  String get homeQuickGlanceNotSet => '未設定';

  @override
  String get homeGoalsQuickGlanceLabel => '目標';

  @override
  String couldNotSavePreferencesMessage(String error) {
    return '保存できませんでした: $error';
  }

  @override
  String get editTransactionGenericTitle => '取引を編集';

  @override
  String couldNotLoadTransactionDetail(String error) {
    return 'この取引を読み込めませんでした: $error';
  }

  @override
  String get transactionDetailScreenTitle => '取引';

  @override
  String get deleteTooltip => '削除';

  @override
  String get deleteTransactionConfirmTitle => 'この取引を削除しますか？';

  @override
  String get deleteTransactionConfirmMessage => '残高・予算・合計のいずれにも反映されなくなります。';

  @override
  String get transactionDetailFromLabel => '振替元';

  @override
  String get transactionDetailToLabel => '振替先';

  @override
  String get transactionDetailNoteLabel => 'メモ';

  @override
  String get appearanceSectionTitle => '外観';

  @override
  String get themeCustomizationTitle => 'テーマのカスタマイズ';

  @override
  String get themeCustomizationSubtitle => '自分好みにカスタマイズしましょう。';

  @override
  String get presetThemesSectionTitle => 'プリセットテーマ';

  @override
  String get themeStyleLight => 'ライト';

  @override
  String get themeStyleDark => 'ダーク';

  @override
  String get themeStylePink => 'ピンク';

  @override
  String get themeStyleOcean => 'オーシャン';

  @override
  String get themeStyleForest => 'フォレスト';

  @override
  String get themeSelectedSemanticLabel => '選択中';

  @override
  String get themeCustomizationPrivacyDisclaimer =>
      'すべてのテーマで、データは100%安全かつローカルに保存されます。';

  @override
  String get referenceRateSectionTitle => '参考レート';

  @override
  String get referenceRateExplanation =>
      'あくまで参考用の概算レートです。実際の両替や送金のレートを保証するものではありません。';

  @override
  String referenceRateEquation(String base, String rate, String quote) {
    return '1 $base = $rate $quote';
  }

  @override
  String get referenceRateSameCurrencyMessage =>
      '基準通貨と生活通貨が同じため、参考レートは表示されません。';

  @override
  String referenceRateSourceLabel(String source) {
    return '提供元: $source';
  }

  @override
  String referenceRateUpdatedLabel(String timestamp) {
    return '更新: $timestamp';
  }

  @override
  String get referenceRateStaleIndicator =>
      '最新の情報を取得できなかったため、前回取得したレートを表示しています';

  @override
  String get referenceRateUnavailableMessage => '現在、参考レートを取得できません。';

  @override
  String get referenceRateRefreshTooltip => '更新';

  @override
  String approxAmountLabel(String amount) {
    return '≈ $amount';
  }

  @override
  String approxAmountStaleLabel(String amount) {
    return '≈ $amount（キャッシュ）';
  }

  @override
  String get currencyConverterTitle => '通貨換算';

  @override
  String get currencyConverterFromLabel => '変換元';

  @override
  String get currencyConverterToLabel => '変換先';

  @override
  String get currencyConverterAmountLabel => '金額';

  @override
  String get currencyConverterSwapTooltip => '通貨を入れ替え';

  @override
  String get currencyConverterSameCurrencyMessage =>
      '変換元と変換先が同じ通貨のため、入力した金額がそのまま換算結果になります。';

  @override
  String get currencyConverterEnterAmountMessage => '金額を入力してください。';

  @override
  String get amountTooLargeMessage => '換算結果が大きすぎて表示できません。';

  @override
  String get favoritePairsSectionTitle => 'お気に入りの通貨ペア';

  @override
  String get favoritePairsSessionNote => 'お気に入りの通貨ペアはこのセッション中のみ保持されます。';

  @override
  String get noFavoritePairsMessage => 'お気に入りの通貨ペアはまだありません。';

  @override
  String get addFavoritePairTooltip => 'お気に入りに追加';

  @override
  String get removeFavoritePairTooltip => 'お気に入りから削除';

  @override
  String favoritePairsLimitReachedMessage(int limit) {
    return 'お気に入りの通貨ペアは最大$limit件まで保存できます。';
  }

  @override
  String get cloudAccountSectionTitle => 'クラウドアカウント';

  @override
  String get cloudAccountStatusChipUnavailable => '利用不可';

  @override
  String get cloudAccountStatusChipLocalOnly => 'ローカルのみ';

  @override
  String get cloudAccountStatusChipSignedIn => 'サインイン済み';

  @override
  String get cloudAccountStatusChipSessionExpired => 'セッション期限切れ';

  @override
  String get cloudAccountUnavailableExplanation =>
      'このバージョンではクラウドアカウントはまだ利用できません。入力したデータはすべてこの端末内に保存されます。';

  @override
  String get cloudAccountLocalOnlyExplanation =>
      'サインインしていません。データはこの端末にのみ保存されます。';

  @override
  String cloudAccountSignedInExplanation(String cloudUserId) {
    return 'クラウドアカウント $cloudUserId でサインイン中です。財務データの同期はまだ利用できません -- これはサインイン状態を記憶するだけです。';
  }

  @override
  String get cloudAccountSessionExpiredExplanation =>
      'クラウドのセッションが期限切れになりました。続けるには再度サインインしてください。この端末に保存されているデータには影響ありません。';

  @override
  String get cloudAccountSignInButtonLabel => 'サインイン';

  @override
  String get cloudAccountSignOutButtonLabel => 'サインアウト';

  @override
  String get cloudAccountSignOutNeverDeletesLocalDataNote =>
      'サインアウトしても、この端末に保存されたデータが削除されることはありません。';

  @override
  String get cloudAccountDifferentAccountDialogTitle => 'クラウドアカウントを切り替えられません';

  @override
  String get cloudAccountDifferentAccountDialogMessage =>
      'この端末は既に別のクラウドアカウントに関連付けられています。既存のローカルデータがある端末で別のクラウドアカウントに切り替えることは、現在のバージョンではサポートされていません。ローカルデータは変更されていません。';

  @override
  String get cloudAccountDialogDismissLabel => 'OK';

  @override
  String get addAccountTypeScreenTitle => '口座を追加';

  @override
  String get addAccountTypeCashTitle => '現金';

  @override
  String get addAccountTypeCashDescription => 'お財布の中の紙幣など、手元で管理する現金です。';

  @override
  String get addAccountTypeBankTitle => '銀行口座';

  @override
  String get addAccountTypeBankDescription => '普通預金など、日常使いの銀行口座です。';

  @override
  String get addAccountTypeSavingsTitle => '貯蓄口座';

  @override
  String get addAccountTypeSavingsDescription => '日常の支払いとは別に管理する貯蓄用の口座です。';

  @override
  String get addAccountTypeWalletTitle => '電子マネー / ウォレット';

  @override
  String get addAccountTypeWalletDescription =>
      'プリペイド式アプリの残高など、デジタルウォレットや電子マネーの残高です。';

  @override
  String get addAccountTypeDepositTitle => '定期預金';

  @override
  String get addAccountTypeDepositDescription => '満期まで利息がつく、定期または積立の預金です。';

  @override
  String get addAccountTypeCreditCardTitle => 'クレジットカード';

  @override
  String get addAccountTypeCreditCardDescription =>
      '利用限度額のある、支払い義務が生じるクレジットカードの残高です。';

  @override
  String get addAccountAmountOwedLabel => '現在の未払い残高';

  @override
  String get addAccountPrincipalLabel => '預入金額';

  @override
  String get addAccountInstitutionLabel => '金融機関 (任意)';

  @override
  String get addAccountInstitutionHint => '例: 三菱UFJ銀行、みずほ銀行';

  @override
  String get addAccountCreditLimitLabel => '利用限度額';

  @override
  String get addAccountCardNetworkLabel => 'カードブランド (任意)';

  @override
  String get addAccountCardNetworkNone => '指定なし';

  @override
  String get addAccountCardNetworkVisa => 'Visa';

  @override
  String get addAccountCardNetworkMastercard => 'Mastercard';

  @override
  String get addAccountCardNetworkJcb => 'JCB';

  @override
  String get addAccountCardNetworkAmex => 'American Express';

  @override
  String get addAccountCardNetworkOther => 'その他';

  @override
  String get addAccountLast4Label => '末尾4桁 (任意)';

  @override
  String get addAccountLast4ErrorMessage => '4桁の数字を入力してください。';

  @override
  String get addAccountExpiryMonthLabel => '有効期限の月 (任意)';

  @override
  String get addAccountExpiryYearLabel => '有効期限の年 (任意)';

  @override
  String get addAccountStatementClosingDayLabel => '締め日 (任意)';

  @override
  String get addAccountDueDayLabel => '支払期日 (任意)';

  @override
  String get addAccountDayOfMonthErrorMessage => '1から31の間の日を入力してください。';

  @override
  String get addAccountDepositTypeLabel => '預金の種類';

  @override
  String get addAccountDepositTypeFixed => '固定期間';

  @override
  String get addAccountDepositTypeShortTerm => '短期';

  @override
  String get addAccountDepositTypeRecurring => '積立';

  @override
  String get addAccountDepositTypeOther => 'その他';

  @override
  String get addAccountStartDateLabel => '開始日';

  @override
  String get addAccountChooseStartDateMessage => '開始日を選択してください。';

  @override
  String get addAccountAnnualRateLabel => '年利 (%)';

  @override
  String get addAccountInterestMethodLabel => '利息の計算方法';

  @override
  String get addAccountInterestMethodSimple => '単利';

  @override
  String get addAccountInterestMethodCompound => '複利';

  @override
  String get addAccountTermNumberLabel => '預入期間';

  @override
  String get addAccountTermNumberErrorMessage => '1以上の期間を入力してください。';

  @override
  String get addAccountTermUnitLabel => '期間の単位';

  @override
  String get addAccountTermUnitDays => '日';

  @override
  String get addAccountTermUnitMonths => 'ヶ月';

  @override
  String get addAccountTermUnitYears => '年';

  @override
  String get addAccountCompoundingFrequencyLabel => '複利計算の頻度';

  @override
  String get addAccountCompoundingFrequencyMonthly => '毎月';

  @override
  String get addAccountCompoundingFrequencyQuarterly => '四半期ごと';

  @override
  String get addAccountCompoundingFrequencySemiannual => '半年ごと';

  @override
  String get addAccountCompoundingFrequencyAnnual => '毎年';

  @override
  String get addAccountCompoundingFrequencyAtMaturity => '満期時';

  @override
  String get addAccountChooseCompoundingFrequencyMessage => '複利計算の頻度を選択してください。';

  @override
  String get addAccountAutoRenewLabel => '満期時に自動更新する';

  @override
  String get addAccountInstallmentAmountLabel => '積立金額 (任意)';

  @override
  String get addAccountInstallmentFrequencyLabel => '積立の頻度 (任意)';

  @override
  String get addAccountInstallmentFrequencyNone => '指定なし';

  @override
  String get addAccountInstallmentFrequencyWeekly => '毎週';

  @override
  String get addAccountInstallmentFrequencyMonthly => '毎月';

  @override
  String get addAccountInstallmentFrequencyQuarterly => '四半期ごと';

  @override
  String get addAccountInstallmentFrequencyYearly => '毎年';

  @override
  String get addAccountInterestDestinationLabel => '利息の受取先 (任意)';

  @override
  String get addAccountNoneOption => 'なし';

  @override
  String get addAccountEstimatedInterestLabel => '予想利息';

  @override
  String get addAccountEstimatedMaturityValueLabel => '満期時の予想金額';

  @override
  String get addAccountEstimatedMaturityDateLabel => '予想満期日';

  @override
  String get addAccountEstimateDisclaimer => 'これは目安です -- 銀行が保証する金額ではありません。';

  @override
  String get addAccountCreateButton => '口座を作成';

  @override
  String addAccountCreationFailedMessage(String error) {
    return '口座を作成できませんでした: $error';
  }

  @override
  String get addAccountExpiryMonthErrorMessage => '1から12の間の月を入力してください。';

  @override
  String get netWorthTitle => '純資産';

  @override
  String get netWorthScreenSubtitle =>
      '所有するすべての資産から負債を引いた金額です。通貨ごとに別々に表示され、換算や合算は行いません。';

  @override
  String get netWorthTotalLabel => '純資産';

  @override
  String get totalAssetsLabel => '資産合計';

  @override
  String get totalLiabilitiesLabel => '負債合計';

  @override
  String get assetsSectionTitle => '資産';

  @override
  String get liabilitiesSectionTitle => '負債';

  @override
  String get assetsDepositBadge => '預金';

  @override
  String get netWorthEmptyMessage => '口座がまだありません。口座を追加すると純資産が表示されます。';

  @override
  String couldNotLoadNetWorth(String error) {
    return '純資産を読み込めませんでした: $error';
  }

  @override
  String get depositDetailsSectionTitle => '預金の詳細';

  @override
  String get depositInterestRateLabel => '金利';

  @override
  String get depositStartDateLabel => '開始日';

  @override
  String get depositMaturityDateLabel => '満期日';

  @override
  String get depositTermLabel => '期間';

  @override
  String get depositStatusActive => '運用中';

  @override
  String get depositStatusMatured => '満期';

  @override
  String get depositTermUnitDay => '日';

  @override
  String get depositTermUnitDays => '日';

  @override
  String get depositTermUnitMonth => 'か月';

  @override
  String get depositTermUnitMonths => 'か月';

  @override
  String get depositTermUnitYear => '年';

  @override
  String get depositTermUnitYears => '年';

  @override
  String get chequesTitle => '小切手';

  @override
  String couldNotLoadCheques(String error) {
    return '小切手を読み込めませんでした: $error';
  }

  @override
  String get noChequesYetMessage => '小切手はまだありません。+をタップして記録してください。';

  @override
  String get recordIssuedChequeTitle => '振り出した小切手を記録';

  @override
  String get recordReceivedChequeTitle => '受け取った小切手を記録';

  @override
  String get chequeStatusPending => '保留中';

  @override
  String get chequeStatusCleared => '決済済み';

  @override
  String get chequeStatusBounced => '不渡り';

  @override
  String get chequeStatusStopped => '支払停止';

  @override
  String get chequeStatusCancelled => '取消済み';

  @override
  String get unknownAccountLabel => '不明なアカウント';

  @override
  String get chequeNumberLabel => '番号';

  @override
  String get chequeNumberFieldLabel => '小切手番号';

  @override
  String get chequeBookLabelField => '小切手帳';

  @override
  String get enterChequeBookLabelMessage => 'この小切手帳のラベルを入力してください。';

  @override
  String get startingChequeNumberOptionalField => '開始小切手番号(任意)';

  @override
  String get newChequeBookDialogTitle => '新しい小切手帳';

  @override
  String get selectAccountMessage => 'アカウントを選択してください。';

  @override
  String get selectChequeBookMessage => '小切手帳を選択してください。';

  @override
  String get enterChequeNumberMessage => '小切手番号を入力してください。';

  @override
  String get payeeFieldLabel => '受取人';

  @override
  String get payerFieldLabel => '支払人/差出人';

  @override
  String get enterPayeeMessage => '受取人名を入力してください。';

  @override
  String get enterPayerMessage => '支払人名を入力してください。';

  @override
  String get issueDateLabel => '発行日';

  @override
  String get receivedDateLabel => '受取日';

  @override
  String get clearedDateLabel => '決済日';

  @override
  String get bouncedDateLabel => '不渡り日';

  @override
  String get stoppedDateLabel => '支払停止日';

  @override
  String get cancelledDateLabel => '取消日';

  @override
  String get memoOptionalFieldLabel => 'メモ(任意)';

  @override
  String get confirmButton => '確認';

  @override
  String get markAsClearedButton => '決済済みにする';

  @override
  String get markAsBouncedButton => '不渡りにする';

  @override
  String get stopChequeButton => '小切手の支払いを停止';

  @override
  String get cancelChequeButton => '小切手を取り消す';

  @override
  String get deleteChequeButton => '小切手を削除';

  @override
  String get deleteChequeConfirmationMessage => 'この小切手を削除しますか?この操作は元に戻せません。';

  @override
  String get viewPostedTransactionButton => '記帳された取引を表示';

  @override
  String get chequeDetailTitle => '小切手';

  @override
  String get chequeNoLongerAvailableMessage => 'この小切手は利用できません。';
}

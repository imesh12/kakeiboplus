import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../../core/database/services/account_creation_service.dart';
import '../../../core/finance/account_creation_kind.dart';
import '../../../core/finance/calendar_month_math.dart';
import '../../../core/finance/card_network.dart';
import '../../../core/finance/deposit_calculator.dart';
import '../../../core/finance/deposit_compounding_frequency.dart';
import '../../../core/finance/deposit_installment_frequency.dart';
import '../../../core/finance/deposit_interest_method.dart';
import '../../../core/finance/deposit_term_unit.dart';
import '../../../core/finance/deposit_type.dart';
import '../../../core/finance/interest_rate_input.dart';
import '../../../core/money/currency_mismatch_exception.dart';
import '../../../core/money/money.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/money_text_field.dart';
import 'account_creation_kind_presentation.dart';
import 'account_providers.dart';

/// Checkpoint G (Add Account UX, docs/20 §13.4): the second, adaptive
/// step of the new Add Account flow -- the common fields every
/// [AccountCreationKind] needs, plus [AccountCreationKind.creditCard]'s
/// and [AccountCreationKind.deposit]'s own extra fields, shown only for
/// their own kind. Submits through [AccountCreationService] (never
/// duplicating any repository's own validation -- every field here maps
/// straight to a parameter that repository/service layer already
/// validates); a failure leaves nothing partially created, because
/// [AccountCreationService.createCreditCardAccount]/
/// [AccountCreationService.createDepositAccount] each wrap their whole
/// sequence in one `AppDatabase.transaction`.
///
/// **Never collects a full card number, CVV, PIN, or banking password**
/// -- the checkpoint's own explicit prohibition. Only `last4` (exactly 4
/// digits) and descriptive metadata (network, expiry, statement/due day)
/// are ever asked for a credit card.
class AddAccountFormScreen extends ConsumerStatefulWidget {
  const AddAccountFormScreen({required this.kind, super.key});

  final AccountCreationKind kind;

  @override
  ConsumerState<AddAccountFormScreen> createState() => _AddAccountFormScreenState();
}

class _AddAccountFormScreenState extends ConsumerState<AddAccountFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _institutionController = TextEditingController();
  String _currencyCode = CurrencyRegistry.seed.first.code;
  Money? _amount;
  bool _isSaving = false;
  String? _errorMessage;

  // Credit-card-only fields.
  Money? _creditLimit;
  CardNetwork? _network;
  final TextEditingController _last4Controller = TextEditingController();
  final TextEditingController _expiryMonthController = TextEditingController();
  final TextEditingController _expiryYearController = TextEditingController();
  final TextEditingController _statementClosingDayController = TextEditingController();
  final TextEditingController _dueDayController = TextEditingController();

  // Deposit-only fields.
  DepositType _depositType = DepositType.fixed;
  DateTime? _startDate;
  final TextEditingController _rateController = TextEditingController();
  DepositInterestMethod _interestMethod = DepositInterestMethod.simple;
  final TextEditingController _termNumberController = TextEditingController();
  DepositTermUnit _termUnit = DepositTermUnit.months;
  DepositCompoundingFrequency? _compoundingFrequency;
  bool _autoRenew = false;
  Money? _installmentAmount;
  DepositInstallmentFrequency? _installmentFrequency;
  String? _interestDestinationAccountId;

  bool get _isCreditCard => widget.kind.requiresCreditFacility;
  bool get _isDeposit => widget.kind.requiresDepositDetails;

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _last4Controller.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _statementClosingDayController.dispose();
    _dueDayController.dispose();
    _rateController.dispose();
    _termNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(accountCreationKindTitle(l10n, widget.kind))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.accountNameLabel),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.enterAccountNameMessage : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _currencyCode,
                  decoration: InputDecoration(labelText: l10n.currencySection),
                  items: <DropdownMenuItem<String>>[
                    for (final currency in CurrencyRegistry.seed)
                      DropdownMenuItem<String>(value: currency.code, child: Text(currency.code)),
                  ],
                  onChanged: (v) => setState(() => _currencyCode = v ?? _currencyCode),
                ),
                const SizedBox(height: 16),
                MoneyTextField(
                  key: ValueKey<String>('addAccountAmount_$_currencyCode'),
                  currencyCode: _currencyCode,
                  label: _amountLabel(l10n),
                  onParsed: (Money? value) => setState(() => _amount = value),
                ),
                if (widget.kind.allowsInstitution) ...<Widget>[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _institutionController,
                    decoration: InputDecoration(
                      labelText: l10n.addAccountInstitutionLabel,
                      hintText: l10n.addAccountInstitutionHint,
                    ),
                  ),
                ],
                if (_isCreditCard) ..._buildCreditCardFields(l10n),
                if (_isDeposit) ..._buildDepositFields(l10n),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...<Widget>[
                  Text(
                    _errorMessage!,
                    style: context.appTypography.body?.copyWith(color: colors.error),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.addAccountCreateButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _amountLabel(AppLocalizations l10n) {
    if (_isCreditCard) return l10n.addAccountAmountOwedLabel;
    if (_isDeposit) return l10n.addAccountPrincipalLabel;
    return l10n.accountOpeningBalanceLabel;
  }

  List<Widget> _buildCreditCardFields(AppLocalizations l10n) {
    return <Widget>[
      const SizedBox(height: 16),
      MoneyTextField(
        key: ValueKey<String>('addAccountCreditLimit_$_currencyCode'),
        currencyCode: _currencyCode,
        label: l10n.addAccountCreditLimitLabel,
        onParsed: (Money? value) => setState(() => _creditLimit = value),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<CardNetwork?>(
        initialValue: _network,
        decoration: InputDecoration(labelText: l10n.addAccountCardNetworkLabel),
        items: <DropdownMenuItem<CardNetwork?>>[
          DropdownMenuItem<CardNetwork?>(value: null, child: Text(l10n.addAccountCardNetworkNone)),
          for (final CardNetwork network in CardNetwork.values)
            DropdownMenuItem<CardNetwork?>(
              value: network,
              child: Text(_networkLabel(l10n, network)),
            ),
        ],
        onChanged: (v) => setState(() => _network = v),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _last4Controller,
        keyboardType: TextInputType.number,
        maxLength: 4,
        decoration: InputDecoration(labelText: l10n.addAccountLast4Label),
        validator: (v) {
          if (v == null || v.isEmpty) return null;
          return RegExp(r'^\d{4}$').hasMatch(v) ? null : l10n.addAccountLast4ErrorMessage;
        },
      ),
      const SizedBox(height: 16),
      Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _expiryMonthController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.addAccountExpiryMonthLabel),
              validator: (v) => _validateOptionalRange(v, 1, 12, l10n.addAccountExpiryMonthErrorMessage),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _expiryYearController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.addAccountExpiryYearLabel),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _statementClosingDayController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.addAccountStatementClosingDayLabel),
              validator: (v) => _validateOptionalRange(v, 1, 31, l10n.addAccountDayOfMonthErrorMessage),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _dueDayController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.addAccountDueDayLabel),
              validator: (v) => _validateOptionalRange(v, 1, 31, l10n.addAccountDayOfMonthErrorMessage),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildDepositFields(AppLocalizations l10n) {
    final List<AccountRow> sameCurrencyAccounts = (ref.watch(accountsProvider).valueOrNull ??
            const <AccountRow>[])
        .where((AccountRow a) => a.currencyCode == _currencyCode)
        .toList();
    // Guard against a previously-chosen destination that no longer
    // exists or no longer matches the currently-selected currency (e.g.
    // the user switched the currency dropdown after choosing one) --
    // reset it rather than silently submitting a stale/invalid id.
    if (_interestDestinationAccountId != null &&
        !sameCurrencyAccounts.any((AccountRow a) => a.id == _interestDestinationAccountId)) {
      _interestDestinationAccountId = null;
    }

    return <Widget>[
      const SizedBox(height: 16),
      DropdownButtonFormField<DepositType>(
        initialValue: _depositType,
        decoration: InputDecoration(labelText: l10n.addAccountDepositTypeLabel),
        items: <DropdownMenuItem<DepositType>>[
          for (final DepositType type in DepositType.values)
            DropdownMenuItem<DepositType>(value: type, child: Text(_depositTypeLabel(l10n, type))),
        ],
        onChanged: (v) => setState(() => _depositType = v ?? _depositType),
      ),
      const SizedBox(height: 16),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.addAccountStartDateLabel),
        subtitle: Text(
          _startDate == null ? l10n.addAccountChooseStartDateMessage : _formatDate(_startDate!),
        ),
        trailing: const Icon(Icons.calendar_today_outlined),
        onTap: _pickStartDate,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _rateController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l10n.addAccountAnnualRateLabel),
        onChanged: (_) => setState(() {}),
        validator: (v) {
          try {
            InterestRateInput.parseAnnualRatePercentToBasisPoints(v ?? '');
            return null;
          } on InterestRateInputException catch (e) {
            return e.message;
          }
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<DepositInterestMethod>(
        initialValue: _interestMethod,
        decoration: InputDecoration(labelText: l10n.addAccountInterestMethodLabel),
        items: <DropdownMenuItem<DepositInterestMethod>>[
          for (final DepositInterestMethod method in DepositInterestMethod.values)
            DropdownMenuItem<DepositInterestMethod>(
              value: method,
              child: Text(_interestMethodLabel(l10n, method)),
            ),
        ],
        onChanged: (v) => setState(() {
          _interestMethod = v ?? _interestMethod;
          if (_interestMethod == DepositInterestMethod.simple) _compoundingFrequency = null;
        }),
      ),
      const SizedBox(height: 16),
      Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _termNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.addAccountTermNumberLabel),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final int? parsed = int.tryParse(v ?? '');
                return (parsed == null || parsed < 1) ? l10n.addAccountTermNumberErrorMessage : null;
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<DepositTermUnit>(
              initialValue: _termUnit,
              decoration: InputDecoration(labelText: l10n.addAccountTermUnitLabel),
              items: <DropdownMenuItem<DepositTermUnit>>[
                for (final DepositTermUnit unit in DepositTermUnit.values)
                  DropdownMenuItem<DepositTermUnit>(
                    value: unit,
                    child: Text(_termUnitLabel(l10n, unit)),
                  ),
              ],
              onChanged: (v) => setState(() => _termUnit = v ?? _termUnit),
            ),
          ),
        ],
      ),
      if (_interestMethod == DepositInterestMethod.compound) ...<Widget>[
        const SizedBox(height: 16),
        DropdownButtonFormField<DepositCompoundingFrequency>(
          initialValue: _compoundingFrequency,
          decoration: InputDecoration(labelText: l10n.addAccountCompoundingFrequencyLabel),
          items: <DropdownMenuItem<DepositCompoundingFrequency>>[
            for (final DepositCompoundingFrequency frequency in DepositCompoundingFrequency.values)
              DropdownMenuItem<DepositCompoundingFrequency>(
                value: frequency,
                child: Text(_compoundingFrequencyLabel(l10n, frequency)),
              ),
          ],
          onChanged: (v) => setState(() => _compoundingFrequency = v),
          validator: (v) => v == null ? l10n.addAccountChooseCompoundingFrequencyMessage : null,
        ),
      ],
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.addAccountAutoRenewLabel),
        value: _autoRenew,
        onChanged: (v) => setState(() => _autoRenew = v),
      ),
      if (_depositType == DepositType.recurring) ...<Widget>[
        const SizedBox(height: 16),
        MoneyTextField(
          key: ValueKey<String>('addAccountInstallmentAmount_$_currencyCode'),
          currencyCode: _currencyCode,
          label: l10n.addAccountInstallmentAmountLabel,
          onParsed: (Money? value) => setState(() => _installmentAmount = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<DepositInstallmentFrequency?>(
          initialValue: _installmentFrequency,
          decoration: InputDecoration(labelText: l10n.addAccountInstallmentFrequencyLabel),
          items: <DropdownMenuItem<DepositInstallmentFrequency?>>[
            DropdownMenuItem<DepositInstallmentFrequency?>(
              value: null,
              child: Text(l10n.addAccountInstallmentFrequencyNone),
            ),
            for (final DepositInstallmentFrequency frequency in DepositInstallmentFrequency.values)
              DropdownMenuItem<DepositInstallmentFrequency?>(
                value: frequency,
                child: Text(_installmentFrequencyLabel(l10n, frequency)),
              ),
          ],
          onChanged: (v) => setState(() => _installmentFrequency = v),
        ),
      ],
      if (sameCurrencyAccounts.isNotEmpty) ...<Widget>[
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _interestDestinationAccountId,
          decoration: InputDecoration(labelText: l10n.addAccountInterestDestinationLabel),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(value: null, child: Text(l10n.addAccountNoneOption)),
            for (final AccountRow account in sameCurrencyAccounts)
              DropdownMenuItem<String?>(value: account.id, child: Text(account.name)),
          ],
          onChanged: (v) => setState(() => _interestDestinationAccountId = v),
        ),
      ],
      ..._buildDepositEstimate(l10n),
    ];
  }

  /// Estimated interest/maturity preview -- always clearly labeled
  /// "Estimated", never persisted (docs/20 §12.8's non-negotiable
  /// labeling requirement). Computed by calling [DepositCalculator]
  /// directly, never by re-deriving its interest formulas here. Only
  /// the maturity DATE (not any interest arithmetic) is computed
  /// locally, via the same public [addWholeCalendarMonths] helper
  /// `DepositRepository` itself uses -- see that repository's own
  /// `_computeMaturityDate` doc for the identical days/months/years
  /// switch this mirrors. Silently shows nothing until every required
  /// input the calculation needs is present and valid.
  List<Widget> _buildDepositEstimate(AppLocalizations l10n) {
    final DateTime? startDate = _startDate;
    final int? termNumber = int.tryParse(_termNumberController.text);
    if (startDate == null || termNumber == null || termNumber < 1) return const <Widget>[];
    int? basisPoints;
    try {
      basisPoints = InterestRateInput.parseAnnualRatePercentToBasisPoints(_rateController.text);
    } on InterestRateInputException {
      return const <Widget>[];
    }
    final Money principal = _amount ?? Money.zero(_currencyCode);
    if (principal.isZero) return const <Widget>[];

    final DateTime maturityDate = _previewMaturityDate(
      startDateUtc: startDate,
      termNumber: termNumber,
      termUnit: _termUnit,
    );

    DepositEstimate estimate;
    try {
      if (_interestMethod == DepositInterestMethod.simple) {
        estimate = DepositCalculator.calculateSimpleInterest(
          principal: principal,
          interestRateBasisPoints: basisPoints,
          startDateUtc: startDate,
          maturityDateUtc: maturityDate,
        );
      } else {
        final DepositCompoundingFrequency? frequency = _compoundingFrequency;
        if (frequency == null) return const <Widget>[];
        estimate = DepositCalculator.calculateCompoundInterest(
          principal: principal,
          interestRateBasisPoints: basisPoints,
          compoundingFrequency: frequency,
          termNumber: termNumber,
          termUnit: _termUnit,
        );
      }
    } catch (_) {
      // e.g. AmbiguousCompoundPeriodException for a days-based compound
      // term -- silently show nothing rather than an alarming error for
      // what is only a non-persisted preview; the real validation still
      // runs (and surfaces its own message) on submit.
      return const <Widget>[];
    }

    return <Widget>[
      const SizedBox(height: 20),
      Text(l10n.addAccountEstimatedInterestLabel, style: context.appTypography.caption),
      Text(estimate.estimatedInterest.toMajorUnitsString(), style: context.appTypography.body),
      const SizedBox(height: 8),
      Text(l10n.addAccountEstimatedMaturityValueLabel, style: context.appTypography.caption),
      Text(estimate.estimatedMaturityValue.toMajorUnitsString(), style: context.appTypography.body),
      const SizedBox(height: 8),
      Text(l10n.addAccountEstimatedMaturityDateLabel, style: context.appTypography.caption),
      Text(_formatDate(maturityDate), style: context.appTypography.body),
      const SizedBox(height: 8),
      Text(l10n.addAccountEstimateDisclaimer, style: context.appTypography.caption),
    ];
  }

  DateTime _previewMaturityDate({
    required DateTime startDateUtc,
    required int termNumber,
    required DepositTermUnit termUnit,
  }) {
    switch (termUnit) {
      case DepositTermUnit.days:
        return startDateUtc.add(Duration(days: termNumber));
      case DepositTermUnit.months:
        return addWholeCalendarMonths(startDateUtc, termNumber);
      case DepositTermUnit.years:
        return addWholeCalendarMonths(startDateUtc, termNumber * 12);
    }
  }

  Future<void> _pickStartDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.utc(now.year, now.month, now.day),
      firstDate: DateTime.utc(now.year - 50),
      lastDate: DateTime.utc(now.year + 50),
    );
    if (picked != null) {
      setState(() => _startDate = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  String _formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _validateOptionalRange(String? value, int min, int max, String errorMessage) {
    if (value == null || value.isEmpty) return null;
    final int? parsed = int.tryParse(value);
    if (parsed == null || parsed < min || parsed > max) return errorMessage;
    return null;
  }

  String _networkLabel(AppLocalizations l10n, CardNetwork network) {
    switch (network) {
      case CardNetwork.visa:
        return l10n.addAccountCardNetworkVisa;
      case CardNetwork.mastercard:
        return l10n.addAccountCardNetworkMastercard;
      case CardNetwork.jcb:
        return l10n.addAccountCardNetworkJcb;
      case CardNetwork.amex:
        return l10n.addAccountCardNetworkAmex;
      case CardNetwork.other:
        return l10n.addAccountCardNetworkOther;
    }
  }

  String _depositTypeLabel(AppLocalizations l10n, DepositType type) {
    switch (type) {
      case DepositType.fixed:
        return l10n.addAccountDepositTypeFixed;
      case DepositType.shortTerm:
        return l10n.addAccountDepositTypeShortTerm;
      case DepositType.recurring:
        return l10n.addAccountDepositTypeRecurring;
      case DepositType.other:
        return l10n.addAccountDepositTypeOther;
    }
  }

  String _interestMethodLabel(AppLocalizations l10n, DepositInterestMethod method) {
    switch (method) {
      case DepositInterestMethod.simple:
        return l10n.addAccountInterestMethodSimple;
      case DepositInterestMethod.compound:
        return l10n.addAccountInterestMethodCompound;
    }
  }

  String _termUnitLabel(AppLocalizations l10n, DepositTermUnit unit) {
    switch (unit) {
      case DepositTermUnit.days:
        return l10n.addAccountTermUnitDays;
      case DepositTermUnit.months:
        return l10n.addAccountTermUnitMonths;
      case DepositTermUnit.years:
        return l10n.addAccountTermUnitYears;
    }
  }

  String _compoundingFrequencyLabel(AppLocalizations l10n, DepositCompoundingFrequency frequency) {
    switch (frequency) {
      case DepositCompoundingFrequency.monthly:
        return l10n.addAccountCompoundingFrequencyMonthly;
      case DepositCompoundingFrequency.quarterly:
        return l10n.addAccountCompoundingFrequencyQuarterly;
      case DepositCompoundingFrequency.semiannual:
        return l10n.addAccountCompoundingFrequencySemiannual;
      case DepositCompoundingFrequency.annual:
        return l10n.addAccountCompoundingFrequencyAnnual;
      case DepositCompoundingFrequency.atMaturity:
        return l10n.addAccountCompoundingFrequencyAtMaturity;
    }
  }

  String _installmentFrequencyLabel(AppLocalizations l10n, DepositInstallmentFrequency frequency) {
    switch (frequency) {
      case DepositInstallmentFrequency.weekly:
        return l10n.addAccountInstallmentFrequencyWeekly;
      case DepositInstallmentFrequency.monthly:
        return l10n.addAccountInstallmentFrequencyMonthly;
      case DepositInstallmentFrequency.quarterly:
        return l10n.addAccountInstallmentFrequencyQuarterly;
      case DepositInstallmentFrequency.yearly:
        return l10n.addAccountInstallmentFrequencyYearly;
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_amount == null) {
      setState(() => _errorMessage = l10n.enterValidAmount);
      return;
    }
    if (_isCreditCard && _creditLimit == null) {
      setState(() => _errorMessage = l10n.enterValidAmount);
      return;
    }
    DateTime? startDateUtc;
    int? interestRateBasisPoints;
    int? termNumber;
    if (_isDeposit) {
      if (_startDate == null) {
        setState(() => _errorMessage = l10n.addAccountChooseStartDateMessage);
        return;
      }
      startDateUtc = _startDate;
      try {
        interestRateBasisPoints =
            InterestRateInput.parseAnnualRatePercentToBasisPoints(_rateController.text);
      } on InterestRateInputException catch (e) {
        setState(() => _errorMessage = e.message);
        return;
      }
      termNumber = int.tryParse(_termNumberController.text);
      if (termNumber == null || termNumber < 1) {
        setState(() => _errorMessage = l10n.addAccountTermNumberErrorMessage);
        return;
      }
      if (_interestMethod == DepositInterestMethod.compound && _compoundingFrequency == null) {
        setState(() => _errorMessage = l10n.addAccountChooseCompoundingFrequencyMessage);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final ProfileRow? profile = await ref.read(profileRepositoryProvider).getProfile();
      if (profile == null) return;

      // Checkpoint G revision: institution resolution is no longer done
      // here as a separate, already-committed step before account
      // creation. `AccountCreationService` now resolves (and, if
      // needed, creates) the institution row itself, INSIDE the same
      // atomic transaction as the account composition, so a failed
      // account creation can no longer leave behind an orphaned
      // institution row. This screen only passes the raw trimmed name
      // through.
      final String rawInstitutionName = _institutionController.text.trim();
      final String? institutionName =
          (widget.kind.allowsInstitution && rawInstitutionName.isNotEmpty)
              ? rawInstitutionName
              : null;

      final AccountCreationService service = ref.read(accountCreationServiceProvider);

      if (_isCreditCard) {
        await service.createCreditCardAccount(
          profileId: profile.id,
          name: _nameController.text.trim(),
          currencyCode: _currencyCode,
          owedAmount: _amount!,
          creditLimit: _creditLimit!,
          institutionName: institutionName,
          network: _network,
          last4: _last4Controller.text.isEmpty ? null : _last4Controller.text,
          expiryMonth: int.tryParse(_expiryMonthController.text),
          expiryYear: int.tryParse(_expiryYearController.text),
          statementClosingDay: int.tryParse(_statementClosingDayController.text),
          dueDay: int.tryParse(_dueDayController.text),
        );
      } else if (_isDeposit) {
        await service.createDepositAccount(
          profileId: profile.id,
          name: _nameController.text.trim(),
          currencyCode: _currencyCode,
          principal: _amount!,
          depositType: _depositType,
          termNumber: termNumber!,
          termUnit: _termUnit,
          startDateUtc: startDateUtc!,
          interestRateBasisPoints: interestRateBasisPoints!,
          interestMethod: _interestMethod,
          compoundingFrequency: _compoundingFrequency,
          autoRenew: _autoRenew,
          interestDestinationAccountId: _interestDestinationAccountId,
          installmentAmountMinorUnits: _depositType == DepositType.recurring
              ? _installmentAmount?.minorUnits
              : null,
          installmentFrequency:
              _depositType == DepositType.recurring ? _installmentFrequency : null,
          institutionName: institutionName,
        );
      } else {
        await service.createSimpleAccount(
          kind: widget.kind,
          profileId: profile.id,
          name: _nameController.text.trim(),
          currencyCode: _currencyCode,
          openingBalance: _amount,
          institutionName: institutionName,
        );
      }
      // Checkpoint G: this screen is always TWO pushes deep from
      // Accounts (Accounts -> AddAccountTypeScreen -> here), unlike the
      // one-push-deep `AddTransactionScreen`/`EditAccountScreen` this
      // pattern is otherwise copied from -- a single `pop()` would only
      // return to the type chooser, not to Accounts. Popping twice on
      // the same captured `NavigatorState` returns predictably to
      // Accounts after a successful creation, per the checkpoint's own
      // "return/navigate predictably to the Accounts experience"
      // requirement, without introducing a second navigation idiom
      // (`context.go`, unused anywhere else in this app) for one screen.
      if (mounted) {
        final NavigatorState navigator = Navigator.of(context);
        navigator.pop();
        navigator.pop();
      }
    } on CurrencyMismatchException catch (e) {
      setState(() {
        _errorMessage = l10n.currencyMismatchError(e.currencyCodeA, e.currencyCodeB);
      });
    } catch (e) {
      setState(() => _errorMessage = l10n.addAccountCreationFailedMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

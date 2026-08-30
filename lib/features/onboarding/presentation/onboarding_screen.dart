import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency_registry.dart';
import '../../../core/database/providers.dart';
import '../domain/country_registry.dart';

/// Beta 0 onboarding: display name, current/home country, and
/// living/home currency — the fields the `profiles` table actually
/// stores (see `docs/03_DATABASE_SCHEMA.md`). The fuller onboarding
/// sequence sketched in `docs/00_MASTER_BLUEPRINT.md` §40 (main
/// intent, optional income, first goal, receipt permission,
/// notification preference) is not implemented here: none of those data
/// points has a place in the Beta 0 schema (goals/receipts/notifications
/// don't exist yet), so asking for them now would either be discarded or
/// require speculative schema — see
/// `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §16. `preferred_language`,
/// `timezone`, `date_format`, and `number_format` are set to sensible
/// defaults here rather than asked explicitly, per the blueprint's own
/// "defaults should be inferred where safe" guidance — Settings (Beta 1+)
/// is where they become user-editable.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  String _currentCountry = 'JP';
  String _homeCountry = 'LK';
  String? _livingCurrency;
  String? _homeCurrency;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _livingCurrency = CountryRegistry.byCode(_currentCountry).defaultCurrencyCode;
    _homeCurrency = CountryRegistry.byCode(_homeCountry).defaultCurrencyCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(profileRepositoryProvider).createProfile(
            displayName: _nameController.text.trim(),
            homeCountry: _homeCountry,
            currentCountry: _currentCountry,
            homeCurrency: _homeCurrency!,
            livingCurrency: _livingCurrency!,
            preferredLanguage: 'en',
            timezone: 'UTC',
            dateFormat: 'yyyy-MM-dd',
            numberFormat: '#,##0.##',
          );
      // No explicit navigation: GoRouter's redirect (see
      // lib/core/routing/app_router.dart) reacts to activeProfileProvider
      // changing and moves us to Home automatically.
    } catch (e) {
      setState(() => _errorMessage = 'Could not save your profile: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text('Welcome', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                "Let's set up your profile. You can change any of this later in Settings.",
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'What should we call you?'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Enter a name.' : null,
              ),
              const SizedBox(height: 24),
              Text('Where do you live right now?', style: Theme.of(context).textTheme.titleMedium),
              _CountryDropdown(
                value: _currentCountry,
                onChanged: (code) => setState(() {
                  _currentCountry = code;
                  _livingCurrency = CountryRegistry.byCode(code).defaultCurrencyCode;
                }),
              ),
              _CurrencyDropdown(
                label: 'Living currency',
                value: _livingCurrency!,
                onChanged: (code) => setState(() => _livingCurrency = code),
              ),
              const SizedBox(height: 24),
              Text('Where is home?', style: Theme.of(context).textTheme.titleMedium),
              _CountryDropdown(
                value: _homeCountry,
                onChanged: (code) => setState(() {
                  _homeCountry = code;
                  _homeCurrency = CountryRegistry.byCode(code).defaultCurrencyCode;
                }),
              ),
              _CurrencyDropdown(
                label: 'Home currency',
                value: _homeCurrency!,
                onChanged: (code) => setState(() => _homeCurrency = code),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...<Widget>[
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Get started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// NOTE ON DropdownButtonFormField BELOW: this uses the `initialValue`
// parameter name. Flutter renamed `DropdownButtonFormField.value` to
// `initialValue` at some point (aligning it with other FormField
// widgets); this file was written without a working `flutter analyze`
// to confirm which name the installed Flutter SDK version expects (see
// CLAUDE_FIRST_CODING_PROMPT.md). If analysis reports an unknown named
// parameter here, rename `initialValue` to `value` in both
// `_CountryDropdown` and `_CurrencyDropdown` below — a one-line fix per
// occurrence, not a logic change.

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Country'),
      items: <DropdownMenuItem<String>>[
        for (final OnboardingCountry country in CountryRegistry.all)
          DropdownMenuItem<String>(value: country.code, child: Text(country.displayName)),
      ],
      onChanged: (code) {
        if (code != null) onChanged(code);
      },
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({required this.label, required this.value, required this.onChanged});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<String>>[
        for (final currency in CurrencyRegistry.seed)
          DropdownMenuItem<String>(
            value: currency.code,
            child: Text('${currency.code} — ${currency.displayName}'),
          ),
      ],
      onChanged: (code) {
        if (code != null) onChanged(code);
      },
    );
  }
}

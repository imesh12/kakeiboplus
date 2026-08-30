import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/money/money_parse_exception.dart';
import '../../core/money/money_parser.dart';

/// A currency-aware amount input field.
///
/// Validation goes through [MoneyParser] — the same parser the domain
/// layer uses — so a currency that allows 0 decimal digits (JPY/KRW/VND)
/// rejects a typed fraction, and one that allows 3 (KWD) rejects a 4th
/// digit, exactly as the release gates require. [onParsed] is called with
/// the parsed [Money] whenever the field currently holds a valid amount;
/// callers read the last value from there rather than re-parsing text
/// themselves.
///
/// Beta 0 scope note: this validates on submit (via [FormState.validate])
/// rather than filtering keystrokes as they're typed. Real-time input
/// filtering is a nice-to-have polish item, not one of the Beta 0 release
/// gates — see `STAGE1_BETA0_IMPLEMENTATION_PLAN.md` §14.
class MoneyTextField extends StatefulWidget {
  const MoneyTextField({
    required this.currencyCode,
    required this.onParsed,
    super.key,
    this.label = 'Amount',
    this.initialValue,
  });

  final String currencyCode;
  final String? label;
  final String? initialValue;
  final ValueChanged<Money?> onParsed;

  @override
  State<MoneyTextField> createState() => _MoneyTextFieldState();
}

class _MoneyTextFieldState extends State<MoneyTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant MoneyTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currencyCode != widget.currencyCode) {
      // Currency changed (e.g. account switched) — re-validate the
      // existing text against the new currency's precision rules.
      _tryParse(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tryParse(String text) {
    try {
      widget.onParsed(MoneyParser.parse(text, widget.currencyCode));
    } on MoneyParseException {
      widget.onParsed(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: '${widget.currencyCode} ',
      ),
      onChanged: _tryParse,
      validator: (String? value) {
        try {
          MoneyParser.parse(value ?? '', widget.currencyCode);
          return null;
        } on MoneyParseException catch (e) {
          return e.message;
        }
      },
    );
  }
}

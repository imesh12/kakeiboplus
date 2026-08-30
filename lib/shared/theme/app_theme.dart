import 'package:flutter/material.dart';

/// A single, calm, Material 3 theme — per
/// `docs/00_MASTER_BLUEPRINT.md` §37 ("premium, calm, modern, friendly,
/// trustworthy, lightweight ... avoid ... aggressive red warnings").
/// Beta 0 does not implement dark-mode-specific tuning beyond what
/// `ColorScheme.fromSeed` already provides for `Brightness.dark`.
class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF2E7D6B);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/providers.dart';
import '../core/routing/app_router.dart';
import '../shared/theme/app_theme.dart';

/// App root: wires up `MaterialApp.router` with the Beta 0 [GoRouter]
/// and seeds system categories once the database is available.
class AiFinancialCoachApp extends ConsumerWidget {
  const AiFinancialCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fire-and-forget: idempotent (insertOrIgnore — see
    // CategoryRepository.seedSystemCategoriesIfNeeded), safe to call on
    // every app start.
    unawaited(ref.watch(categoryRepositoryProvider).seedSystemCategoriesIfNeeded());

    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AI Financial Coach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}

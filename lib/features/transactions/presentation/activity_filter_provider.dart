import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activity_filter.dart';

/// Activity's search/filter UI state -- Beta 1 Transaction UX Phase B,
/// Checkpoint 3 (`docs/14_DECISION_LOG.md` ADR-025/026).
///
/// A plain `StateProvider.autoDispose` is the simplest Riverpod shape
/// that fits this state's lifecycle: it holds one small immutable value
/// ([ActivityFilterState]) with no asynchronous work and no business
/// logic beyond the `copyWith`/`filterActivity` helpers
/// `activity_filter.dart` (Checkpoint 1) already provides, so a full
/// `StateNotifier`/`Notifier` class would add ceremony without adding
/// safety.
///
/// `.autoDispose` is what makes this screen-local rather than global:
/// `ActivityScreen` is the only widget that ever watches this provider,
/// so the moment it's unmounted (the user leaves Activity), the
/// provider loses its last listener and Riverpod tears it down
/// immediately. The next time Activity is built, this provider is
/// re-created fresh at [ActivityFilterState.initial] -- there is no
/// code path that reads a previous session's value back, and nothing
/// here ever touches Drift, `SharedPreferences`, or profile/account
/// state, so "screen-local, resets on leaving, never persisted" is true
/// by construction rather than by convention.
final AutoDisposeStateProvider<ActivityFilterState> activityFilterProvider =
    StateProvider.autoDispose<ActivityFilterState>((ref) => ActivityFilterState.initial);

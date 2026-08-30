import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] to a [Listenable] so `GoRouter`'s
/// `refreshListenable` re-evaluates `redirect` whenever the stream
/// emits — e.g. when the active profile changes (onboarding completes,
/// see `lib/core/routing/app_router.dart`).
///
/// `go_router` itself does not export a class like this — it's a small,
/// widely-used utility from the package's own official examples that
/// consuming apps hand-roll. Written here rather than pulled from an
/// extra dependency to keep the dependency list to what Beta 0 actually
/// needs (Decision 9).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

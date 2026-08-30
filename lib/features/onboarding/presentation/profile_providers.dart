import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';

/// The single local profile, or `null` before onboarding has created one.
/// Beta 0 has no auth/multi-profile support (see
/// `lib/core/database/repositories/profile_repository.dart`), so nothing
/// else needs to key this by an id.
final StreamProvider<ProfileRow?> activeProfileProvider = StreamProvider<ProfileRow?>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});

/// True once onboarding has created a profile. `GoRouter`'s redirect
/// logic (see `lib/core/routing/app_router.dart`) uses this to decide
/// whether to show onboarding or the main navigation shell.
final Provider<AsyncValue<bool>> hasProfileProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(activeProfileProvider).whenData((profile) => profile != null);
});

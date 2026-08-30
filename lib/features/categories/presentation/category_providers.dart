import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers.dart';
import '../../onboarding/presentation/profile_providers.dart';

/// Categories usable for a given transaction `type` ('expense' or
/// 'income') — system categories plus any the current profile added.
/// `.family` keyed by a plain [String] type name.
final AutoDisposeStreamProviderFamily<List<CategoryRow>, String> categoriesForTypeProvider =
    StreamProvider.autoDispose.family<List<CategoryRow>, String>((ref, type) async* {
  final ProfileRow? profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) {
    yield const <CategoryRow>[];
    return;
  }
  yield* ref
      .watch(categoryRepositoryProvider)
      .watchAvailableFor(profileId: profile.id, type: type);
});

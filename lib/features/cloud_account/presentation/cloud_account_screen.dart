import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/different_cloud_account_linked_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../domain/cloud_account_status.dart';
import 'cloud_account_providers.dart';

/// Checkpoint 12.2 (Cloud Identity / Auth Foundation): the minimum
/// Account/Cloud entry point required for V1 -- reached from Profile/
/// Settings' new "Cloud Account" row (see `settings_screen.dart`).
///
/// # What this screen truthfully shows, and never claims
///
/// Renders exactly one of [CloudAccountStatusKind]'s 4 states via
/// [AppStatusChip] + an explanatory sentence -- never "Synced"/"Backed
/// up"/"Up to date" (financial sync does not exist yet, and this screen
/// never implies otherwise). In every production build today,
/// [CloudAccountStatusKind.unavailable] is the ONLY state a real user
/// can ever see -- `UnavailableCloudAuthProvider` never reports itself
/// available -- and [CloudAccountStatusKind.localOnly]/
/// [CloudAccountStatusKind.signedIn]/[CloudAccountStatusKind.sessionExpired] are only
/// reachable in a test/dev build that overrides `cloudAuthProviderProvider`
/// with `InMemoryCloudAuthProvider`. This screen renders all 4 correctly
/// regardless, since which one is live is entirely the provider's
/// decision, never this widget's.
///
/// # Different-account sign-in
///
/// [_handleButtonTap] catches [DifferentCloudAccountLinkedException] and shows a
/// blocking dialog rather than letting it surface as an unhandled error
/// -- CP12.2's minimum-safe-behavior instruction for this case (no
/// reset/merge flow exists yet; the dialog says so plainly).
class CloudAccountScreen extends ConsumerWidget {
  const CloudAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CloudAccountStatus> statusAsync = ref.watch(cloudAccountStatusProvider);
    final AppTokens tokens = context.appTokens;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cloudAccountSectionTitle)),
      body: SafeArea(
        child: statusAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace st) => Center(child: Text('$e')),
          data: (CloudAccountStatus status) {
            final _StatusPresentation presentation = _presentationFor(l10n, colors, status);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                AppCard(
                  bordered: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AppStatusChip(label: presentation.chipLabel, color: presentation.color),
                      SizedBox(height: tokens.spacing.md),
                      Text(presentation.explanation, style: context.appTypography.secondaryBody),
                      if (status.kind == CloudAccountStatusKind.signedIn ||
                          status.kind == CloudAccountStatusKind.sessionExpired) ...<Widget>[
                        SizedBox(height: tokens.spacing.xs),
                        Text(
                          l10n.cloudAccountSignOutNeverDeletesLocalDataNote,
                          style: context.appTypography.caption,
                        ),
                      ],
                      if (presentation.buttonLabel != null) ...<Widget>[
                        SizedBox(height: tokens.spacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: Key('cloudAccount_${presentation.buttonAction}'),
                            onPressed: () => _handleButtonTap(context, ref, status),
                            child: Text(presentation.buttonLabel!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleButtonTap(
    BuildContext context,
    WidgetRef ref,
    CloudAccountStatus status,
  ) async {
    if (status.kind == CloudAccountStatusKind.signedIn) {
      await signOutCurrentProfile(ref);
      return;
    }
    // localOnly or sessionExpired -- both offer "sign in".
    try {
      await signInAndLinkCurrentProfile(ref);
    } on DifferentCloudAccountLinkedException {
      if (context.mounted) await _showDifferentAccountDialog(context);
    }
  }

  Future<void> _showDifferentAccountDialog(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.cloudAccountDifferentAccountDialogTitle),
        content: Text(l10n.cloudAccountDifferentAccountDialogMessage),
        actions: <Widget>[
          TextButton(
            key: const Key('cloudAccountDifferentAccountDialogDismiss'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cloudAccountDialogDismissLabel),
          ),
        ],
      ),
    );
  }

  _StatusPresentation _presentationFor(
    AppLocalizations l10n,
    ColorScheme colors,
    CloudAccountStatus status,
  ) {
    switch (status.kind) {
      case CloudAccountStatusKind.unavailable:
        return _StatusPresentation(
          chipLabel: l10n.cloudAccountStatusChipUnavailable,
          color: colors.onSurfaceVariant,
          explanation: l10n.cloudAccountUnavailableExplanation,
          buttonLabel: null,
          buttonAction: null,
        );
      case CloudAccountStatusKind.localOnly:
        return _StatusPresentation(
          chipLabel: l10n.cloudAccountStatusChipLocalOnly,
          color: colors.onSurfaceVariant,
          explanation: l10n.cloudAccountLocalOnlyExplanation,
          buttonLabel: l10n.cloudAccountSignInButtonLabel,
          buttonAction: 'signIn',
        );
      case CloudAccountStatusKind.signedIn:
        return _StatusPresentation(
          chipLabel: l10n.cloudAccountStatusChipSignedIn,
          color: colors.primary,
          explanation: l10n.cloudAccountSignedInExplanation(status.cloudUserId!),
          buttonLabel: l10n.cloudAccountSignOutButtonLabel,
          buttonAction: 'signOut',
        );
      case CloudAccountStatusKind.sessionExpired:
        return _StatusPresentation(
          chipLabel: l10n.cloudAccountStatusChipSessionExpired,
          color: colors.error,
          explanation: l10n.cloudAccountSessionExpiredExplanation,
          buttonLabel: l10n.cloudAccountSignInButtonLabel,
          buttonAction: 'signIn',
        );
    }
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.chipLabel,
    required this.color,
    required this.explanation,
    required this.buttonLabel,
    required this.buttonAction,
  });

  final String chipLabel;
  final Color color;
  final String explanation;
  final String? buttonLabel;
  final String? buttonAction;
}

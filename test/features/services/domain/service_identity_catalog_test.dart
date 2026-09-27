import 'package:ai_financial_coach/features/services/domain/service_identity.dart';
import 'package:ai_financial_coach/features/services/domain/service_identity_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ai_financial_coach/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

void main() {
  group('serviceIdentityCatalog', () {
    test('every id is unique -- no duplicate ServiceIdentityDefinition.id', () {
      final List<String> ids = serviceIdentityCatalog.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('is not empty and is a curated set, not a giant merchant database', () {
      expect(serviceIdentityCatalog, isNotEmpty);
      expect(serviceIdentityCatalog.length, lessThan(100));
    });

    test('every ServiceIdentityFamily has exactly one generic (unnamed) entry', () {
      for (final ServiceIdentityFamily family in ServiceIdentityFamily.values) {
        final int genericCount =
            serviceIdentityCatalog.where((d) => d.family == family && !d.isNamed).length;
        expect(genericCount, 1, reason: family.storageValue);
      }
    });

    test('a generic entry\'s id equals its family\'s storageValue', () {
      for (final def in serviceIdentityCatalog.where((d) => !d.isNamed)) {
        expect(def.id, def.family.storageValue);
      }
    });

    test('named and generic identities are distinguishable via isNamed', () {
      expect(serviceIdentityCatalog.where((d) => d.isNamed), isNotEmpty);
      expect(serviceIdentityCatalog.where((d) => !d.isNamed), isNotEmpty);
    });

    test('a well-known named service (Netflix) resolves under the streaming family', () {
      final def = serviceIdentityCatalog.firstWhere((d) => d.id == 'netflix');
      expect(def.family, ServiceIdentityFamily.streaming);
      expect(def.properName, 'Netflix');
      expect(def.isNamed, isTrue);
    });
  });

  group('serviceIdentityDefinitionFor', () {
    test('null key resolves to null -- "no service" stays distinguishable from "unknown service"',
        () {
      expect(serviceIdentityDefinitionFor(null), isNull);
    });

    test('every catalog id resolves back to its own definition (stable persisted key)', () {
      for (final def in serviceIdentityCatalog) {
        expect(serviceIdentityDefinitionFor(def.id)?.id, def.id);
      }
    });

    test('an unrecognized non-null key degrades safely to the generic "other" entry, never throws',
        () {
      final def = serviceIdentityDefinitionFor('not_a_real_service_id_1234');
      expect(def, isNotNull);
      expect(def!.family, ServiceIdentityFamily.other);
      expect(def.isNamed, isFalse);
    });
  });

  group('serviceIdentityDisplayName', () {
    testWidgets('a named entry\'s display name is its properName verbatim, in every locale',
        (tester) async {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ja')]) {
        late AppLocalizations l10n;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: const <LocalizationsDelegate<Object?>>[
              ...AppLocalizations.localizationsDelegates,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (BuildContext context) {
                l10n = AppLocalizations.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final def = serviceIdentityCatalog.firstWhere((d) => d.id == 'spotify');
        expect(serviceIdentityDisplayName(l10n, def), 'Spotify', reason: locale.toString());
      }
    });

    testWidgets('a generic entry\'s display name is localized, not the raw family key',
        (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final def = serviceIdentityCatalog.firstWhere((d) => d.id == 'streaming');
      final String name = serviceIdentityDisplayName(l10n, def);
      expect(name, isNot('streaming'));
      expect(name, isNotEmpty);
    });
  });
}

import 'package:ai_financial_coach/features/services/domain/service_identity.dart';
import 'package:ai_financial_coach/features/services/presentation/service_identity_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a null key renders the safe generic ("other" family) fallback without throwing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ServiceIdentityIcon())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, serviceFamilyIconFor(ServiceIdentityFamily.other));
  });

  testWidgets('a generic-family key (e.g. "streaming") renders that family\'s distinct icon',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ServiceIdentityIcon(serviceIdentityKey: 'streaming')),
      ),
    );
    await tester.pumpAndSettle();
    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, serviceFamilyIconFor(ServiceIdentityFamily.streaming));
    expect(icon.icon, isNot(serviceFamilyIconFor(ServiceIdentityFamily.other)));
  });

  testWidgets('a named-service key (Netflix) renders through its family\'s icon, never throwing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ServiceIdentityIcon(serviceIdentityKey: 'netflix')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, serviceFamilyIconFor(ServiceIdentityFamily.streaming));
  });

  testWidgets('an unrecognized key degrades safely to the generic fallback, never throwing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ServiceIdentityIcon(serviceIdentityKey: 'not_a_real_service')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, serviceFamilyIconFor(ServiceIdentityFamily.other));
  });
}

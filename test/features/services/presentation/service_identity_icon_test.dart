import 'package:ai_financial_coach/features/services/domain/service_identity.dart';
import 'package:ai_financial_coach/features/services/presentation/service_identity_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('defaults to ServiceIdentityKey.other and renders without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ServiceIdentityIcon())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, serviceIdentityIconFor(ServiceIdentityKey.other));
  });

  testWidgets('renders a distinct icon for a non-default key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ServiceIdentityIcon(identityKey: ServiceIdentityKey.streaming)),
      ),
    );
    await tester.pumpAndSettle();
    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, serviceIdentityIconFor(ServiceIdentityKey.streaming));
    expect(icon.icon, isNot(serviceIdentityIconFor(ServiceIdentityKey.other)));
  });
}
